function plot_tce_fig07_urbmask()
% Standalone TCE figure generator for UrbMask only.
% This script does not modify the old raw-cache figure pipeline.
%
% It uses both Day17 frozen runs:
%   - A_Day17_Final_Cong_S10_v2   -> main figure for report
%   - A_Day17_Final_NoCong_S10_v2 -> backup figure for appendix / notes
%
% Output:
%   - Fig07_TCE_UrbMask_Cong.{png,pdf,fig}
%   - Fig07b_TCE_UrbMask_NoCong_backup.{png,pdf,fig}

clc;

% -------------------------------------------------------------------------
% Path setup
% -------------------------------------------------------------------------
thisDir = fileparts(mfilename('fullpath'));   % ...\03_sim_A\matlab
simADir = fileparts(thisDir);                 % ...\03_sim_A
projDir = fileparts(simADir);                 % ...\PE_V2X_Reliability
runsRoot = fullfile(projDir, "05_results_A", "runs");

% -------------------------------------------------------------------------
% Common settings
% -------------------------------------------------------------------------
scenario     = "UrbMask";
profile      = "pre_crash";
profileLabel = "pre-crash";
rets         = [0 2];

xMax_m      = 3000;
yMax_main   = 0.60;
minTotalBin = 1000;
smoothWin   = 5;      % 5 bins x 5 m
interpDx_m  = 1.0;    % display interpolation only

fontName = "Times New Roman";
fontSize = 14;

cPhy    = [0.10 0.35 0.85];
cTCE    = [0.90 0.45 0.10];
cTimely = [0.15 0.65 0.25];

set(groot, "defaultTextInterpreter", "none");
set(groot, "defaultLegendInterpreter", "none");
set(groot, "defaultAxesTickLabelInterpreter", "none");

% -------------------------------------------------------------------------
% Job list: use both frozen runs
% -------------------------------------------------------------------------
jobs = struct([]);

jobs(1).runId      = "A_Day17_Final_Cong_S10_v2";
jobs(1).condLabel  = "Cong";
jobs(1).saveBase   = "Fig07_TCE_UrbMask_Cong";
jobs(1).titleText  = "UrbMask TCE utility decomposition | Cong | pre-crash | ret=0 vs ret=2";

jobs(2).runId      = "A_Day17_Final_NoCong_S10_v2";
jobs(2).condLabel  = "NoCong";
jobs(2).saveBase   = "Fig07b_TCE_UrbMask_NoCong_backup";
jobs(2).titleText  = "UrbMask TCE utility decomposition | NoCong | pre-crash | ret=0 vs ret=2";

% -------------------------------------------------------------------------
% Build figures
% -------------------------------------------------------------------------
for iJob = 1:numel(jobs)
    runId     = jobs(iJob).runId;
    condLabel = jobs(iJob).condLabel;
    saveBase  = jobs(iJob).saveBase;
    titleText = jobs(iJob).titleText;

    tablesDir = fullfile(runsRoot, runId, "tables");
    figDir    = fullfile(runsRoot, runId, "figures");

    if ~exist(figDir, 'dir')
        mkdir(figDir);
    end

    curveCell   = cell(1, numel(rets));
    summaryCell = cell(1, numel(rets));

    for k = 1:numel(rets)
        ret = rets(k);

        bydistPath = find_latest_file( ...
            tablesDir, ...
            sprintf("tce_by_distance__%s__ret%d__%s__*.csv", char(scenario), ret, char(profile)) ...
        );

        summaryPath = find_latest_file( ...
            tablesDir, ...
            sprintf("tce_summary__%s__ret%d__%s__*.csv", char(scenario), ret, char(profile)) ...
        );

        T = readtable(bydistPath);
        S = readtable(summaryPath);

        curveCell{k}   = prepare_curve(T, xMax_m, minTotalBin, smoothWin, interpDx_m);
        summaryCell{k} = S;

        fprintf("[OK] %s | ret=%d | by-distance -> %s\n", condLabel, ret, bydistPath);
        fprintf("[OK] %s | ret=%d | summary     -> %s\n", condLabel, ret, summaryPath);
    end

    build_pair_figure( ...
        curveCell, summaryCell, rets, scenario, condLabel, profileLabel, ...
        xMax_m, yMax_main, minTotalBin, ...
        cPhy, cTCE, cTimely, ...
        fontName, fontSize, ...
        figDir, saveBase, titleText ...
    );
