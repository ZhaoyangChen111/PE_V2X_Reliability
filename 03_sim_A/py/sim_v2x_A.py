from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional

import numpy as np
import pandas as pd

from progress_util import progress

from paths_A import (
    ensure_run_dirs_a,
    make_run_id,
    load_latest_run_id,
    ensure_base_dirs_a,
    get_base_paths_a,
)

from modules.mac_congestion import (
    CongestionParams,
    compute_ncs_from_distances,
    compute_airtime_s,
    compute_cbr,
    p_collision_from_ncs,
    congestion_extra_delay_ms,
)

from modules.link_variation import LinkVariationField
from modules.hotspot_weight import HotspotWeightParams, hotspot_multipliers
from modules import prop_city as pc
from modules import prop_tunnel as pt


@dataclass(frozen=True)
class Rect:
    x_min: float
    x_max: float
    y_min: float
    y_max: float


def clamp01(x: float) -> float:
    return float(np.clip(float(x), 0.0, 1.0))


def load_traj(traj_path: Path) -> pd.DataFrame:
    df = pd.read_csv(traj_path)
    if "time_s" not in df.columns or "veh_id" not in df.columns:
        raise ValueError(f"trajectory missing required columns: {traj_path}")
    if "time_key" not in df.columns:
        df["time_key"] = df["time_s"].round(3)
    return df


def load_buildings(buildings_path: Path) -> list[Rect]:
    df = pd.read_csv(buildings_path)
    need = {"x_min", "x_max", "y_min", "y_max"}
    if not need.issubset(df.columns):
        raise ValueError(f"buildings missing columns {need}: {buildings_path}")
    out: list[Rect] = []
    for _, r in df.iterrows():
        out.append(Rect(float(r["x_min"]), float(r["x_max"]), float(r["y_min"]), float(r["y_max"])))
    return out


def _legacy_dirs() -> tuple[Path, Path, Path, Path]:
    ensure_base_dirs_a()
    bp = get_base_paths_a()

    traj_dir = bp.scenarios_a_dir / "trajectories"
    buildings_dir = bp.scenarios_a_dir / "buildings"
    tunnel_dir = bp.scenarios_a_dir / "tunnel"
    raw_dir = bp.results_a_root / "raw"

    for d in [traj_dir, buildings_dir, tunnel_dir, raw_dir]:
        d.mkdir(parents=True, exist_ok=True)
    return traj_dir, buildings_dir, tunnel_dir, raw_dir


def _pick_run_id(arg_run_id: str) -> str:
    s = (arg_run_id or "").strip()
    if s == "":
        return make_run_id(prefix="A_")
    if s.lower() == "latest":
        rid = load_latest_run_id()
        return rid if rid else make_run_id(prefix="A_")
    return s


def parse_tx_ids(s: str, all_ids: Iterable[int]) -> list[int]:
    s = (s or "").strip().lower()
    ids = sorted(set(int(v) for v in all_ids))
    idset = set(ids)
    if s in ("all", "*"):
        return ids
    if s == "":
        return []
    out: list[int] = []
    for part in s.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            a, b = part.split("-", 1)
            a_i, b_i = int(a), int(b)
            out.extend(list(range(min(a_i, b_i), max(a_i, b_i) + 1)))
        else:
            out.append(int(part))
    out = [i for i in sorted(set(out)) if i in idset]
    return out


def _tag_is_cross(tag: str, prefixes: list[str]) -> bool:
    t = (tag or "").upper()
    return any(t.startswith(p.upper()) for p in prefixes if p)


def compute_delay_ms(
    distance_m: float,
    attempt_idx: int,
    attempt_spacing_ms: float,
    rng: np.random.Generator,
    impairment_b: float,
    extra_ms: float,
    exp_scale_ms: float,
) -> float:
    base = 1.0 + 0.02 * float(distance_m)
    backoff = (int(attempt_idx) - 1) * float(attempt_spacing_ms)
    jitter = float(rng.normal(0.0, 0.2))

    add = float(impairment_b) * float(extra_ms)
    tail = 0.0
    if float(impairment_b) > 1e-9 and float(exp_scale_ms) > 1e-9:
        tail = float(rng.exponential(scale=float(impairment_b) * float(exp_scale_ms)))

    return max(0.1, base + backoff + jitter + add + tail)


