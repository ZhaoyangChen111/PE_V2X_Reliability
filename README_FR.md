# PE_V2X_Reliability

**Langue :** Français | [English](README.md)

Un pipeline de simulation **reproductible** et **orienté mécanismes** pour évaluer la **fiabilité** et la **ponctualité** des messages de sécurité V2X en **environnements dégradés** (obstruction urbaine, tunnel) et en **congestion (heures de pointe)**.

Le projet met l’accent sur :
- PDR à temps en fonction de la distance
- latence de queue (p95 / p99)
- décomposition sous deadline : succès PHY vs pénalité late

---

## Contenu du dépôt

- `03_sim_A/` : code de simulation (pipeline Python + scripts MATLAB)
- `06_report/` : notebooks de rapport (EN/FR) + assets des figures finales (PDF + PNG)

Dimensions expérimentales :
- Scénarios : `RefPlus`, `UrbMaskPlus`, `TunnelPlus`
- Régimes (ablation) : `NoCong` vs `Cong` (switch congestion/compétition)
- Levier principal : retransmissions `ret = 0 / 1 / 2`

> Remarque : des dossiers comme `__pycache__/` sont générés automatiquement et ne font pas partie du dépôt.

---

## Structure du dépôt (vue d’ensemble)

<pre>
03_sim_A/
  py/
    analyze_metrics_A.py
    generate_trajectories_A.py
    generate_tunnel_config_A.py
    generate_urbmask_buildings_A.py
    paths_A.py
    plot_figures_A.py
    progress_util.py
    run_logging.py
    run_pipeline_A.py          # entrée : générer → simuler → agréger → tracer
    sim_v2x_A.py               # simulateur cœur (success_phy / late / success)
    modules/
      road_geometry.py
      traffic_idm.py
      traffic_signals.py
      buildings_3d.py
      prop_city.py
      prop_tunnel.py
      mac_congestion.py
      scenario_refplus.py
      scenario_urbmaskplus.py
      scenario_tunnelplus.py
  matlab/
    pe_raw_build_cache.m
    pe_raw_config.m
    pe_raw_plot_figures.m
    pe_raw_prepare_dirs.m
    run_all_raw.m

06_report/
  *.ipynb
  requirements_utf8.txt
  assets/
    final_figures_A_pdf/
    final_figures_A_preview/
    deliverables/
    matlab_cache_raw/
</pre>

---

## Démarrage rapide (Python)

Recommandé : ouvrir le dépôt dans **VS Code** et utiliser le terminal intégré.

### 1) Créer un environnement virtuel + installer les dépendances

**Windows (cmd) :**
<pre>
cd &lt;ROOT&gt;\03_sim_A\py
python -m venv &lt;ROOT&gt;\.venv
&lt;ROOT&gt;\.venv\Scripts\activate.bat
pip install -r &lt;ROOT&gt;\06_report\requirements_utf8.txt
</pre>

**macOS / Linux :**
<pre>
cd &lt;ROOT&gt;/03_sim_A/py
python3 -m venv &lt;ROOT&gt;/.venv
source &lt;ROOT&gt;/.venv/bin/activate
pip install -r &lt;ROOT&gt;/06_report/requirements_utf8.txt
</pre>

### 2) Lancer un smoke test

<pre>
python run_pipeline_A.py --run_id A_Smoke --preset RefPlus --scenarios Ref --rets 0,1,2 --seed_start 1 --n_seeds 1 --duration_s 60 --msg_rate_hz 10 --tx_mode mix --tx_k 6 --tx_k_cross 2
</pre>

Sorties :
<pre>
&lt;ROOT&gt;\05_results_A\runs\&lt;run_id&gt;\
  raw/
  tables/
  figures/
  run_commands.txt
</pre>

---

## Reproduire les runs finaux

Pour reproduire exactement les résultats finaux, utiliser les snapshots de commandes :
- `06_report/assets/deliverables/**/run_commands.txt`

Cela garantit le protocole complet (scénarios, seeds, binning, switch congestion, etc.).

---

## Rapports et figures finales

Notebooks principaux :
- Anglais : `06_report/01_Project_Report_SchemeA_EN_*.ipynb`
- Français : `06_report/01_Rapport_Projet_SchemaA_FR_*.ipynb`

Figures finales (Fig01–Fig07) :
- PDFs (référence) : `06_report/assets/final_figures_A_pdf/`
- PNG (rendus depuis les PDFs) : `06_report/assets/final_figures_A_preview/`

---

## Remarque sur la taille des données

Les logs raw paquet peuvent être volumineux et ne sont pas destinés à être distribués tels quels.
Pour la validation/relecture, le dépôt privilégie :
- tables CSV compactes + snapshots de commandes
- figures finales (PDF + PNG)
