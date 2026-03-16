% File: pe_raw_build_cache.m
function pe_raw_build_cache(cfg)
% Build raw aggregation cache for NoCong and Cong runs.
% Output: .mat caches under 05_results_A\matlab_cache_raw\<run_id>\...

build_one(cfg, cfg.runIdNoCong, cfg.rawDirNoCong);
build_one(cfg, cfg.runIdCong,   cfg.rawDirCong);

end

function build_one(cfg, runId, rawDir)
cacheDir = fullfile(cfg.cacheRoot, runId);
if ~exist(cacheDir, "dir"); mkdir(cacheDir); end

cacheName = sprintf("rawAgg__dist%gm__delay%gms__band%d-%d.mat", ...
    cfg.dist.bin_m, cfg.delay.bin_ms, int32(cfg.band.min_m), int32(cfg.band.max_m));
cachePath = fullfile(cacheDir, cacheName);

if exist(cachePath, "file") && ~cfg.cache.forceRebuild
    fprintf("[CACHE] Exists, skip build: %s\n", cachePath);
    return;
end

fprintf("\n[BUILD] Raw aggregation for run: %s\n", runId);
fprintf("       rawDir: %s\n", rawDir);

distEdges = 0:cfg.dist.bin_m:cfg.dist.max_m;
if distEdges(end) < cfg.dist.max_m
    distEdges = [distEdges cfg.dist.max_m];
end
nDistBins = numel(distEdges) - 1;
distCenters = distEdges(1:end-1) + 0.5*cfg.dist.bin_m;

delayEdges = 0:cfg.delay.bin_ms:cfg.delay.max_ms;
nDelayBins = numel(delayEdges) - 1;
delayCenters = delayEdges(1:end-1) + 0.5*cfg.delay.bin_ms;

runAgg = struct();
runAgg.meta.runId = runId;
runAgg.meta.rawDir = rawDir;
runAgg.meta.builtAt = datestr(now);
runAgg.cfg = cfg;
runAgg.dist.edges = distEdges;
runAgg.dist.centers = distCenters;
runAgg.delay.edges = delayEdges;
runAgg.delay.centers = delayCenters;

% Main aggregation per scenario/ret
for s = 1:numel(cfg.scenarios)
    scen = cfg.scenarios(s);
    scenAgg = struct();

    % Pre-allocate per ret
    for r = 1:numel(cfg.rets)
        ret = cfg.rets(r);
        files = dir(fullfile(rawDir, sprintf("results_packets__%s__ret%d__seed*.csv", scen, ret)));
        if isempty(files)
            error("Missing raw files: %s ret=%d in %s", scen, ret, rawDir);
        end
        fileList = fullfile({files.folder}, {files.name});

        fprintf("  - %s ret=%d : %d files\n", scen, ret, numel(fileList));
        A = aggregate_files(fileList, scen, ret, cfg, distEdges, delayEdges, nDistBins, nDelayBins);
        scenAgg.(sprintf("ret%d", ret)) = A;
    end

    runAgg.(scen) = scenAgg;
end

% Save cache
save(cachePath, "runAgg", "-v7.3");
fprintf("[OK] Cache saved: %s\n", cachePath);

end

function A = aggregate_files(fileList, scen, ret, cfg, distEdges, delayEdges, nDistBins, nDelayBins)
% Streaming aggregation using tabularTextDatastore + accumarray

% Accumulators
n_total       = zeros(nDistBins, 1);
n_succ        = zeros(nDistBins, 1);
n_phy         = zeros(nDistBins, 1);
n_late        = zeros(nDistBins, 1);

sum_attempts  = zeros(nDistBins, 1);
sum_blockage  = zeros(nDistBins, 1);
sum_ncs       = zeros(nDistBins, 1);
sum_cbr       = zeros(nDistBins, 1);
sum_pcol      = zeros(nDistBins, 1);
sum_congdelay = zeros(nDistBins, 1);

cnt_blockage  = zeros(nDistBins, 1);
cnt_ncs       = zeros(nDistBins, 1);
cnt_cbr       = zeros(nDistBins, 1);
cnt_pcol      = zeros(nDistBins, 1);
cnt_congdelay = zeros(nDistBins, 1);
cnt_attempts  = zeros(nDistBins, 1);