def simulate_one_seed(
    scenario: str,
    retrans: int,
    seed: int,
    msg_rate_hz: float,
    tx_ids_fixed: list[int],
    tx_mode: str,
    tx_k: int,
    tx_k_cross: int,
    tx_cross_prefixes: list[str],
    traj: pd.DataFrame,
    buildings: list[Rect],
    urb_transition_m: float,
    attempt_spacing_ms: float,
    tunnel_cfg: Optional[pt.TunnelConfig],
    enable_refl_gain: bool,
    gmax_db: float,
    d0_m: float,
    refl_beta: float,
    enable_congestion: bool,
    cong: CongestionParams,
    deadline_ms: float,
    collect_start_s: float,
    enable_link_variation: bool,
    link_field: Optional[LinkVariationField],
    enable_hotspot_weight: bool,
    hotspot_params: HotspotWeightParams,
) -> pd.DataFrame:
    rng = np.random.default_rng(int(seed))

    veh_ids = np.sort(traj["veh_id"].unique()).astype(int)
    vid2i = {int(v): i for i, v in enumerate(veh_ids)}
    V = len(veh_ids)

    cols = ["time_key", "veh_id", "x_m", "y_m"]
    has_speed = "speed_mps" in traj.columns
    has_tag = "road_tag" in traj.columns
    if has_speed:
        cols.append("speed_mps")
    if has_tag:
        cols.append("road_tag")

    g = traj[cols].copy()
    time_keys = np.sort(g["time_key"].unique())

    pos_by_t: dict[float, np.ndarray] = {}
    speed_by_t: dict[float, np.ndarray] = {}
    tag_by_t: dict[float, np.ndarray] = {}

    for tk, sub in g.groupby("time_key", sort=False):
        pos = np.full((V, 2), np.nan, dtype=float)
        spd = np.full((V,), np.nan, dtype=float)
        tag = np.full((V,), "", dtype=object)

        if has_speed and has_tag:
            arr = sub[["veh_id", "x_m", "y_m", "speed_mps", "road_tag"]].to_numpy()
            for vid, x, y, s_mps, rt in arr:
                ii = vid2i[int(vid)]
                pos[ii, 0] = float(x)
                pos[ii, 1] = float(y)
                spd[ii] = float(s_mps)
                tag[ii] = str(rt)
        elif has_speed and (not has_tag):
            arr = sub[["veh_id", "x_m", "y_m", "speed_mps"]].to_numpy()
            for vid, x, y, s_mps in arr:
                ii = vid2i[int(vid)]
                pos[ii, 0] = float(x)
                pos[ii, 1] = float(y)
                spd[ii] = float(s_mps)
        elif (not has_speed) and has_tag:
            arr = sub[["veh_id", "x_m", "y_m", "road_tag"]].to_numpy()
            for vid, x, y, rt in arr:
                ii = vid2i[int(vid)]
                pos[ii, 0] = float(x)
                pos[ii, 1] = float(y)
                tag[ii] = str(rt)
        else:
            arr = sub[["veh_id", "x_m", "y_m"]].to_numpy()
            for vid, x, y in arr:
                ii = vid2i[int(vid)]
                pos[ii, 0] = float(x)
                pos[ii, 1] = float(y)

        pos_by_t[float(tk)] = pos
        if has_speed:
            speed_by_t[float(tk)] = spd
        if has_tag:
            tag_by_t[float(tk)] = tag

    t0, t1 = float(time_keys.min()), float(time_keys.max())
    dt_msg = 1.0 / float(msg_rate_hz)
    msg_times = np.arange(t0, t1 + 1e-9, dt_msg)
    msg_times = np.round(msg_times, 3)

    airtime_s = 0.0
    if enable_congestion:
        airtime_s = compute_airtime_s(
            pkt_bytes=int(cong.pkt_bytes),
            phy_rate_mbps=float(cong.phy_rate_mbps),
            mac_efficiency=float(cong.mac_efficiency),
            phy_overhead_us=float(cong.phy_overhead_us),
        )

    out_rows = []
    msg_id = 0

    for t in progress(msg_times, total=len(msg_times), desc=f"{scenario} seed={seed}"):
        if float(t) < float(collect_start_s):
            continue

        pos = pos_by_t.get(float(t), None)
        if pos is None:
            continue

        spd = speed_by_t.get(float(t), None) if has_speed else None
        tag = tag_by_t.get(float(t), None) if has_tag else None

        active = np.isfinite(pos[:, 0]) & np.isfinite(pos[:, 1])
        active_ids = [int(veh_ids[i]) for i in range(V) if active[i]]
        if not active_ids:
            continue

        if tx_mode == "fixed":
            tx_ids = tx_ids_fixed if tx_ids_fixed else [active_ids[0]]
        elif tx_mode == "random":
            k = min(int(tx_k), len(active_ids))
            tx_ids = rng.choice(active_ids, size=k, replace=False).tolist()
        else:
            cross_ids = []
            if tag is not None:
                cross_ids = [int(veh_ids[i]) for i in range(V) if active[i] and _tag_is_cross(str(tag[i]), tx_cross_prefixes)]
            main_ids = [x for x in active_ids if x not in set(cross_ids)]

            k_cross = min(int(tx_k_cross), len(cross_ids))
            k_main = min(max(0, int(tx_k) - k_cross), len(main_ids))

            tx_ids = []
            if k_cross > 0:
                tx_ids += rng.choice(cross_ids, size=k_cross, replace=False).tolist()
            if k_main > 0:
                tx_ids += rng.choice(main_ids, size=k_main, replace=False).tolist()

            if not tx_ids:
                k = min(int(tx_k), len(active_ids))
                tx_ids = rng.choice(active_ids, size=k, replace=False).tolist()

        for tx_id in tx_ids:
            txi = vid2i.get(int(tx_id), None)
            if txi is None:
                continue

            tx_x, tx_y = float(pos[txi, 0]), float(pos[txi, 1])
            if not np.isfinite(tx_x):
                continue

            tx_speed_mps = float(spd[txi]) if (spd is not None and np.isfinite(spd[txi])) else np.nan
            tx_road_tag = str(tag[txi]) if tag is not None else ""

            dx = pos[:, 0] - tx_x
            dy = pos[:, 1] - tx_y
            dist_all = np.hypot(dx, dy)

            n_cs = 1
            cbr = 0.0
            p_col_base = 0.0
            cong_delay_ms_base = 0.0

            if enable_congestion:
                n_cs = compute_ncs_from_distances(
                    dist_all=dist_all,
                    tx_index=int(txi),
                    r_cs_m=float(cong.r_cs_m),
                    active_mask=active,
                    speed_all=spd,
                    min_speed_mps=float(cong.min_speed_mps),
                )
                cbr = compute_cbr(
                    n_cs=int(n_cs),
                    msg_rate_hz=float(msg_rate_hz),
                    airtime_s=float(airtime_s),
                    cbr_cap=float(cong.cbr_cap),
                )
                p_col_base = p_collision_from_ncs(
                    n_cs=int(n_cs),
                    alpha_col=float(cong.alpha_col),
                    cbr=float(cbr),
                    gamma_cbr_col=float(cong.gamma_cbr_col),
                    p_col_cap=float(cong.p_col_cap),
                )
                cong_delay_ms_base = congestion_extra_delay_ms(
                    rng=rng,
                    n_cs=int(n_cs),
                    beta_delay_ms=float(cong.beta_delay_ms),
                    exp_scale_ms=float(cong.exp_scale_ms),
                    cbr=float(cbr),
                    gamma_cbr_delay=float(cong.gamma_cbr_delay),
                    max_extra_delay_ms=float(cong.max_extra_delay_ms),
                )

            hotspot_mult_col = 1.0
            hotspot_mult_delay = 1.0
            if enable_hotspot_weight:
                hotspot_mult_col, hotspot_mult_delay = hotspot_multipliers(
                    road_tag=tx_road_tag,
                    tx_speed_mps=None if not np.isfinite(tx_speed_mps) else tx_speed_mps,
                    params=hotspot_params,
                )

            p_col = clamp01(p_col_base * hotspot_mult_col)
            cong_delay_ms = float(cong_delay_ms_base * hotspot_mult_delay)

            for rx_id in veh_ids:
                if int(rx_id) == int(tx_id):
                    continue
                rxi = vid2i[int(rx_id)]
                rx_x, rx_y = float(pos[rxi, 0]), float(pos[rxi, 1])
                if not np.isfinite(rx_x):
                    continue

                dist = float(dist_all[rxi])

                b = 0.0
                d_min_m = float("inf")
                g_refl_db = 0.0
                tunnel_u = np.nan
                extra_ms = 0.0
                exp_scale_ms = 0.0

                if scenario == "UrbMask":
                    b, d_min_m = pc.blockage_strength_with_dmin(tx_x, tx_y, rx_x, rx_y, buildings, float(urb_transition_m))
                    g_refl_db = pc.refl_gain_db(float(d_min_m), float(b), float(gmax_db), float(d0_m))
                elif scenario == "Tunnel":
                    if tunnel_cfg is None:
                        raise ValueError("Tunnel scenario requires tunnel_cfg")
                    b, tunnel_u = pt.tunnel_impairment_b(tx_x, rx_x, tunnel_cfg)
                    extra_ms = float(tunnel_cfg.delay_extra_ms)
                    exp_scale_ms = float(tunnel_cfg.delay_exp_scale_ms)

                if scenario == "Tunnel":
                    link_state = "TUNNEL" if float(b) >= 0.15 else "LOS"
                else:
                    link_state = "NLOS" if float(b) >= 0.5 else "LOS"

                p_los = pc.p_success_los(dist)
                p_nlos = pc.p_success_nlos(dist)
                p_succ = (1.0 - float(b)) * float(p_los) + float(b) * float(p_nlos)

                if enable_refl_gain and (scenario == "UrbMask") and float(gmax_db) > 1e-9:
                    rescue = float(np.clip(float(g_refl_db) / float(gmax_db), 0.0, 1.0))
                    p_succ = float(np.clip(p_succ + float(refl_beta) * rescue * (1.0 - p_succ), 0.001, 0.999))

                link_bias = 0.0
                if enable_link_variation and (link_field is not None):
                    link_bias = float(link_field.get_bias(int(tx_id), int(rx_id), float(t), link_state=link_state))
                    p_succ = float(np.clip(p_succ + link_bias, 0.001, 0.999))

                if enable_congestion:
                    p_succ = float(np.clip(p_succ * (1.0 - float(p_col)), 0.001, 0.999))

                success = 0
                success_phy = 0
                late = 0
                fail_reason = "PHY_FAIL"
                n_attempts = 0
                delay_ms = np.nan

                for attempt in range(1, int(retrans) + 2):
                    n_attempts = attempt
                    if rng.random() < p_succ:
                        success_phy = 1
                        delay_ms = compute_delay_ms(
                            dist,
                            attempt,
                            float(attempt_spacing_ms),
                            rng,
                            impairment_b=float(b),
                            extra_ms=float(extra_ms),
                            exp_scale_ms=float(exp_scale_ms),
                        )
                        if enable_congestion:
                            delay_ms = float(delay_ms + cong_delay_ms)

                        if float(deadline_ms) > 0.0 and float(delay_ms) > float(deadline_ms):
                            success = 0
                            late = 1
                            fail_reason = "DEADLINE"
                        else:
                            success = 1
                            late = 0
                            fail_reason = "OK"
                        break

                out_rows.append(
                    [
                        scenario,
                        int(retrans),
                        int(seed),
                        int(msg_id),
                        float(t),
                        int(tx_id),
                        int(rx_id),
                        float(dist),
                        float(b),
                        str(link_state),
                        float(0.5 * (tx_x + rx_x)),
                        float(tunnel_u),
                        float(d_min_m),
                        float(g_refl_db),
                        int(success),
                        int(success_phy),
                        int(late),
                        str(fail_reason),
                        int(n_attempts),
                        float(delay_ms) if np.isfinite(delay_ms) else np.nan,
                        float(deadline_ms),
                        int(n_cs),
                        float(cbr),
                        float(p_col),
                        float(cong_delay_ms),
                        str(tx_road_tag),
                        float(link_bias),
                        float(hotspot_mult_col),
                        float(hotspot_mult_delay),
                        float(tx_speed_mps) if np.isfinite(tx_speed_mps) else np.nan,
                    ]
                )

            msg_id += 1

    return pd.DataFrame(
        out_rows,
        columns=[
            "scenario",
            "retrans",
            "seed",
            "msg_id",
            "tx_time_s",
            "tx_id",
            "rx_id",
            "distance_m",
            "blockage_b",
            "link_state",
            "mid_x_m",
            "tunnel_u",
            "d_min_m",
            "g_refl_db",
            "success",
            "success_phy",
            "late",
            "fail_reason",
            "n_tx_attempts",
            "delay_ms",
            "deadline_ms",
            "n_cs",
            "cbr",
            "p_col",
            "cong_delay_ms",
            "tx_road_tag",
            "link_bias",
            "hotspot_mult_col",
            "hotspot_mult_delay",
            "tx_speed_mps",
        ],
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scenario", type=str, required=True, choices=["Ref", "UrbMask", "Tunnel"])
    ap.add_argument("--retrans", type=int, required=True, choices=[0, 1, 2])

    ap.add_argument("--run_id", type=str, default="")
    ap.add_argument("--seed_start", type=int, default=1)
    ap.add_argument("--n_seeds", type=int, default=1)

    ap.add_argument("--msg_rate_hz", type=float, default=10.0)

    ap.add_argument("--tx_id", type=int, default=0)
    ap.add_argument("--tx_ids", type=str, default="", help="e.g. all / 0,1,2 / 0-3")

    ap.add_argument("--tx_mode", type=str, default="fixed", choices=["fixed", "random", "mix"])
    ap.add_argument("--tx_k", type=int, default=6)
    ap.add_argument("--tx_k_cross", type=int, default=2)
    ap.add_argument("--tx_cross_prefixes", type=str, default="CROSS_,TURN_")

    ap.add_argument("--traj_path", type=str, default="")
    ap.add_argument("--traj_run_id", type=str, default="")
    ap.add_argument("--buildings_path", type=str, default="")
    ap.add_argument("--buildings_seed", type=int, default=-1)
    ap.add_argument("--transition_m", type=float, default=8.0)
    ap.add_argument("--tunnel_config_path", type=str, default="")
    ap.add_argument("--attempt_spacing_ms", type=float, default=20.0)

    ap.add_argument("--enable_refl_gain", action="store_true")
    ap.add_argument("--disable_refl_gain", action="store_true")
    ap.add_argument("--gmax_db", type=float, default=6.0)
    ap.add_argument("--d0_m", type=float, default=15.0)
    ap.add_argument("--refl_beta", type=float, default=0.25)

    ap.add_argument("--enable_congestion", action="store_true")
    ap.add_argument("--cs_r_m", type=float, default=150.0)
    ap.add_argument("--cs_alpha", type=float, default=0.012)
    ap.add_argument("--cs_beta_delay_ms", type=float, default=0.10)
    ap.add_argument("--cs_exp_scale_ms", type=float, default=0.10)
    ap.add_argument("--cs_min_speed_mps", type=float, default=0.0)
    ap.add_argument("--cs_pkt_bytes", type=int, default=300)
    ap.add_argument("--cs_phy_rate_mbps", type=float, default=6.0)
    ap.add_argument("--cs_mac_efficiency", type=float, default=0.55)
    ap.add_argument("--cs_phy_overhead_us", type=float, default=300.0)
    ap.add_argument("--cs_gamma_cbr_col", type=float, default=0.40)
    ap.add_argument("--cs_gamma_cbr_delay", type=float, default=0.60)
    ap.add_argument("--cs_cbr_cap", type=float, default=0.75)

    ap.add_argument("--deadline_ms", type=float, default=0.0)
    ap.add_argument("--collect_start_s", type=float, default=0.0)

    ap.add_argument("--enable_link_variation", action="store_true")
    ap.add_argument("--link_block_s", type=float, default=0.5)
    ap.add_argument("--link_rho", type=float, default=0.92)
    ap.add_argument("--link_sigma", type=float, default=0.04)
    ap.add_argument("--link_clip_abs", type=float, default=0.20)

    ap.add_argument("--enable_hotspot_weight", action="store_true")
    ap.add_argument("--hotspot_cross_mult", type=float, default=1.04)
    ap.add_argument("--hotspot_turn_mult", type=float, default=1.06)
    ap.add_argument("--hotspot_low_speed_thresh_mps", type=float, default=3.0)
    ap.add_argument("--hotspot_low_speed_bonus", type=float, default=0.02)
    ap.add_argument("--hotspot_queue_speed_thresh_mps", type=float, default=1.0)
    ap.add_argument("--hotspot_queue_bonus", type=float, default=0.02)

    args = ap.parse_args()

    run_id = _pick_run_id(args.run_id)
    rp = ensure_run_dirs_a(
        run_id,
        meta={"script": "sim_v2x_A.py", "scenario": args.scenario, "retrans": int(args.retrans)}
    )

    legacy_traj_dir, legacy_buildings_dir, legacy_tunnel_dir, _ = _legacy_dirs()

    if args.scenario in ("UrbMask", "Tunnel"):
        traj_name = "traj__Ref.csv"
    else:
        traj_name = f"traj__{args.scenario}.csv"

    traj_candidates = []

    if args.traj_path:
        traj_candidates.append(Path(args.traj_path))

    if args.traj_run_id:
        traj_candidates.append(
            rp.traj_dir.parent.parent / str(args.traj_run_id) / "trajectories" / traj_name
        )

    traj_candidates.append(rp.traj_dir / traj_name)
    traj_candidates.append(legacy_traj_dir / traj_name)

    traj_path = None
    for cand in traj_candidates:
        if cand.exists():
            traj_path = cand
            break

    if traj_path is None:
        searched = "\n".join(str(p) for p in traj_candidates)
        raise FileNotFoundError(
            "Trajectory file not found.\n"
            f"scenario={args.scenario}\n"
            f"expected_name={traj_name}\n"
            "Searched paths:\n"
            f"{searched}\n"
            "Please either:\n"
            "  1) run generate_trajectories_A.py with the same --run_id, or\n"
            "  2) pass --traj_path explicitly, or\n"
            "  3) pass --traj_run_id to reuse trajectories from another run."
        )

    print(f"[INFO] Using trajectory: {traj_path}")
    traj = load_traj(traj_path)

    buildings: list[Rect] = []
    if args.scenario == "UrbMask":
        if args.buildings_path:
            bpath = Path(args.buildings_path)
        else:
            seed_use = int(args.buildings_seed) if int(args.buildings_seed) >= 0 else int(args.seed_start)
            bpath = rp.buildings_dir / f"buildings__UrbMask__seed{seed_use}.csv"
            if not bpath.exists():
                bpath = legacy_buildings_dir / f"buildings__UrbMask__seed{seed_use}.csv"
        if bpath.exists():
            buildings = load_buildings(bpath)

    tunnel_cfg: Optional[pt.TunnelConfig] = None
    if args.scenario == "Tunnel":
        if args.tunnel_config_path:
            tpath = Path(args.tunnel_config_path)
        else:
            tpath = rp.tunnel_dir / "tunnel_config__Tunnel.csv"
            if not tpath.exists():
                tpath = legacy_tunnel_dir / "tunnel_config__Tunnel.csv"
        if not tpath.exists():
            raise FileNotFoundError(f"tunnel config not found: {tpath}")
        tunnel_cfg = pt.TunnelConfig.from_csv(tpath)

    veh_ids = np.sort(traj["veh_id"].unique()).astype(int)
    tx_ids_fixed = parse_tx_ids(args.tx_ids, veh_ids)
    if args.tx_mode == "fixed" and not tx_ids_fixed:
        tx_ids_fixed = [int(args.tx_id)]

    prefixes = [p.strip() for p in str(args.tx_cross_prefixes).split(",") if p.strip()]

    cong = CongestionParams(
        r_cs_m=float(args.cs_r_m),
        alpha_col=float(args.cs_alpha),
        beta_delay_ms=float(args.cs_beta_delay_ms),
        exp_scale_ms=float(args.cs_exp_scale_ms),
        min_speed_mps=float(args.cs_min_speed_mps),
        pkt_bytes=int(args.cs_pkt_bytes),
        phy_rate_mbps=float(args.cs_phy_rate_mbps),
        mac_efficiency=float(args.cs_mac_efficiency),
        phy_overhead_us=float(args.cs_phy_overhead_us),
        gamma_cbr_col=float(args.cs_gamma_cbr_col),
        gamma_cbr_delay=float(args.cs_gamma_cbr_delay),
        cbr_cap=float(args.cs_cbr_cap),
    )

    hotspot_params = HotspotWeightParams(
        cross_mult=float(args.hotspot_cross_mult),
        turn_mult=float(args.hotspot_turn_mult),
        low_speed_thresh_mps=float(args.hotspot_low_speed_thresh_mps),
        low_speed_bonus=float(args.hotspot_low_speed_bonus),
        queue_speed_thresh_mps=float(args.hotspot_queue_speed_thresh_mps),
        queue_bonus=float(args.hotspot_queue_bonus),
    )

    enable_refl = bool(args.enable_refl_gain) and (not bool(args.disable_refl_gain))

    seed0 = int(args.seed_start)
    n_seeds = int(args.n_seeds)
    seeds = list(range(seed0, seed0 + n_seeds))
    seed_tag = f"seed{seed0}-{seed0+n_seeds-1}" if n_seeds > 1 else f"seed{seed0}"

    frames = []
    for sd in seeds:
        link_field = None
        if args.enable_link_variation:
            link_field = LinkVariationField(
                block_s=float(args.link_block_s),
                rho=float(args.link_rho),
                sigma=float(args.link_sigma),
                clip_abs=float(args.link_clip_abs),
                base_seed=int(sd),
            )

        df = simulate_one_seed(
            scenario=str(args.scenario),
            retrans=int(args.retrans),
            seed=int(sd),
            msg_rate_hz=float(args.msg_rate_hz),
            tx_ids_fixed=tx_ids_fixed,
            tx_mode=str(args.tx_mode),
            tx_k=int(args.tx_k),
            tx_k_cross=int(args.tx_k_cross),
            tx_cross_prefixes=prefixes,
            traj=traj,
            buildings=buildings,
            urb_transition_m=float(args.transition_m),
            attempt_spacing_ms=float(args.attempt_spacing_ms),
            tunnel_cfg=tunnel_cfg,
            enable_refl_gain=bool(enable_refl),
            gmax_db=float(args.gmax_db),
            d0_m=float(args.d0_m),
            refl_beta=float(args.refl_beta),
            enable_congestion=bool(args.enable_congestion),
            cong=cong,
            deadline_ms=float(args.deadline_ms),
            collect_start_s=float(args.collect_start_s),
            enable_link_variation=bool(args.enable_link_variation),
            link_field=link_field,
            enable_hotspot_weight=bool(args.enable_hotspot_weight),
            hotspot_params=hotspot_params,
        )
        frames.append(df)

    out = pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()
    out_path = rp.raw_dir / f"results_packets__{args.scenario}__ret{args.retrans}__{seed_tag}.csv"
    out.to_csv(out_path, index=False)

    print(f"[OK] run_id={run_id}")
    print(f"[OK] packets -> {out_path} (rows={len(out)})")


if __name__ == "__main__":
    main()