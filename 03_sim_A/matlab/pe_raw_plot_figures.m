% File: pe_raw_plot_figures.m
function pe_raw_plot_figures(cfg)
% Final figures (raw-derived) - teacher-oriented version (Fig03 robustness fix)
%
% Fix in this version:
% - Fig03 Tunnel panels could become blank due to strict filtering.
% - We use relaxed thresholds ONLY for Fig03 (decomposition), ensuring data is visible.
% - If still no valid bins, print an explicit message in the subplot.

NoCong = load_cache(cfg, cfg.runIdNoCong);
Cong   = load_cache(cfg, cfg.runIdCong);

xDist = NoCong.dist.centers(:);
focusMask = (xDist <= cfg.plot.focusMax_m);

retAll = cfg.rets(:).';
retKey = [0 2]; % key rets for some figures

retColorsAll = lines(numel(retAll));
retColorsKey = lines(numel(retKey));
scenColors   = lines(numel(cfg.scenarios)); %#ok<NASGU>

% Disable TeX interpreters globally (underscores won't create subscripts)
set(groot, "defaultTextInterpreter", "none");
set(groot, "defaultLegendInterpreter", "none");
set(groot, "defaultAxesTickLabelInterpreter", "none");

% ===================== Fig01: PDR vs distance (focus, 1x3) =====================
fig = figure("Name","Fig01 PDR vs distance (<=200m)");
set_fig_style(fig, cfg, [1800 650]);
tl = tiledlayout(fig, 1, 3, "TileSpacing","compact", "Padding","compact");

for iS = 1:numel(cfg.scenarios)
    scen = cfg.scenarios(iS);
    ax = nexttile(tl, iS);
    hold(ax,"on");

    for k = 1:numel(retAll)
        ret = retAll(k);
        c = retColorsAll(k,:);

        A = NoCong.(scen).(sprintf("ret%d", ret));
        B = Cong.(scen).(sprintf("ret%d", ret));

        yA = mask_by_n(A.pdr, A.n_total, cfg.th.min_total_per_bin);
        yB = mask_by_n(B.pdr, B.n_total, cfg.th.min_total_per_bin);

        % NoCong: solid
        plot_smooth(ax, xDist, yA, cfg, focusMask, "-", c);
        % Cong: denser dotted style (visual better than sparse dashed)
        plot_smooth(ax, xDist, yB, cfg, focusMask, ":", c);
    end

    gridify(ax, cfg);
    xlim(ax, [0 cfg.plot.focusMax_m]);
    ylim(ax, [0 1]);
    title(ax, char(scen));
    xlabel(ax, "Distance (m)");
    ylabel(ax, "PDR (timely)");

    text(ax, 0.02, 0.04, "Solid=NoCong, Dotted=Cong", "Units","normalized", ...
        "FontSize", 12, "Color",[0.25 0.25 0.25]);
end

add_ret_legend(fig, retAll, retColorsAll, "ret (color) | Solid=NoCong, Dotted=Cong");
sg = sgtitle(tl, "PDR vs distance (raw-derived, dist<=200m)");
set(sg, "Interpreter","none");
save_figure(fig, cfg, "Fig01_PDR_Focus");
close(fig);

% ===================== Fig02: Tail delays (p95 solid, p99 dotted), 2x3, ret0/ret2 =====================
fig = figure("Name","Fig02 Tail delays (p95/p99, ret0/ret2)");
set_fig_style(fig, cfg, [1800 900]);
tl = tiledlayout(fig, 2, 3, "TileSpacing","compact", "Padding","compact");

runs = ["NoCong","Cong"];
for iRun = 1:2
    runName = runs(iRun);
    R = pick_run(NoCong, Cong, runName);

    for iS = 1:numel(cfg.scenarios)
        scen = cfg.scenarios(iS);
        ax = nexttile(tl, (iRun-1)*3 + iS);
        hold(ax,"on");

        for k = 1:numel(retKey)
            ret = retKey(k);
            c = retColorsKey(k,:);

            A = R.(scen).(sprintf("ret%d", ret));

            p95 = mask_by_n(A.delay_p95_ms, A.n_success, cfg.th.min_succ_for_delayQ);
            p99 = mask_by_n(A.delay_p99_ms, A.n_success, cfg.th.min_succ_for_delayQ);

            plot_smooth(ax, xDist, p95, cfg, focusMask, "-", c);
            plot_smooth(ax, xDist, p99, cfg, focusMask, ":", c);
        end

        gridify(ax, cfg);
        xlim(ax, [0 cfg.plot.focusMax_m]);
        xlabel(ax, "Distance (m)");
        ylabel(ax, "Delay (ms)");

        if runName == "NoCong"
            ylim(ax, [0 30]);
            title(ax, sprintf("%s | NoCong", scen));
        else
            ylim(ax, [50 100]);
            title(ax, sprintf("%s | Cong", scen));
        end

        text(ax, 0.02, 0.04, "p95 solid, p99 dotted", "Units","normalized", ...
            "FontSize", 12, "Color",[0.25 0.25 0.25]);
    end
end

add_ret_legend(fig, retKey, retColorsKey, "ret (color) | p95 solid, p99 dotted");
sg = sgtitle(tl, "Tail delays of timely successes (raw-derived) | ret=0 and ret=2");
set(sg, "Interpreter","none");
save_figure(fig, cfg, "Fig02_TailDelay_p95p99_Ret0Ret2");
close(fig);

% ===================== Fig03: Cong-only decomposition (ROBUST) =====================
% Cong-only, 2x3 panels: row=ret0 vs ret2, col=scenario
% Left y-axis: phy_rate and timely_rate
% Right y-axis: late_ratio_phy
%
% Robustness: use relaxed thresholds only here to avoid blank Tunnel panels.
minTotalDecomp = max(30, round(cfg.th.min_total_per_bin / 10));
minPhyDecomp   = max(10, round(cfg.th.min_phy_for_late / 5));

fig = figure("Name","Fig03 Cong decomposition (3 curves, dual axis)");
set_fig_style(fig, cfg, [1800 900]);
tl = tiledlayout(fig, 2, 3, "TileSpacing","compact", "Padding","compact");

cPhy    = [0.10 0.35 0.85]; % blue
cTimely = [0.15 0.65 0.25]; % green
cLate   = [0.90 0.55 0.10]; % orange

axFirst = [];
hLegend = gobjects(3,1);

for iRow = 1:2
    ret = retKey(iRow);

    for iS = 1:numel(cfg.scenarios)
        scen = cfg.scenarios(iS);
        ax = nexttile(tl, (iRow-1)*3 + iS);
        hold(ax,"on");
        if isempty(axFirst), axFirst = ax; end

        A = Cong.(scen).(sprintf("ret%d", ret));

        nT = double(A.n_total(:));
        nS = double(A.n_success(:));
        nP = double(A.n_success_phy(:));
        nL = double(A.n_late(:));

        goodT = focusMask(:) & isfinite(nT) & (nT >= minTotalDecomp);

        timely_rate = nan(size(nT));
        phy_rate    = nan(size(nT));
        late_ratio  = nan(size(nT));

        timely_rate(goodT) = nS(goodT) ./ nT(goodT);
        phy_rate(goodT)    = nP(goodT) ./ nT(goodT);

        goodP = goodT & isfinite(nP) & (nP >= minPhyDecomp);
        late_ratio(goodP) = nL(goodP) ./ nP(goodP);

        % Smooth for visualization (not changing cached statistics)
        timely_rate = movmean(timely_rate, 5, "omitnan");
        phy_rate    = movmean(phy_rate,    5, "omitnan");
        late_ratio  = movmean(late_ratio,  5, "omitnan");

        % If everything is NaN, show explicit message (never blank silently)
        if all(~isfinite(timely_rate(focusMask))) && all(~isfinite(phy_rate(focusMask)))
            gridify(ax, cfg);
            xlim(ax, [0 cfg.plot.focusMax_m]);
            ylim(ax, [0 1]);
            xlabel(ax, "Distance (m)");
            ylabel(ax, "Rate (share of total)");
            title(ax, sprintf("%s | Cong | ret=%d", scen, ret));
            text(ax, 0.5, 0.5, ...
                sprintf("Insufficient samples after filtering\n(minTotal=%d, minPhy=%d)", minTotalDecomp, minPhyDecomp), ...
                "Units","normalized", "HorizontalAlignment","center", "FontSize", 12, "Color",[0.35 0.35 0.35]);
            continue;
        end

        % Left axis
        yyaxis(ax, "left");
        p1 = plot(ax, xDist(focusMask), phy_rate(focusMask), "-", "Color", cPhy, "LineWidth", 2.4);
        p2 = plot(ax, xDist(focusMask), timely_rate(focusMask), "-", "Color", cTimely, "LineWidth", 2.4);
        ylabel(ax, "Rate (share of total)");

        mxL = max([nanmax(phy_rate(focusMask)), nanmax(timely_rate(focusMask))]);
        if ~isfinite(mxL) || mxL <= 0, mxL = 0.12; end
        ylim(ax, [0 min(1.0, max(0.12, 1.15*mxL))]);

        % Right axis
        yyaxis(ax, "right");
        p3 = plot(ax, xDist(focusMask), late_ratio(focusMask), ":", "Color", cLate, "LineWidth", 2.6);
        ylabel(ax, "late_ratio_phy");

        mxR = nanmax(late_ratio(focusMask));
        if ~isfinite(mxR) || mxR <= 0, mxR = 0.1; end
        ylim(ax, [0 min(1.0, max(0.15, 1.15*mxR))]);

        % Back to left axis for grid aesthetics
        yyaxis(ax, "left");
        gridify(ax, cfg);
        xlim(ax, [0 cfg.plot.focusMax_m]);
        xlabel(ax, "Distance (m)");
        title(ax, sprintf("%s | Cong | ret=%d", scen, ret));

        if iRow == 1
            text(ax, 0.02, 0.90, "timely = phy × (1 - late)", "Units","normalized", ...
                "FontSize", 12, "Color",[0.25 0.25 0.25]);
        end

        if iRow == 1 && iS == 1
            hLegend(1) = p1; hLegend(2) = p2; hLegend(3) = p3;
        end
    end
end

lg = legend(axFirst, hLegend, ...
    ["phy_rate = success_phy/total", "timely_rate = success/total", "late_ratio_phy = late/success_phy"], ...
    "Location","northoutside", "Orientation","horizontal");
lg.Box = "off";
lg.FontSize = 11;

sg = sgtitle(tl, sprintf("Cong-only decomposition (readable): PHY success, timely success, and late penalty | ret=0 vs ret=2 (minTotal=%d, minPhy=%d)", ...
    minTotalDecomp, minPhyDecomp));
set(sg, "Interpreter","none");
save_figure(fig, cfg, "Fig03_Cong_Decomposition_3Curves");
close(fig);

% ===================== Fig04: Congestion proxy (mean +/- std band) =====================
fig = figure("Name","Fig04 Cong proxy mean+std band (Cong only)");
set_fig_style(fig, cfg, [1800 600]);
tl = tiledlayout(fig, 1, 3, "TileSpacing","compact", "Padding","compact");

metricNames = ["avg_cbr","avg_p_col","avg_cong_delay_ms"];
metricYlab  = ["Avg CBR","Avg p_col","Avg congestion delay (ms)"];

for iM = 1:3
    ax = nexttile(tl, iM);
    hold(ax,"on");

    Y = nan(numel(cfg.scenarios), numel(xDist));
    for iS = 1:numel(cfg.scenarios)
        scen = cfg.scenarios(iS);
        A = Cong.(scen).("ret0");
        y = mask_by_n(A.(metricNames(iM)), A.n_total, cfg.th.min_total_per_bin);
        Y(iS,:) = y(:).';
    end

    xf = xDist(focusMask);
    Yf = Y(:, focusMask);

    mu = mean(Yf, 1, "omitnan");
    sd = std(Yf, 0, 1, "omitnan");

    mu = movmean(mu, 5, "omitnan");
    sd = movmean(sd, 5, "omitnan");

    yLo = mu - sd;
    yHi = mu + sd;

    fill(ax, [xf; flipud(xf)], [yLo(:); flipud(yHi(:))], [0.7 0.7 0.9], ...
        "EdgeColor","none", "FaceAlpha",0.35);
    plot(ax, xf, mu, "-", "Color",[0.15 0.15 0.6], "LineWidth",2.8);

    gridify(ax, cfg);
    xlim(ax, [0 cfg.plot.focusMax_m]);
    xlabel(ax, "Distance (m)");
    ylabel(ax, metricYlab(iM));
    title(ax, metricYlab(iM) + " | Cong");

    text(ax, 0.02, 0.04, "Line=mean, band=±1 std across scenarios", "Units","normalized", ...
        "FontSize", 12, "Color",[0.25 0.25 0.25]);
end

sg = sgtitle(tl, "Congestion proxy evidence (raw-derived) | Cong only | mean ± std across scenarios");
set(sg, "Interpreter","none");
save_figure(fig, cfg, "Fig04_CongProxy_MeanStdBand");
close(fig);

% ===================== Fig05: UrbMask heterogeneity lines + ratio =====================
fig = figure("Name","Fig05 UrbMask heterogeneity (NoCong) + ratio(Cong/NoCong)");
set_fig_style(fig, cfg, [1800 750]);
tl = tiledlayout(fig, 2, 1, "TileSpacing","compact", "Padding","compact");

xMid = NoCong.UrbMask.ret0.f4.mid_x_centers(:);

ax = nexttile(tl, 1); hold(ax,"on");
for k = 1:numel(retAll)
    ret = retAll(k);
    c = retColorsAll(k,:);

    f4 = NoCong.UrbMask.(sprintf("ret%d", ret)).f4;
    y = f4.pdr_band(:);
    y(f4.n_total < cfg.f4.min_total) = NaN;
    y = movmean(y, 3, "omitnan");
    plot(ax, xMid, y, "-", "Color", c, "LineWidth", 2.2);
end
gridify(ax, cfg);
xlim(ax, [0 cfg.dist.max_m]);
ylim(ax, [0 1]);
xlabel(ax, "mid_x (m)");
ylabel(ax, "PDR_band (NoCong)");
title(ax, "UrbMask heterogeneity (NoCong) | PDR_band vs mid_x");
add_ret_legend(fig, retAll, retColorsAll, "ret (color)");

ax = nexttile(tl, 2); hold(ax,"on");
yline(ax, 1.0, ":", "Color",[0.35 0.35 0.35], "LineWidth", 1.5);

for k = 1:numel(retAll)
    ret = retAll(k);
    c = retColorsAll(k,:);

    f4A = NoCong.UrbMask.(sprintf("ret%d", ret)).f4;
    f4B = Cong.UrbMask.(sprintf("ret%d", ret)).f4;

    yA = f4A.pdr_band(:); yA(f4A.n_total < cfg.f4.min_total) = NaN;
    yB = f4B.pdr_band(:); yB(f4B.n_total < cfg.f4.min_total) = NaN;

    ratio = yB ./ yA;
    ratio(~isfinite(ratio)) = NaN;
    ratio = movmean(ratio, 3, "omitnan");

    plot(ax, xMid, ratio, "-", "Color", c, "LineWidth", 2.2);
end

gridify(ax, cfg);
xlim(ax, [0 cfg.dist.max_m]);
ylim(ax, [0 0.6]);
xlabel(ax, "mid_x (m)");
ylabel(ax, "PDR_ratio = Cong / NoCong");
title(ax, "Congestion impact on UrbMask heterogeneity | ratio (Cong/NoCong)");
text(ax, 0.02, 0.06, "Lower ratio => stronger degradation under congestion", "Units","normalized", ...
    "FontSize", 12, "Color",[0.25 0.25 0.25]);

sg = sgtitle(tl, sprintf("UrbMask spatial heterogeneity (raw band %.0f-%.0fm, mid bin=%.0fm)", ...
    cfg.band.min_m, cfg.band.max_m, cfg.f4.mid_bin_m));
set(sg, "Interpreter","none");
save_figure(fig, cfg, "Fig05_UrbMask_Heterogeneity_LinesAndRatio");
close(fig);

% ===================== Fig06: Tunnel inside vs outside bars (unified y per row) =====================
fig = figure("Name","Fig06 Tunnel inside vs outside (bars, unified y-axis)");
set_fig_style(fig, cfg, [1800 800]);
tl = tiledlayout(fig, 2, 3, "TileSpacing","compact", "Padding","compact");

axRow = gobjects(2,3);
rowMax = zeros(2,1);

for iRun = 1:2
    runName = runs(iRun);
    R = pick_run(NoCong, Cong, runName);

    for iC = 1:3
        ret = retAll(iC);
        ax = nexttile(tl, (iRun-1)*3 + iC);
        axRow(iRun,iC) = ax;
        hold(ax,"on");

        f5 = R.Tunnel.(sprintf("ret%d", ret)).f5;
        u = f5.u_centers(:);
        inside = (u >= 0) & (u <= 1);
        outside = ~inside;

        nT_in = sum(f5.n_total(inside));
        nS_in = sum(f5.n_success(inside));
        nP_in = sum(f5.n_success_phy(inside));
        nL_in = sum(f5.n_late(inside));

        nT_out = sum(f5.n_total(outside));
        nS_out = sum(f5.n_success(outside));
        nP_out = sum(f5.n_success_phy(outside));
        nL_out = sum(f5.n_late(outside));

        pdr_in  = safe_div(nS_in, nT_in);
        pdr_out = safe_div(nS_out, nT_out);

        pphy_in  = safe_div(nP_in, nT_in);
        pphy_out = safe_div(nP_out, nT_out);

        late_in  = safe_div(nL_in, nP_in);
        late_out = safe_div(nL_out, nP_out);

        cats = categorical(["inside(0-1)", "outside(<0 or >1)"]);
        vals = [pdr_in, pdr_out];

        b = bar(ax, cats, vals, 0.6);
        b.FaceColor = "flat";
        b.CData(1,:) = [0.20 0.55 0.85];
        b.CData(2,:) = [0.85 0.45 0.20];

        gridify(ax, cfg);
        ylabel(ax, "Timely PDR in band");
        title(ax, sprintf("%s | ret=%d", runName, ret));

        rowMax(iRun) = max(rowMax(iRun), max(vals, [], "omitnan"));

        ax.UserData.ann.vals = vals;
        ax.UserData.ann.txt1 = sprintf("phy=%.3f\nlate=%.3f", pphy_in,  late_in);
        ax.UserData.ann.txt2 = sprintf("phy=%.3f\nlate=%.3f", pphy_out, late_out);
        ax.UserData.ann.nnote = sprintf("nT_in=%d, nT_out=%d", nT_in, nT_out);
    end
end

for iRun = 1:2
    yTop = max(0.12, 1.15*rowMax(iRun));
    for iC = 1:3
        ax = axRow(iRun,iC);
        ylim(ax, [0 yTop]);

        vals = ax.UserData.ann.vals;
        txt1 = ax.UserData.ann.txt1;
        txt2 = ax.UserData.ann.txt2;
        nnote = ax.UserData.ann.nnote;

        dy = 0.02 * yTop;
        text(ax, 1, vals(1) + dy, txt1, "HorizontalAlignment","center", "FontSize", 12);
        text(ax, 2, vals(2) + dy, txt2, "HorizontalAlignment","center", "FontSize", 12);
        text(ax, 0.02, 0.06, nnote, "Units","normalized", "FontSize", 12, "Color",[0.25 0.25 0.25]);
    end
end

sg = sgtitle(tl, sprintf("Tunnel segmented effect (raw band %.0f-%.0fm): inside vs outside | bars=timely PDR, text=phy/late | unified y-lims per row", ...
    cfg.band.min_m, cfg.band.max_m));
set(sg, "Interpreter","none");
save_figure(fig, cfg, "Fig06_Tunnel_InsideOutside_Bars_UnifiedY");
close(fig);

% ===================== Fig07: Summary matrices =====================
fig = figure("Name","Fig07 Summary matrices");
set_fig_style(fig, cfg, [1800 650]);
tl = tiledlayout(fig, 1, 2, "TileSpacing","compact", "Padding","compact");

ax1 = nexttile(tl, 1);
plot_summary_matrix(ax1, cfg, NoCong, "NoCong", [0 1.0]);

ax2 = nexttile(tl, 2);
plot_summary_matrix(ax2, cfg, Cong, "Cong", [0 0.2]);

sg = sgtitle(tl, sprintf("Summary (dist<=%.0fm, weighted from raw cache) | cells: PDR, p95(ms), late(%%)", cfg.plot.focusMax_m));
set(sg, "Interpreter","none");
save_figure(fig, cfg, "Fig07_Summary_Matrices");
close(fig);

end

% ======================================================================================
% Helpers
% ======================================================================================

function R = load_cache(cfg, runId)
cacheDir = fullfile(cfg.cacheRoot, runId);
cacheName = sprintf("rawAgg__dist%gm__delay%gms__band%d-%d.mat", ...
    cfg.dist.bin_m, cfg.delay.bin_ms, int32(cfg.band.min_m), int32(cfg.band.max_m));
cachePath = fullfile(cacheDir, cacheName);
S = load(cachePath, "runAgg");
R = S.runAgg;
end

function R = pick_run(NoCong, Cong, name)
if name == "NoCong"
    R = NoCong;
else
    R = Cong;
end
end

function set_fig_style(fig, cfg, wh)
set(fig, "Color","w");
set(fig, "DefaultTextInterpreter", "none");
set(fig, "DefaultLegendInterpreter", "none");
set(fig, "DefaultAxesTickLabelInterpreter", "none");

set(fig, "DefaultAxesFontName", cfg.style.fontName);
set(fig, "DefaultTextFontName", cfg.style.fontName);

baseFS = max(cfg.style.fontSize, 14);
set(fig, "DefaultAxesFontSize", baseFS);
set(fig, "DefaultTextFontSize", baseFS);
set(fig, "DefaultLineLineWidth", cfg.style.lineWidth);

set(fig, "Units","pixels");
pos = get(fig, "Position");
pos(3) = wh(1); pos(4) = wh(2);
set(fig, "Position", pos);
end

function gridify(ax, cfg)
grid(ax, "on");
ax.GridAlpha = cfg.style.gridAlpha;
ax.MinorGridAlpha = cfg.style.gridAlpha * 0.6;
end

function save_figure(fig, cfg, baseName)
if cfg.export.saveFIG
    savefig(fig, fullfile(cfg.outDir, baseName + ".fig"));
end
if cfg.export.savePDF
    exportgraphics(fig, fullfile(cfg.outDir, baseName + ".pdf"), "ContentType","vector");
end
if cfg.export.savePNG
    exportgraphics(fig, fullfile(cfg.outDir, baseName + ".png"), "Resolution", cfg.export.pngDPI);
end
end

function y = mask_by_n(y, n, th)
y = y(:); n = n(:);
y(n < th) = NaN;
end

function plot_smooth(ax, x, y, cfg, mask, lineStyle, colorRGB)
x = x(:); y = y(:);
x = x(mask); y = y(mask);

finiteMask = isfinite(x) & isfinite(y);
x(~finiteMask) = NaN;
y(~finiteMask) = NaN;

gap = isnan(x) | isnan(y);
idx = find(gap);
cuts = [0; idx; numel(x)+1];

hold(ax,"on");
for k = 1:numel(cuts)-1
    a = cuts(k)+1;
    b = cuts(k+1)-1;
    if b-a+1 < 2
        continue;
    end
    xs = x(a:b);
    ys = y(a:b);

    [xs, ord] = sort(xs);
    ys = ys(ord);

    if cfg.smooth.enabled
        xq = (xs(1):cfg.smooth.dx_m:xs(end)).';
        if numel(xq) < 2
            continue;
        end
        yq = interp1(xs, ys, xq, cfg.smooth.method, "extrap");
        plot(ax, xq, yq, "LineStyle", lineStyle, "Color", colorRGB);
    else
        plot(ax, xs, ys, "LineStyle", lineStyle, "Color", colorRGB);
    end
end
end

function add_ret_legend(fig, retVals, retColors, titleStr)
axRef = findobj(fig, "Type","axes");
if isempty(axRef); axRef = gca; else; axRef = axRef(end); end

h = gobjects(numel(retVals),1);
lab = strings(numel(retVals),1);
for k = 1:numel(retVals)
    h(k) = plot(axRef, NaN, NaN, "-", "Color", retColors(k,:));
    lab(k) = sprintf("ret=%d", retVals(k));
end

lg = legend(axRef, h, lab, "Location","southoutside", "Orientation","horizontal");
lg.Box = "off";
lg.Title.String = titleStr;
lg.FontSize = 12;
try
    lg.Layout.Tile = "south";
catch
end
end

function v = safe_div(a, b)
if b <= 0
    v = NaN;
else
    v = double(a) / double(b);
end
end

function plot_summary_matrix(ax, cfg, R, tag, cax)
scens = cfg.scenarios(:);
rets  = cfg.rets(:);

P = nan(numel(scens), numel(rets));
P95 = nan(numel(scens), numel(rets));
Late = nan(numel(scens), numel(rets));

xDist = R.dist.centers(:);
focus = (xDist <= cfg.plot.focusMax_m);

for iS = 1:numel(scens)
    scen = scens(iS);
    for j = 1:numel(rets)
        ret = rets(j);
        A = R.(scen).(sprintf("ret%d", ret));

        nT = sum(double(A.n_total(focus)));
        nS = sum(double(A.n_success(focus)));
        P(iS,j) = safe_div(nS, nT);

        nP = sum(double(A.n_success_phy(focus)));
        nL = sum(double(A.n_late(focus)));
        Late(iS,j) = safe_div(nL, nP);

        H = A.delay_hist;
        if ~isempty(H)
            hsum = sum(H(focus,:), 1);
            P95(iS,j) = hist_quantile(hsum, R.delay.centers, 0.95);
        end
    end
end

imagesc(ax, P);
colormap(ax, parula);
caxis(ax, cax);
cb = colorbar(ax);
cb.Label.String = "PDR (timely)";
axis(ax, "tight");
set(ax, "YDir","normal");

xticks(ax, 1:numel(rets));
xticklabels(ax, arrayfun(@(r) sprintf("ret=%d", r), rets, "UniformOutput", false));
yticks(ax, 1:numel(scens));
yticklabels(ax, cellstr(scens));

title(ax, tag);

for i = 1:numel(scens)
    for j = 1:numel(rets)
        if isfinite(P(i,j))
            txt = sprintf("PDR=%.3f\np95=%.1fms | late=%.1f%%", P(i,j), P95(i,j), 100*Late(i,j));
        else
            txt = "n/a";
        end
        text(ax, j, i, txt, "HorizontalAlignment","center", "FontSize", 11, "Color","k");
    end
end

xlabel(ax, "retransmissions");
ylabel(ax, "scenario");
end

function qv = hist_quantile(counts, centers, q)
counts = double(counts(:));
if sum(counts) <= 0
    qv = NaN;
    return;
end
cdf = cumsum(counts) / sum(counts);
idx = find(cdf >= q, 1, "first");
if isempty(idx)
    qv = centers(end);
else
    qv = centers(idx);
end
end