% Link-state counts (optional but cheap)
cnt_nlos   = zeros(nDistBins, 1);
cnt_tunnel = zeros(nDistBins, 1);

% Delay histogram per distance bin (success==1)
H = zeros(nDistBins, nDelayBins);

% F4/F5 band aggregators (raw-based)
doF4 = strcmp(scen, "UrbMask");
doF5 = strcmp(scen, "Tunnel");

if doF4
    midEdges = 0:cfg.f4.mid_bin_m:cfg.dist.max_m;
    nMidBins = numel(midEdges)-1;
    midCenters = midEdges(1:end-1) + 0.5*cfg.f4.mid_bin_m;

    f4_n_total = zeros(nMidBins,1);
    f4_n_succ  = zeros(nMidBins,1);
    f4_n_phy   = zeros(nMidBins,1);
    f4_n_late  = zeros(nMidBins,1);
    f4_sum_cbr = zeros(nMidBins,1); f4_cnt_cbr = zeros(nMidBins,1);
    f4_sum_blk = zeros(nMidBins,1); f4_cnt_blk = zeros(nMidBins,1);
end

if doF5
    uEdges = cfg.f5.u_min:cfg.f5.u_bin_w:cfg.f5.u_max;
    nUBins = numel(uEdges)-1;
    uCenters = uEdges(1:end-1) + 0.5*cfg.f5.u_bin_w;

    f5_n_total = zeros(nUBins,1);
    f5_n_succ  = zeros(nUBins,1);
    f5_n_phy   = zeros(nUBins,1);
    f5_n_late  = zeros(nUBins,1);
    f5_sum_cbr = zeros(nUBins,1); f5_cnt_cbr = zeros(nUBins,1);
    f5_sum_blk = zeros(nUBins,1); f5_cnt_blk = zeros(nUBins,1);
end

ds = tabularTextDatastore(fileList, "Delimiter", ",");
ds.ReadSize = 300000;

% Select only required columns (intersection for robustness)
firstOpts = detectImportOptions(fileList{1}, "Delimiter", ",");
vars = string(firstOpts.VariableNames);

need = ["distance_m","success","success_phy","late","delay_ms","n_tx_attempts", ...
        "blockage_b","link_state","n_cs","cbr","p_col","cong_delay_ms","mid_x_m","tunnel_u"];
sel = intersect(vars, need, "stable");
ds.SelectedVariableNames = cellstr(sel);

