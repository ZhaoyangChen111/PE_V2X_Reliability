% File: pe_raw_prepare_dirs.m
function cfg = pe_raw_prepare_dirs(cfg)
% Prepare output folder + cache root under 05_results_A

ts = datestr(now, "yyyymmdd_HHMMSS");
cfg.outDir = fullfile(cfg.resultsRoot, "matlab_final_figures_raw__" + string(ts));
if ~exist(cfg.outDir, "dir"); mkdir(cfg.outDir); end

cfg.cacheRoot = fullfile(cfg.resultsRoot, "matlab_cache_raw");
if ~exist(cfg.cacheRoot, "dir"); mkdir(cfg.cacheRoot); end

% Run note
notePath = fullfile(cfg.outDir, "MATLAB_RUN_NOTE.txt");
fid = fopen(notePath, "w");
fprintf(fid, "Raw-first MATLAB final figures (PE_V2X_Reliability)\n");
fprintf(fid, "Generated at: %s\n", datestr(now));
fprintf(fid, "Project root: %s\n", cfg.projectRoot);
fprintf(fid, "NoCong run:   %s\n", cfg.runIdNoCong);
fprintf(fid, "Cong run:     %s\n", cfg.runIdCong);
fprintf(fid, "dist.bin_m:   %.3f\n", cfg.dist.bin_m);
fprintf(fid, "dist.max_m:   %.1f\n", cfg.dist.max_m);
fprintf(fid, "delay.bin_ms: %.3f\n", cfg.delay.bin_ms);
fprintf(fid, "delay.max_ms: %.1f\n", cfg.delay.max_ms);
fprintf(fid, "band:         %.1f-%.1f m\n", cfg.band.min_m, cfg.band.max_m);
fclose(fid);

end