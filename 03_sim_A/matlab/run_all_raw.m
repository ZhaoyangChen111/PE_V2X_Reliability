% File: run_all_raw.m
clear; clc;

thisDir = fileparts(mfilename('fullpath'));
addpath(thisDir);

cfg = pe_raw_config();
cfg = pe_raw_prepare_dirs(cfg);

% Build cache (raw -> aggregated .mat) if needed
pe_raw_build_cache(cfg);

% Load cache and generate final figures (6-7)
pe_raw_plot_figures(cfg);

fprintf("\n[OK] Done.\nCache root:\n  %s\nOutput folder:\n  %s\n\n", cfg.cacheRoot, cfg.outDir);