while hasdata(ds)
    T = read(ds);

    dist = getNumeric(T, "distance_m");
    if isempty(dist); continue; end

    % Distance bin index
    idx = floor(dist / cfg.dist.bin_m) + 1;
    inRange = isfinite(idx) & (idx >= 1) & (idx <= nDistBins);
    idx = idx(inRange);

    if isempty(idx)
        continue;
    end

    n_total = n_total + accumarray(idx, 1, [nDistBins,1], @sum, 0);

    % success / phy / late
    suc  = getNumeric(T, "success");
    phy  = getNumeric(T, "success_phy");
    late = getNumeric(T, "late");

    if ~isempty(suc)
        suc = suc(inRange);
        m = (suc == 1);
        n_succ = n_succ + accumarray(idx(m), 1, [nDistBins,1], @sum, 0);
    end
    if ~isempty(phy)
        phy = phy(inRange);
        m = (phy == 1);
        n_phy = n_phy + accumarray(idx(m), 1, [nDistBins,1], @sum, 0);
    end
    if ~isempty(late)
        late = late(inRange);
        m = (late == 1);
        n_late = n_late + accumarray(idx(m), 1, [nDistBins,1], @sum, 0);
    end

    % attempts
    att = getNumeric(T, "n_tx_attempts");
    if ~isempty(att)
        att = att(inRange);
        v = isfinite(att);
        sum_attempts = sum_attempts + accumarray(idx(v), att(v), [nDistBins,1], @sum, 0);
        cnt_attempts = cnt_attempts + accumarray(idx(v), 1, [nDistBins,1], @sum, 0);
    end

    % blockage
    blk = getNumeric(T, "blockage_b");
    if ~isempty(blk)
        blk = blk(inRange);
        v = isfinite(blk);
        sum_blockage = sum_blockage + accumarray(idx(v), blk(v), [nDistBins,1], @sum, 0);
        cnt_blockage = cnt_blockage + accumarray(idx(v), 1, [nDistBins,1], @sum, 0);
    end

    % n_cs, cbr, p_col, cong_delay_ms
    ncs = getNumeric(T, "n_cs");
    if ~isempty(ncs)
        ncs = ncs(inRange);
        v = isfinite(ncs);
        sum_ncs = sum_ncs + accumarray(idx(v), ncs(v), [nDistBins,1], @sum, 0);
        cnt_ncs = cnt_ncs + accumarray(idx(v), 1, [nDistBins,1], @sum, 0);
    end

    cbr = getNumeric(T, "cbr");
    if ~isempty(cbr)
        cbr = cbr(inRange);
        v = isfinite(cbr);
        sum_cbr = sum_cbr + accumarray(idx(v), cbr(v), [nDistBins,1], @sum, 0);
        cnt_cbr = cnt_cbr + accumarray(idx(v), 1, [nDistBins,1], @sum, 0);
    end

    pcol = getNumeric(T, "p_col");
    if ~isempty(pcol)
        pcol = pcol(inRange);
        v = isfinite(pcol);
        sum_pcol = sum_pcol + accumarray(idx(v), pcol(v), [nDistBins,1], @sum, 0);
        cnt_pcol = cnt_pcol + accumarray(idx(v), 1, [nDistBins,1], @sum, 0);
    end

    cdly = getNumeric(T, "cong_delay_ms");
    if ~isempty(cdly)
        cdly = cdly(inRange);
        v = isfinite(cdly);
        sum_congdelay = sum_congdelay + accumarray(idx(v), cdly(v), [nDistBins,1], @sum, 0);
        cnt_congdelay = cnt_congdelay + accumarray(idx(v), 1, [nDistBins,1], @sum, 0);
    end

    % link_state ratios (string)
    if any(strcmpi(T.Properties.VariableNames, "link_state"))
        ls = string(T.link_state);
        ls = ls(inRange);
        mN = (ls == "NLOS");
        mT = (ls == "TUNNEL");
        if any(mN)
            cnt_nlos = cnt_nlos + accumarray(idx(mN), 1, [nDistBins,1], @sum, 0);
        end
        if any(mT)
            cnt_tunnel = cnt_tunnel + accumarray(idx(mT), 1, [nDistBins,1], @sum, 0);
        end
    end

    % delay histogram (success==1 only)
    if ~isempty(suc) && any(strcmpi(T.Properties.VariableNames, "delay_ms"))
        dly = getNumeric(T, "delay_ms");
        dly = dly(inRange);
        suc2 = suc; % already inRange
        m = (suc2 == 1) & isfinite(dly) & (dly >= 0) & (dly <= cfg.delay.max_ms);
        if any(m)
            di = idx(m);
            db = discretize(dly(m), delayEdges); % 1..nDelayBins
            ok = isfinite(db) & (db >= 1) & (db <= nDelayBins);
            di = di(ok);
            db = db(ok);

            H = H + accumarray([di db], 1, [nDistBins nDelayBins], @sum, 0);
        end
    end

    % F4 (UrbMask heterogeneity) using distance band + mid_x_m
    if doF4 && any(strcmpi(T.Properties.VariableNames, "mid_x_m"))
        midx = getNumeric(T, "mid_x_m");
        midx = midx(inRange);
        dist2 = dist(inRange);

        inBand = isfinite(dist2) & (dist2 >= cfg.band.min_m) & (dist2 < cfg.band.max_m) & isfinite(midx);
        if any(inBand)
            mi = floor(midx(inBand) / cfg.f4.mid_bin_m) + 1;
            ok = (mi >= 1) & (mi <= nMidBins);
            mi = mi(ok);

            f4_n_total = f4_n_total + accumarray(mi, 1, [nMidBins,1], @sum, 0);

            if ~isempty(suc)
                sucB = suc(inBand);
                sucB = sucB(ok);
                f4_n_succ = f4_n_succ + accumarray(mi(sucB==1), 1, [nMidBins,1], @sum, 0);
            end
            if ~isempty(phy)
                phyB = phy(inBand);
                phyB = phyB(ok);
                f4_n_phy = f4_n_phy + accumarray(mi(phyB==1), 1, [nMidBins,1], @sum, 0);
            end
            if ~isempty(late)
                lateB = late(inBand);
                lateB = lateB(ok);
                f4_n_late = f4_n_late + accumarray(mi(lateB==1), 1, [nMidBins,1], @sum, 0);
            end

            if ~isempty(cbr)
                cbrB = cbr(inBand);
                cbrB = cbrB(ok);
                v = isfinite(cbrB);
                f4_sum_cbr = f4_sum_cbr + accumarray(mi(v), cbrB(v), [nMidBins,1], @sum, 0);
                f4_cnt_cbr = f4_cnt_cbr + accumarray(mi(v), 1, [nMidBins,1], @sum, 0);
            end

            if ~isempty(blk)
                blkB = blk(inBand);
                blkB = blkB(ok);
                v = isfinite(blkB);
                f4_sum_blk = f4_sum_blk + accumarray(mi(v), blkB(v), [nMidBins,1], @sum, 0);
                f4_cnt_blk = f4_cnt_blk + accumarray(mi(v), 1, [nMidBins,1], @sum, 0);
            end
        end
    end

    % F5 (Tunnel segments) using distance band + tunnel_u
    if doF5 && any(strcmpi(T.Properties.VariableNames, "tunnel_u"))
        u = getNumeric(T, "tunnel_u");
        u = u(inRange);
        dist2 = dist(inRange);

        inBand = isfinite(dist2) & (dist2 >= cfg.band.min_m) & (dist2 < cfg.band.max_m) & isfinite(u);
        if any(inBand)
            ui = discretize(u(inBand), uEdges);
            ok = isfinite(ui) & (ui >= 1) & (ui <= nUBins);
            ui = ui(ok);

            f5_n_total = f5_n_total + accumarray(ui, 1, [nUBins,1], @sum, 0);

            if ~isempty(suc)
                sucB = suc(inBand);
                sucB = sucB(ok);
                f5_n_succ = f5_n_succ + accumarray(ui(sucB==1), 1, [nUBins,1], @sum, 0);
            end
            if ~isempty(phy)
                phyB = phy(inBand);
                phyB = phyB(ok);
                f5_n_phy = f5_n_phy + accumarray(ui(phyB==1), 1, [nUBins,1], @sum, 0);
            end
            if ~isempty(late)
                lateB = late(inBand);
                lateB = lateB(ok);
                f5_n_late = f5_n_late + accumarray(ui(lateB==1), 1, [nUBins,1], @sum, 0);
            end

            if ~isempty(cbr)
                cbrB = cbr(inBand);
                cbrB = cbrB(ok);
                v = isfinite(cbrB);
                f5_sum_cbr = f5_sum_cbr + accumarray(ui(v), cbrB(v), [nUBins,1], @sum, 0);
                f5_cnt_cbr = f5_cnt_cbr + accumarray(ui(v), 1, [nUBins,1], @sum, 0);
            end

            if ~isempty(blk)
                blkB = blk(inBand);
                blkB = blkB(ok);
                v = isfinite(blkB);
                f5_sum_blk = f5_sum_blk + accumarray(ui(v), blkB(v), [nUBins,1], @sum, 0);
                f5_cnt_blk = f5_cnt_blk + accumarray(ui(v), 1, [nUBins,1], @sum, 0);
            end
        end
    end

