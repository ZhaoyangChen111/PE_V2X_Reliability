# paths_A.py
from __future__ import annotations
from dataclasses import dataclass
from pathlib import Path
from datetime import datetime
import json


@dataclass(frozen=True)
class BasePathsA:
    project_root: Path
    scenarios_a_dir: Path
    results_a_root: Path
    sim_a_dir: Path
    modules_dir: Path
    runs_scenarios_dir: Path   # 02_scenarios_A/runs
    runs_results_dir: Path     # 05_results_A/runs
    latest_run_file: Path      # 05_results_A/LATEST_RUN.json


@dataclass(frozen=True)
class RunPathsA:
    run_id: str

    # run input dirs
    run_scenarios_dir: Path
    config_dir: Path
    traj_dir: Path
    buildings_dir: Path
    tunnel_dir: Path

    # run output dirs
    run_results_dir: Path
    raw_dir: Path
    tables_dir: Path
    figures_dir: Path

    manifest_path: Path


def _detect_project_root(from_file: Path) -> Path:
    p = from_file.resolve()
    return p.parents[2]  # paths_A.py -> py -> 03_sim_A -> <root>


def get_base_paths_a() -> BasePathsA:
    root = _detect_project_root(Path(__file__))

    scenarios_a_dir = root / "02_scenarios_A"
    results_a_root = root / "05_results_A"

    sim_a_dir = root / "03_sim_A" / "py"
    modules_dir = sim_a_dir / "modules"

    runs_scenarios_dir = scenarios_a_dir / "runs"
    runs_results_dir = results_a_root / "runs"
    latest_run_file = results_a_root / "LATEST_RUN.json"

    return BasePathsA(
        project_root=root,
        scenarios_a_dir=scenarios_a_dir,
        results_a_root=results_a_root,
        sim_a_dir=sim_a_dir,
        modules_dir=modules_dir,
        runs_scenarios_dir=runs_scenarios_dir,
        runs_results_dir=runs_results_dir,
        latest_run_file=latest_run_file,
    )


def make_run_id(prefix: str = "") -> str:
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    return f"{prefix}{ts}" if prefix else ts


def ensure_base_dirs_a() -> BasePathsA:
    b = get_base_paths_a()
    b.modules_dir.mkdir(parents=True, exist_ok=True)
    b.runs_scenarios_dir.mkdir(parents=True, exist_ok=True)
    b.runs_results_dir.mkdir(parents=True, exist_ok=True)
    return b


def ensure_run_dirs_a(run_id: str, save_as_latest: bool = True, meta: dict | None = None) -> RunPathsA:
    """
    Create run directories for inputs+outputs.
    Optionally write LATEST_RUN.json and run manifest.
    """
    b = ensure_base_dirs_a()

    run_scenarios_dir = b.runs_scenarios_dir / run_id
    config_dir = run_scenarios_dir / "config"
    traj_dir = run_scenarios_dir / "trajectories"
    buildings_dir = run_scenarios_dir / "buildings"
    tunnel_dir = run_scenarios_dir / "tunnel"

    run_results_dir = b.runs_results_dir / run_id
    raw_dir = run_results_dir / "raw"
    tables_dir = run_results_dir / "tables"
    figures_dir = run_results_dir / "figures"

    for d in [config_dir, traj_dir, buildings_dir, tunnel_dir, raw_dir, tables_dir, figures_dir]:
        d.mkdir(parents=True, exist_ok=True)

    manifest_path = run_results_dir / "run_manifest.json"
    if meta is None:
        meta = {}
    meta2 = {
        "run_id": run_id,
        "created_at": datetime.now().isoformat(timespec="seconds"),
        **meta,
    }
    manifest_path.write_text(json.dumps(meta2, indent=2, ensure_ascii=False), encoding="utf-8")

    if save_as_latest:
        b.latest_run_file.write_text(
            json.dumps({"latest_run_id": run_id, "updated_at": meta2["created_at"]}, indent=2),
            encoding="utf-8",
        )

    return RunPathsA(
        run_id=run_id,
        run_scenarios_dir=run_scenarios_dir,
        config_dir=config_dir,
        traj_dir=traj_dir,
        buildings_dir=buildings_dir,
        tunnel_dir=tunnel_dir,
        run_results_dir=run_results_dir,
        raw_dir=raw_dir,
        tables_dir=tables_dir,
        figures_dir=figures_dir,
        manifest_path=manifest_path,
    )


def load_latest_run_id() -> str | None:
    b = get_base_paths_a()
    if not b.latest_run_file.exists():
        return None
    try:
        obj = json.loads(b.latest_run_file.read_text(encoding="utf-8"))
        return obj.get("latest_run_id")
    except Exception:
        return None


if __name__ == "__main__":
    b = ensure_base_dirs_a()
    rid = make_run_id(prefix="A_")
    r = ensure_run_dirs_a(rid)
    print("[OK] base runs scenarios:", b.runs_scenarios_dir)
    print("[OK] base runs results  :", b.runs_results_dir)
    print("[OK] created run_id     :", rid)
    print("[OK] run traj_dir       :", r.traj_dir)
    print("[OK] run raw_dir        :", r.raw_dir)
    print("[OK] latest_run_file    :", b.latest_run_file)