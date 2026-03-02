# PE_V2X_Reliability (Scheme A)

A reproducible, mechanism-oriented simulation pipeline to evaluate **V2X safety-message reliability and timeliness** under **degraded environments** and **busy-hour congestion**.  
The project focuses on **distance-dependent PDR**, **tail latency (p95/p99)**, and **deadline-aware success**, with explicit evidence fields for explainability.

---

## What this repository contains

This repository is organized around two deliverables:

- **`03_sim_A/`** — the simulation code (Python pipeline + optional MATLAB post-processing)
- **`06_report/`** — reporting notebooks (CN/EN/FR) + final figure assets (PDF + PNG previews)

The experiments are built around:

- **Scenarios (degraded environments)**  
  - `RefPlus`: controlled baseline corridor  
  - `UrbMaskPlus`: urban canyon / obstruction + spatial heterogeneity  
  - `TunnelPlus`: tunnel segmentation + tail-delay shaping
- **Regimes (ablation)**  
  - `NoCong` vs `Cong` (congestion/competition mechanism toggle)
- **Main enhancement lever**  
  - retransmissions: `ret = 0 / 1 / 2`

---

## Repository structure (high level)

```text
03_sim_A/
  py/
    run_pipeline_A.py          # entry point: generate → simulate → aggregate → plot
    sim_v2x_A.py               # core event simulator (success_phy / late / success)
    analyze_metrics_A.py       # raw → tables (CSV)
    plot_figures_A.py          # deliverable plots (F1/F2/F3)
    modules/
      scenario_refplus.py
      scenario_urbmaskplus.py
      scenario_tunnelplus.py
      road_geometry.py
      traffic_idm.py
      traffic_signals.py
      buildings_3d.py
      prop_city.py
      prop_tunnel.py
      mac_congestion.py
06_report/
  *.ipynb                      # report notebooks (EN/FR + others)
  requirements_utf8.txt
  assets/
    final_figures_A_pdf/       # authoritative final PDFs (Fig01–Fig07)
    final_figures_A_preview/   # PNG previews rendered from PDFs
    deliverables/              # compact run artifacts (tables/figures + run_commands)
    matlab_cache_raw/          # cached stats for fast re-plotting (MATLAB)