end

% Derived curves
pdr = n_succ ./ max(1, n_total);
pdr_phy = n_phy ./ max(1, n_total);
late_ratio_phy = n_late ./ max(1, n_phy);

avg_attempts = sum_attempts ./ max(1, cnt_attempts);
avg_blockage = sum_blockage ./ max(1, cnt_blockage);
avg_ncs      = sum_ncs ./ max(1, cnt_ncs);
avg_cbr      = sum_cbr ./ max(1, cnt_cbr);
avg_pcol     = sum_pcol ./ max(1, cnt_pcol);
avg_cdly     = sum_congdelay ./ max(1, cnt_congdelay);

nlos_ratio   = cnt_nlos ./ max(1, n_total);
tunnel_ratio = cnt_tunnel ./ max(1, n_total);

% Delay quantiles per distance bin from histogram
[p50, p95, p99] = delay_quantiles_from_hist(H, cfg, delayEdges);

A = struct();
A.meta.scenario = scen;
A.meta.ret = ret;

A.n_total = n_total;
A.n_success = n_succ;
A.n_success_phy = n_phy;
A.n_late = n_late;

A.pdr = pdr;
A.pdr_phy = pdr_phy;
A.late_ratio_phy = late_ratio_phy;

A.avg_n_tx_attempts = avg_attempts;
A.avg_blockage_b = avg_blockage;
A.avg_n_cs = avg_ncs;
A.avg_cbr = avg_cbr;
A.avg_p_col = avg_pcol;
A.avg_cong_delay_ms = avg_cdly;

