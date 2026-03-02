# run_pipeline_A.py
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from paths_A import ensure_run_dirs_a, make_run_id
from run_logging import log_command, update_manifest


def _run(cmd: list[str], cwd: Path) -> None:
    print("\n[RUN]", " ".join(cmd))
    r = subprocess.run(cmd, cwd=str(cwd))
    if r.returncode != 0:
        raise SystemExit(f"[ERROR] command failed with returncode={r.returncode}: {' '.join(cmd)}")


def main():
    ap = argparse.ArgumentParser(description="A version: one-click pipeline (gen -> sim -> analyze -> plot)")
    ap.add_argument("--run_id", type=str, default="")
    # Presets: structure the "scenario defaults" into named configs + manifest snapshot.
    # - If you don't use preset, behavior is unchanged (pure CLI-driven).
    ap.add_argument("--preset", type=str, default="", choices=["", "RefPlus", "UrbMaskPlus", "TunnelPlus", "Day13Final"])
    ap.add_argument(
        "--preset_override",
        action="store_true",
        help="If set, preset will override even explicitly provided CLI args (default: preset fills only missing args).",
    )

    # Reflection rescue toggle (UrbMask only). Useful with presets.
    ap.add_argument("--enable_refl_gain", action="store_true")
    ap.add_argument("--disable_refl_gain", action="store_true")
    ap.add_argument("--gmax_db", type=float, default=6.0)
    ap.add_argument("--d0_m", type=float, default=15.0)
    ap.add_argument("--refl_beta", type=float, default=0.25)

    # Application deadline for timeliness (ms). <=0 disabled.
    ap.add_argument("--deadline_ms", type=float, default=0.0)

    ap.add_argument("--scenarios", type=str, default="UrbMask")
    ap.add_argument("--rets", type=str, default="0,1,2")

    ap.add_argument("--seed_start", type=int, default=1)
    ap.add_argument("--n_seeds", type=int, default=3)
    ap.add_argument("--msg_rate_hz", type=float, default=10.0)

    # tx selection
    ap.add_argument("--tx_id", type=int, default=0)
    ap.add_argument("--tx_ids", type=str, default="")
    ap.add_argument("--tx_mode", type=str, default="fixed", choices=["fixed", "random", "mix"])
    ap.add_argument("--tx_k", type=int, default=6)
    ap.add_argument("--tx_k_cross", type=int, default=2)
    ap.add_argument("--tx_cross_prefixes", type=str, default="CROSS_,TURN_")

    ap.add_argument("--duration_s", type=float, default=120.0)
    ap.add_argument("--dt_s", type=float, default=0.1)
    ap.add_argument("--n_vehicles", type=int, default=60)
    ap.add_argument("--speed_mps", type=float, default=15.0)
    ap.add_argument("--spacing_m", type=float, default=20.0)

    ap.add_argument("--buildings_seed", type=int, default=1)
    # UrbMask buildings knobs (optional; if not set, generate_urbmask_buildings_A defaults are used)
    ap.add_argument("--urb_n_blocks", type=int, default=12)
    ap.add_argument("--urb_min_w_m", type=float, default=18.0)
    ap.add_argument("--urb_max_w_m", type=float, default=45.0)
    ap.add_argument("--urb_min_h_m", type=float, default=8.0)
    ap.add_argument("--urb_max_h_m", type=float, default=22.0)
    ap.add_argument("--urb_min_height_m", type=float, default=10.0)
    ap.add_argument("--urb_max_height_m", type=float, default=50.0)
    ap.add_argument("--urb_y_halfspan_mode", type=str, default="cross_road", choices=["cross_road", "one_side"])
    ap.add_argument("--urb_x_margin_m", type=float, default=10.0)

    # UrbMask propagation transition (maps d_min -> blockage strength b)
    ap.add_argument("--urb_transition_m", type=float, default=8.0)

    ap.add_argument("--road_length_m", type=float, default=400.0)
    ap.add_argument("--n_blocks", type=int, default=12)

    # Gate-A
    ap.add_argument("--refplus", action="store_true")
    ap.add_argument("--n_lanes_per_dir", type=int, default=3)
    ap.add_argument("--lane_width_m", type=float, default=3.5)
    ap.add_argument("--median_gap_m", type=float, default=2.0)
    ap.add_argument("--s_curve_x0", type=float, default=900.0)
    ap.add_argument("--s_curve_x1", type=float, default=1500.0)
    ap.add_argument("--s_curve_amp_y_m", type=float, default=12.0)
    ap.add_argument("--i1_x", type=float, default=1000.0)
    ap.add_argument("--i2_x", type=float, default=2000.0)
    ap.add_argument("--intersection_zone_m", type=float, default=60.0)

    # Gate-B
    ap.add_argument("--traffic_idm", action="store_true")
    ap.add_argument("--traffic_signals", action="store_true")
    ap.add_argument("--flow_main_vph", type=float, default=600.0)
    ap.add_argument("--veh_length_m", type=float, default=4.5)
    ap.add_argument("--min_spawn_gap_m", type=float, default=10.0)

    ap.add_argument("--idm_v0_mps", type=float, default=22.0)
    ap.add_argument("--idm_T_s", type=float, default=1.2)
    ap.add_argument("--idm_a_mps2", type=float, default=1.2)
    ap.add_argument("--idm_b_mps2", type=float, default=2.0)
    ap.add_argument("--idm_s0_m", type=float, default=2.0)
    ap.add_argument("--idm_delta", type=float, default=4.0)

    ap.add_argument("--sig_cycle_s", type=float, default=90.0)
    ap.add_argument("--sig_green_main_s", type=float, default=55.0)
    ap.add_argument("--sig_all_red_s", type=float, default=2.0)
    ap.add_argument("--sig_offset_i2_s", type=float, default=15.0)

    # Gate-C
    ap.add_argument("--cross_enable", action="store_true")
    ap.add_argument("--flow_cross_vph", type=float, default=400.0)
    ap.add_argument("--cross_half_length_m", type=float, default=400.0)
    ap.add_argument("--p_turn_i1", type=float, default=0.12)
    ap.add_argument("--p_turn_i2", type=float, default=0.12)
    ap.add_argument("--p_right", type=float, default=0.80)
    ap.add_argument("--p_left", type=float, default=0.20)

    # Gate-D
    ap.add_argument("--enable_congestion", action="store_true")
    ap.add_argument("--cs_r_m", type=float, default=250.0)
    ap.add_argument("--cs_alpha", type=float, default=0.06)
    ap.add_argument("--cs_beta_delay_ms", type=float, default=0.8)
    ap.add_argument("--cs_exp_scale_ms", type=float, default=0.6)
    ap.add_argument("--cs_min_speed_mps", type=float, default=0.0)
    ap.add_argument("--cs_pkt_bytes", type=int, default=300)
    ap.add_argument("--cs_phy_rate_mbps", type=float, default=6.0)
    ap.add_argument("--cs_mac_efficiency", type=float, default=0.55)
    ap.add_argument("--cs_phy_overhead_us", type=float, default=300.0)
    ap.add_argument("--cs_gamma_cbr_col", type=float, default=1.5)
    ap.add_argument("--cs_gamma_cbr_delay", type=float, default=2.0)
    ap.add_argument("--cs_cbr_cap", type=float, default=0.95)

    # tunnel config defaults
    ap.add_argument("--x0_m", type=float, default=1000.0)
    ap.add_argument("--x1_m", type=float, default=2600.0)
    ap.add_argument("--transition_m", type=float, default=200.0)
    ap.add_argument("--tunnel_severity", type=float, default=1.0)
    ap.add_argument("--tunnel_b_floor", type=float, default=0.35)
    ap.add_argument("--tunnel_b_peak", type=float, default=0.45)
    ap.add_argument("--tunnel_bell_gamma", type=float, default=1.6)
    ap.add_argument("--tunnel_delay_extra_ms", type=float, default=0.8)
    ap.add_argument("--tunnel_delay_exp_scale_ms", type=float, default=1.0)

    ap.add_argument("--skip_gen", action="store_true")
    ap.add_argument("--skip_plot", action="store_true")
    args = ap.parse_args()

    # -------- preset application (fills only missing args by default) --------
    # We detect whether an option was explicitly provided by scanning sys.argv.
    argv_set = set(sys.argv[1:])

    def _has_flag(name: str) -> bool:
        return name in argv_set

    def _has_any(names: list[str]) -> bool:
        return any(n in argv_set for n in names)

    def _apply_if_missing(opt_names: list[str], attr: str, value):
        if args.preset_override or (not _has_any(opt_names)):
            setattr(args, attr, value)

    preset = (args.preset or "").strip()

    if preset:
        try:
            from modules.scenario_refplus import RefPlusScenarioConfig
            from modules.scenario_urbmaskplus import UrbMaskScenarioConfig
            from modules.scenario_tunnelplus import TunnelScenarioConfig
        except Exception:
            # If user didn't copy the scenario_*.py into modules yet, skip preset.
            RefPlusScenarioConfig = None  # type: ignore
            UrbMaskScenarioConfig = None  # type: ignore
            TunnelScenarioConfig = None  # type: ignore

        cfg_ref = RefPlusScenarioConfig() if RefPlusScenarioConfig else None
        cfg_urb = UrbMaskScenarioConfig() if UrbMaskScenarioConfig else None
        cfg_tun = TunnelScenarioConfig() if TunnelScenarioConfig else None

        # Day13Final is a bundle: RefPlus + UrbMaskPlus + TunnelPlus + recommended toggles
        if preset in ("Day13Final", "RefPlus"):
            if cfg_ref is not None:
                _apply_if_missing(["--refplus"], "refplus", True)
                _apply_if_missing(["--traffic_idm"], "traffic_idm", True)
                _apply_if_missing(["--traffic_signals"], "traffic_signals", True)
                _apply_if_missing(["--cross_enable"], "cross_enable", bool(cfg_ref.cross_enable))

                _apply_if_missing(["--road_length_m"], "road_length_m", float(cfg_ref.geom.road_length_m))
                _apply_if_missing(["--n_lanes_per_dir"], "n_lanes_per_dir", int(cfg_ref.geom.n_lanes_per_dir))
                _apply_if_missing(["--lane_width_m"], "lane_width_m", float(cfg_ref.geom.lane_width_m))
                _apply_if_missing(["--median_gap_m"], "median_gap_m", float(cfg_ref.geom.median_gap_m))
                _apply_if_missing(["--s_curve_x0"], "s_curve_x0", float(cfg_ref.geom.s_curve_x0))
                _apply_if_missing(["--s_curve_x1"], "s_curve_x1", float(cfg_ref.geom.s_curve_x1))
                _apply_if_missing(["--s_curve_amp_y_m"], "s_curve_amp_y_m", float(cfg_ref.geom.s_curve_amp_y_m))
                _apply_if_missing(["--i1_x"], "i1_x", float(cfg_ref.geom.i1_x))
                _apply_if_missing(["--i2_x"], "i2_x", float(cfg_ref.geom.i2_x))
                _apply_if_missing(
                    ["--intersection_zone_m"], "intersection_zone_m", float(cfg_ref.geom.intersection_zone_m)
                )

                _apply_if_missing(["--flow_main_vph"], "flow_main_vph", float(cfg_ref.idm.flow_main_vph))
                _apply_if_missing(["--veh_length_m"], "veh_length_m", float(cfg_ref.idm.veh_length_m))
                _apply_if_missing(["--min_spawn_gap_m"], "min_spawn_gap_m", float(cfg_ref.idm.min_spawn_gap_m))
                _apply_if_missing(["--idm_v0_mps"], "idm_v0_mps", float(cfg_ref.idm.idm_v0_mps))
                _apply_if_missing(["--idm_T_s"], "idm_T_s", float(cfg_ref.idm.idm_T_s))
                _apply_if_missing(["--idm_a_mps2"], "idm_a_mps2", float(cfg_ref.idm.idm_a_mps2))
                _apply_if_missing(["--idm_b_mps2"], "idm_b_mps2", float(cfg_ref.idm.idm_b_mps2))
                _apply_if_missing(["--idm_s0_m"], "idm_s0_m", float(cfg_ref.idm.idm_s0_m))
                _apply_if_missing(["--idm_delta"], "idm_delta", float(cfg_ref.idm.idm_delta))

                _apply_if_missing(["--sig_cycle_s"], "sig_cycle_s", float(cfg_ref.sig.sig_cycle_s))
                _apply_if_missing(["--sig_green_main_s"], "sig_green_main_s", float(cfg_ref.sig.sig_green_main_s))
                _apply_if_missing(["--sig_all_red_s"], "sig_all_red_s", float(cfg_ref.sig.sig_all_red_s))
                _apply_if_missing(["--sig_offset_i2_s"], "sig_offset_i2_s", float(cfg_ref.sig.sig_offset_i2_s))

                _apply_if_missing(["--flow_cross_vph"], "flow_cross_vph", float(cfg_ref.flow_cross_vph))
                _apply_if_missing(["--cross_half_length_m"], "cross_half_length_m", float(cfg_ref.cross_half_length_m))
                _apply_if_missing(["--p_turn_i1"], "p_turn_i1", float(cfg_ref.p_turn_i1))
                _apply_if_missing(["--p_turn_i2"], "p_turn_i2", float(cfg_ref.p_turn_i2))
                _apply_if_missing(["--p_right"], "p_right", float(cfg_ref.p_right))
                _apply_if_missing(["--p_left"], "p_left", float(cfg_ref.p_left))

        if preset in ("Day13Final", "UrbMaskPlus"):
            if cfg_urb is not None:
                _apply_if_missing(["--buildings_seed"], "buildings_seed", int(cfg_urb.buildings.seed))
                _apply_if_missing(["--urb_n_blocks"], "urb_n_blocks", int(cfg_urb.buildings.n_blocks))
                _apply_if_missing(["--urb_x_margin_m"], "urb_x_margin_m", float(cfg_urb.buildings.x_margin_m))
                _apply_if_missing(["--urb_y_halfspan_mode"], "urb_y_halfspan_mode", str(cfg_urb.buildings.y_halfspan_mode))
                _apply_if_missing(["--urb_min_w_m"], "urb_min_w_m", float(cfg_urb.buildings.min_w_m))
                _apply_if_missing(["--urb_max_w_m"], "urb_max_w_m", float(cfg_urb.buildings.max_w_m))
                _apply_if_missing(["--urb_min_h_m"], "urb_min_h_m", float(cfg_urb.buildings.min_h_m))
                _apply_if_missing(["--urb_max_h_m"], "urb_max_h_m", float(cfg_urb.buildings.max_h_m))
                _apply_if_missing(["--urb_min_height_m"], "urb_min_height_m", float(cfg_urb.buildings.min_height_m))
                _apply_if_missing(["--urb_max_height_m"], "urb_max_height_m", float(cfg_urb.buildings.max_height_m))

                _apply_if_missing(["--urb_transition_m"], "urb_transition_m", float(cfg_urb.prop.urb_transition_m))

                # reflection rescue: default on in config, but allow CLI disable
                if bool(cfg_urb.prop.enable_refl_gain) and (not _has_flag("--disable_refl_gain")):
                    _apply_if_missing(["--enable_refl_gain"], "enable_refl_gain", True)
                    _apply_if_missing(["--gmax_db"], "gmax_db", float(cfg_urb.prop.gmax_db))
                    _apply_if_missing(["--d0_m"], "d0_m", float(cfg_urb.prop.d0_m))
                    _apply_if_missing(["--refl_beta"], "refl_beta", float(cfg_urb.prop.refl_beta))

        if preset in ("Day13Final", "TunnelPlus"):
            if cfg_tun is not None:
                _apply_if_missing(["--x0_m"], "x0_m", float(cfg_tun.tunnel.x0_m))
                _apply_if_missing(["--x1_m"], "x1_m", float(cfg_tun.tunnel.x1_m))
                _apply_if_missing(["--transition_m"], "transition_m", float(cfg_tun.tunnel.transition_m))
                _apply_if_missing(["--tunnel_severity"], "tunnel_severity", float(cfg_tun.tunnel.severity))
                _apply_if_missing(["--tunnel_b_floor"], "tunnel_b_floor", float(cfg_tun.tunnel.b_floor))
                _apply_if_missing(["--tunnel_b_peak"], "tunnel_b_peak", float(cfg_tun.tunnel.b_peak))
                _apply_if_missing(["--tunnel_bell_gamma"], "tunnel_bell_gamma", float(cfg_tun.tunnel.bell_gamma))
                _apply_if_missing(["--tunnel_delay_extra_ms"], "tunnel_delay_extra_ms", float(cfg_tun.tunnel.delay_extra_ms))
                _apply_if_missing(
                    ["--tunnel_delay_exp_scale_ms"], "tunnel_delay_exp_scale_ms", float(cfg_tun.tunnel.delay_exp_scale_ms)
                )

        # Day13Final also suggests tx_mode mix + typical k values (unless user overrides)
        if preset == "Day13Final":
            _apply_if_missing(["--tx_mode"], "tx_mode", "mix")
            _apply_if_missing(["--tx_k"], "tx_k", 6)
            _apply_if_missing(["--tx_k_cross"], "tx_k_cross", 2)
            # Default deadline to 100ms if not specified (V2X safety-ish), but user can override
            _apply_if_missing(["--deadline_ms"], "deadline_ms", 100.0)

    run_id = args.run_id.strip() if args.run_id.strip() else make_run_id(prefix="A_")
    rp = ensure_run_dirs_a(run_id, meta={"script": "run_pipeline_A.py"})

    log_command(run_id, rp.run_results_dir, extra="pipeline_start")
    update_manifest(rp.manifest_path, patch={"pipeline": {"scenarios": args.scenarios, "rets": args.rets, "preset": args.preset}})

    script_dir = Path(__file__).resolve().parent
    py = sys.executable

    scenarios = [s.strip() for s in args.scenarios.split(",") if s.strip()]
    rets = [int(x.strip()) for x in args.rets.split(",") if x.strip()]

    if not args.skip_gen:
        gen_cmd = [
            py,
            "generate_trajectories_A.py",
            "--run_id",
            run_id,
            "--duration_s",
            str(args.duration_s),
            "--dt_s",
            str(args.dt_s),
            "--n_vehicles",
            str(args.n_vehicles),
            "--speed_mps",
            str(args.speed_mps),
            "--spacing_m",
            str(args.spacing_m),
            "--seed",
            str(args.seed_start),
        ]

        if args.refplus:
            gen_cmd += [
                "--refplus",
                "--road_length_m",
                str(args.road_length_m),
                "--n_lanes_per_dir",
                str(args.n_lanes_per_dir),
                "--lane_width_m",
                str(args.lane_width_m),
                "--median_gap_m",
                str(args.median_gap_m),
                "--s_curve_x0",
                str(args.s_curve_x0),
                "--s_curve_x1",
                str(args.s_curve_x1),
                "--s_curve_amp_y_m",
                str(args.s_curve_amp_y_m),
                "--i1_x",
                str(args.i1_x),
                "--i2_x",
                str(args.i2_x),
                "--intersection_zone_m",
                str(args.intersection_zone_m),
            ]

        if args.traffic_idm:
            gen_cmd += [
                "--traffic_idm",
                "--flow_main_vph",
                str(args.flow_main_vph),
                "--veh_length_m",
                str(args.veh_length_m),
                "--min_spawn_gap_m",
                str(args.min_spawn_gap_m),
                "--idm_v0_mps",
                str(args.idm_v0_mps),
                "--idm_T_s",
                str(args.idm_T_s),
                "--idm_a_mps2",
                str(args.idm_a_mps2),
                "--idm_b_mps2",
                str(args.idm_b_mps2),
                "--idm_s0_m",
                str(args.idm_s0_m),
                "--idm_delta",
                str(args.idm_delta),
            ]
            if args.traffic_signals:
                gen_cmd += [
                    "--traffic_signals",
                    "--sig_cycle_s",
                    str(args.sig_cycle_s),
                    "--sig_green_main_s",
                    str(args.sig_green_main_s),
                    "--sig_all_red_s",
                    str(args.sig_all_red_s),
                    "--sig_offset_i2_s",
                    str(args.sig_offset_i2_s),
                ]

        if args.cross_enable:
            gen_cmd += [
                "--cross_enable",
                "--flow_cross_vph",
                str(args.flow_cross_vph),
                "--cross_half_length_m",
                str(args.cross_half_length_m),
                "--p_turn_i1",
                str(args.p_turn_i1),
                "--p_turn_i2",
                str(args.p_turn_i2),
                "--p_right",
                str(args.p_right),
                "--p_left",
                str(args.p_left),
            ]

        _run(gen_cmd, cwd=script_dir)

        if "UrbMask" in scenarios:
            _run(
                [
                    py,
                    "generate_urbmask_buildings_A.py",
                    "--run_id",
                    run_id,
                    "--seed",
                    str(args.buildings_seed),
                    "--road_length_m",
                    str(args.road_length_m),
                    "--n_blocks",
                    str(args.urb_n_blocks),
                    "--min_w_m",
                    str(args.urb_min_w_m),
                    "--max_w_m",
                    str(args.urb_max_w_m),
                    "--min_h_m",
                    str(args.urb_min_h_m),
                    "--max_h_m",
                    str(args.urb_max_h_m),
                    "--min_height_m",
                    str(args.urb_min_height_m),
                    "--max_height_m",
                    str(args.urb_max_height_m),
                    "--y_halfspan_mode",
                    str(args.urb_y_halfspan_mode),
                    "--x_margin_m",
                    str(args.urb_x_margin_m),
                ],
                cwd=script_dir,
            )

        if "Tunnel" in scenarios:
            _run(
                [
                    py,
                    "generate_tunnel_config_A.py",
                    "--run_id",
                    run_id,
                    "--x0_m",
                    str(args.x0_m),
                    "--x1_m",
                    str(args.x1_m),
                    "--transition_m",
                    str(args.transition_m),
                    "--severity",
                    str(args.tunnel_severity),
                    "--b_floor",
                    str(args.tunnel_b_floor),
                    "--b_peak",
                    str(args.tunnel_b_peak),
                    "--bell_gamma",
                    str(args.tunnel_bell_gamma),
                    "--delay_extra_ms",
                    str(args.tunnel_delay_extra_ms),
                    "--delay_exp_scale_ms",
                    str(args.tunnel_delay_exp_scale_ms),
                ],
                cwd=script_dir,
            )

    for sc in scenarios:
        for ret in rets:
            sim_cmd = [
                py,
                "sim_v2x_A.py",
                "--run_id",
                run_id,
                "--scenario",
                sc,
                "--retrans",
                str(ret),
                "--seed_start",
                str(args.seed_start),
                "--n_seeds",
                str(args.n_seeds),
                "--msg_rate_hz",
                str(args.msg_rate_hz),
                "--deadline_ms",
                str(args.deadline_ms),
                "--tx_mode",
                str(args.tx_mode),
                "--tx_k",
                str(args.tx_k),
                "--tx_k_cross",
                str(args.tx_k_cross),
                "--tx_cross_prefixes",
                str(args.tx_cross_prefixes),
                "--transition_m",
                str(args.urb_transition_m),
            ]
            # UrbMask reflection rescue (optional)
            if args.enable_refl_gain and (not args.disable_refl_gain):
                sim_cmd += [
                    "--enable_refl_gain",
                    "--gmax_db",
                    str(args.gmax_db),
                    "--d0_m",
                    str(args.d0_m),
                    "--refl_beta",
                    str(args.refl_beta),
                ]
            if args.disable_refl_gain:
                sim_cmd += ["--disable_refl_gain"]

            if args.tx_mode == "fixed":
                if args.tx_ids.strip():
                    sim_cmd += ["--tx_ids", args.tx_ids.strip()]
                else:
                    sim_cmd += ["--tx_id", str(args.tx_id)]

            if args.enable_congestion:
                sim_cmd += [
                    "--enable_congestion",
                    "--cs_r_m",
                    str(args.cs_r_m),
                    "--cs_alpha",
                    str(args.cs_alpha),
                    "--cs_beta_delay_ms",
                    str(args.cs_beta_delay_ms),
                    "--cs_exp_scale_ms",
                    str(args.cs_exp_scale_ms),
                    "--cs_min_speed_mps",
                    str(args.cs_min_speed_mps),
                    "--cs_pkt_bytes",
                    str(args.cs_pkt_bytes),
                    "--cs_phy_rate_mbps",
                    str(args.cs_phy_rate_mbps),
                    "--cs_mac_efficiency",
                    str(args.cs_mac_efficiency),
                    "--cs_phy_overhead_us",
                    str(args.cs_phy_overhead_us),
                    "--cs_gamma_cbr_col",
                    str(args.cs_gamma_cbr_col),
                    "--cs_gamma_cbr_delay",
                    str(args.cs_gamma_cbr_delay),
                    "--cs_cbr_cap",
                    str(args.cs_cbr_cap),
                ]

            _run(sim_cmd, cwd=script_dir)
            _run([py, "analyze_metrics_A.py", "--run_id", run_id, "--scenario", sc, "--retrans", str(ret)], cwd=script_dir)

            if not args.skip_plot:
                _run([py, "plot_figures_A.py", "--run_id", run_id, "--scenario", sc, "--retrans", str(ret)], cwd=script_dir)

    print("\n[OK] Pipeline finished.")
    print("[OK] run_id:", run_id)
    print("[OK] results:", rp.run_results_dir)


if __name__ == "__main__":
    main()