end

fprintf("[DONE] UrbMask TCE figures generated for both Cong and NoCong.\n");

end

% =========================================================================
% Figure builder
% =========================================================================
function build_pair_figure(curveCell, summaryCell, rets, scenario, condLabel, profileLabel, ...
    xMax_m, yTop, minTotalBin, ...
    cPhy, cTCE, cTimely, ...
    fontName, fontSize, ...
    figDir, baseName, titleText)

fig = figure('Color','w', 'Position', [90 90 1550 650]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing','compact', 'Padding','compact');

hLegend = gobjects(3,1);

for k = 1:numel(rets)
    ret = rets(k);
    C = curveCell{k};
    S = summaryCell{k};

    ax = nexttile(tl, k);
    hold(ax, 'on');

    h1 = plot(ax, C.x_phy,    C.y_phy,    '--', 'Color', cPhy,    'LineWidth', 2.6);
    h2 = plot(ax, C.x_tce,    C.y_tce,    '-',  'Color', cTCE,    'LineWidth', 3.0);
    h3 = plot(ax, C.x_timely, C.y_timely, '-.', 'Color', cTimely, 'LineWidth', 2.6);

    if k == 1
        hLegend(1) = h1;
        hLegend(2) = h2;
        hLegend(3) = h3;
    end

    % Structural reference lines for UrbMask
    xline(ax, 1000, ':', 'Color', [0.60 0.60 0.60], 'LineWidth', 1.0);
    xline(ax, 2000, ':', 'Color', [0.60 0.60 0.60], 'LineWidth', 1.0);

    grid(ax, 'on');
    ax.GridAlpha = 0.25;
    ax.FontName = fontName;
    ax.FontSize = fontSize;

    xlim(ax, [0 xMax_m]);
    ylim(ax, [0 yTop]);

    xlabel(ax, 'Distance (m)', 'FontName', fontName, 'FontSize', fontSize);
    ylabel(ax, 'Rate / utility', 'FontName', fontName, 'FontSize', fontSize);
    title(ax, sprintf('%s | %s | ret=%d', char(scenario), char(condLabel), ret), ...
        'FontName', fontName, 'FontSize', fontSize + 1);

    if ~isempty(S) && height(S) >= 1
        txt1 = sprintf('Overall: PHY=%.3f | TCE=%.3f | Timely=%.3f', ...
            S.phy_success_rate(1), S.tce(1), S.timely_success_rate(1));

        txt2 = sprintf('Late gain=%.3f | late/PHY=%.3f', ...
            S.late_partial_gain(1), S.late_ratio_phy(1));

        text(ax, 0.02, 0.96, txt1, ...
            'Units','normalized', ...
            'HorizontalAlignment','left', ...
            'VerticalAlignment','top', ...
            'FontName', fontName, ...
            'FontSize', fontSize - 1, ...
            'Color', [0.15 0.15 0.15]);

        text(ax, 0.02, 0.90, txt2, ...
            'Units','normalized', ...
            'HorizontalAlignment','left', ...
            'VerticalAlignment','top', ...
            'FontName', fontName, ...
            'FontSize', fontSize - 1, ...
            'Color', [0.15 0.15 0.15]);
    end

    text(ax, 0.02, 0.04, ...
        sprintf('%s | 5 m bins | n >= %d | light smoothing', char(profileLabel), minTotalBin), ...
        'Units','normalized', ...
        'FontName', fontName, ...
        'FontSize', fontSize - 2, ...
        'Color', [0.28 0.28 0.28]);
end

lg = legend(hLegend, {'PHY success','TCE','Timely success'}, ...
    'Location','northoutside', 'Orientation','horizontal');
lg.Box = 'off';
lg.FontName = fontName;
lg.FontSize = fontSize - 1;
try
    lg.Layout.Tile = 'north';
catch
end

sgtitle(tl, titleText, 'FontName', fontName, 'FontSize', fontSize + 2);

figPathFIG = fullfile(figDir, baseName + ".fig");
figPathPNG = fullfile(figDir, baseName + ".png");
figPathPDF = fullfile(figDir, baseName + ".pdf");

savefig(fig, figPathFIG);
exportgraphics(fig, figPathPNG, 'Resolution', 450);
exportgraphics(fig, figPathPDF, 'ContentType', 'vector');

fprintf("[OK] Saved figure -> %s\n", figPathPNG);
fprintf("[OK] Saved figure -> %s\n", figPathPDF);

close(fig);

end

% =========================================================================
% Curve preparation
% =========================================================================
function C = prepare_curve(T, xMax_m, minTotalBin, smoothWin, interpDx_m)

x = as_col(T.dist_bin_center);
phy    = as_col(T.phy_success_rate);
tce    = as_col(T.tce);
timely = as_col(T.timely_success_rate);

if ismember('n_total', T.Properties.VariableNames)
    nTotal = as_col(T.n_total);
else
    nTotal = nan(size(x));
end

mask = isfinite(x) & (x <= xMax_m);

if all(isfinite(nTotal))
    mask = mask & (nTotal >= minTotalBin);
end

phy(~mask)    = NaN;
tce(~mask)    = NaN;
timely(~mask) = NaN;

phy    = movmean(phy,    smoothWin, 'omitnan');
tce    = movmean(tce,    smoothWin, 'omitnan');
timely = movmean(timely, smoothWin, 'omitnan');

[x_phy,    y_phy]    = interp_segments(x, phy,    interpDx_m);
[x_tce,    y_tce]    = interp_segments(x, tce,    interpDx_m);
[x_timely, y_timely] = interp_segments(x, timely, interpDx_m);

C = struct();
C.x_phy    = x_phy;
C.y_phy    = y_phy;
C.x_tce    = x_tce;
C.y_tce    = y_tce;
C.x_timely = x_timely;
C.y_timely = y_timely;

end

% =========================================================================
% Segment-wise interpolation
% =========================================================================
function [xOut, yOut] = interp_segments(x, y, dx)

x = x(:);
y = y(:);

good = isfinite(x) & isfinite(y);
x(~good) = NaN;
y(~good) = NaN;

gapIdx = find(isnan(x) | isnan(y));
cuts = [0; gapIdx; numel(x)+1];

xOut = [];
yOut = [];

for i = 1:numel(cuts)-1
    a = cuts(i) + 1;
    b = cuts(i+1) - 1;

    if b - a + 1 < 2
        continue;
    end

    xs = x(a:b);
    ys = y(a:b);

    [xs, ord] = sort(xs);
    ys = ys(ord);

    xq = (xs(1):dx:xs(end)).';
    if numel(xq) < 2
        continue;
    end

    yq = interp1(xs, ys, xq, 'pchip');

    if isempty(xOut)
        xOut = xq;
        yOut = yq;
    else
        xOut = [xOut; NaN; xq]; %#ok<AGROW>
        yOut = [yOut; NaN; yq]; %#ok<AGROW>
    end
end

end

% =========================================================================
% Utilities
% =========================================================================
function p = find_latest_file(folderPath, pattern)
D = dir(fullfile(folderPath, pattern));
if isempty(D)
    error('Cannot find file: %s', fullfile(folderPath, pattern));
end
[~, idx] = max([D.datenum]);
p = fullfile(folderPath, D(idx).name);
end

function x = as_col(v)
x = double(v(:));
end