A.nlos_ratio = nlos_ratio;
A.tunnel_ratio = tunnel_ratio;

A.delay_hist = H;              % [nDistBins x nDelayBins], success==1 only
A.delay_p50_ms = p50;
A.delay_p95_ms = p95;
A.delay_p99_ms = p99;

% Attach F4/F5 (raw-derived)
if doF4
    f4 = struct();
    f4.mid_x_centers = midCenters(:);
    f4.n_total = f4_n_total;
    f4.n_success = f4_n_succ;
    f4.n_success_phy = f4_n_phy;
    f4.n_late = f4_n_late;
    f4.pdr_band = f4_n_succ ./ max(1, f4_n_total);
    f4.pdr_phy_band = f4_n_phy ./ max(1, f4_n_total);
    f4.late_ratio_phy_band = f4_n_late ./ max(1, f4_n_phy);
    f4.avg_cbr_band = f4_sum_cbr ./ max(1, f4_cnt_cbr);
    f4.mean_blockage_b = f4_sum_blk ./ max(1, f4_cnt_blk);
    A.f4 = f4;
end

if doF5
    f5 = struct();
    f5.u_centers = uCenters(:);
    f5.n_total = f5_n_total;
    f5.n_success = f5_n_succ;
    f5.n_success_phy = f5_n_phy;
    f5.n_late = f5_n_late;
    f5.pdr_band = f5_n_succ ./ max(1, f5_n_total);
    f5.pdr_phy_band = f5_n_phy ./ max(1, f5_n_total);
    f5.late_ratio_phy_band = f5_n_late ./ max(1, f5_n_phy);
    f5.avg_cbr_band = f5_sum_cbr ./ max(1, f5_cnt_cbr);
    f5.mean_blockage_b = f5_sum_blk ./ max(1, f5_cnt_blk);
    A.f5 = f5;
end

end

function x = getNumeric(T, name)
% Get numeric column robustly; return [] if missing.
if any(strcmpi(T.Properties.VariableNames, name))
    v = T.(name);
    if iscell(v)
        x = str2double(string(v));
    else
        x = double(v);
    end
else
    x = [];
end
end

function [p50, p95, p99] = delay_quantiles_from_hist(H, cfg, delayEdges)
nDistBins = size(H,1);
p50 = nan(nDistBins,1);
p95 = nan(nDistBins,1);
p99 = nan(nDistBins,1);

centers = delayEdges(1:end-1) + 0.5*(delayEdges(2)-delayEdges(1));

for i = 1:nDistBins
    h = H(i,:);
    n = sum(h);
    if n < cfg.th.min_succ_for_delayQ
        continue;
    end
    c = cumsum(h) / n;

    p50(i) = centers(find(c >= 0.50, 1, "first"));
    p95(i) = centers(find(c >= 0.95, 1, "first"));
    p99(i) = centers(find(c >= 0.99, 1, "first"));
end
end