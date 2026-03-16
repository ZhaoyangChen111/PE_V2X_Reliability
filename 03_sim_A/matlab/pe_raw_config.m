% File: pe_raw_config.m
function cfg = pe_raw_config()
% Raw-first pipeline config (high resolution but controllable)

thisDir = fileparts(mfilename('fullpath'));   % ...\03_sim_A\matlab
simADir = fileparts(thisDir);                 % ...\03_sim_A
projDir = fileparts(simADir);                 % ...\PE_V2X_Reliability

cfg.projectRoot = projDir;
cfg.resultsRoot = fullfile(cfg.projectRoot, "05_results_A");
cfg.runsRoot    = fullfile(cfg.resultsRoot, "runs");

% Run IDs (Day17 frozen version)
cfg.runIdNoCong = "A_Day17_Final_NoCong_S10_v2";
cfg.runIdCong   = "A_Day17_Final_Cong_S10_v2";

cfg.runDirNoCong = fullfile(cfg.runsRoot, cfg.runIdNoCong);
cfg.runDirCong   = fullfile(cfg.runsRoot, cfg.runIdCong);

cfg.rawDirNoCong = fullfile(cfg.runDirNoCong, "raw");
cfg.rawDirCong   = fullfile(cfg.runDirCong, "raw");

% Scope
cfg.scenarios = ["Ref","UrbMask","Tunnel"];
cfg.rets      = [0 1 2];

% Distance binning (high resolution)
cfg.dist.bin_m = 2.0;
cfg.dist.max_m = 3000.0;

% Plot windows
cfg.plot.fullMax_m  = cfg.dist.max_m;
cfg.plot.focusMax_m = 200.0;

% Delay histogram for quantiles (timely success only: success==1)
cfg.delay.bin_ms = 0.25;
cfg.delay.max_ms = 100.0;

% Thresholds to suppress noisy bins
cfg.th.min_total_per_bin   = 200;
cfg.th.min_succ_for_delayQ = 80;
cfg.th.min_phy_for_late    = 50;

% F4/F5 bands (from raw, not from tables)
cfg.band.min_m = 80.0;
cfg.band.max_m = 100.0;

% F4 (UrbMask mid_x bins)
cfg.f4.mid_bin_m = 50.0;
cfg.f4.min_total = 500;

% F5 (Tunnel u bins)
cfg.f5.u_min     = -0.25;
cfg.f5.u_max     =  1.25;
cfg.f5.u_bin_w   =  0.025;
cfg.f5.min_total = 200;

% Smoothing for plotting
cfg.smooth.enabled = true;
cfg.smooth.dx_m    = 1.0;
cfg.smooth.method  = "pchip";

% Export
cfg.export.saveFIG = true;
cfg.export.savePDF = true;
cfg.export.savePNG = true;
cfg.export.pngDPI  = 450;

% Style
cfg.style.fontName  = "Times New Roman";
cfg.style.fontSize  = 12;
cfg.style.lineWidth = 2.0;
cfg.style.gridAlpha = 0.25;

% Cache control
% Use true for the first rebuild on Day17 frozen runs.
% After one successful run, change it back to false.
cfg.cache.forceRebuild = true;

end