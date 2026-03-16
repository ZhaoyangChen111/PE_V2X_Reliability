%% plot_refine_fig2_fig5_only.m
% Refine only Fig2 and Fig5 for the paper.
% - Fig2: compact 2x3 layout, p95 only, better use of vertical space
% - Fig5: keep only the upper heterogeneity panel, add gray blockage bands
%
% Output folder:
% D:\study\France\PE\PE_V2X_Reliability\05_results_A\paper_figures_refined_fig2_fig5

clear; clc; close all;

%% =========================
%  User configuration
%  =========================
root_results = 'D:\study\France\PE\PE_V2X_Reliability\05_results_A';

run_id_no = 'A_Day17_Final_NoCong_S10_v2';
run_id_co = 'A_Day17_Final_Cong_S10_v2';

out_dir = fullfile(root_results, 'paper_figures_refined_fig2_fig5');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

scenarios = {'Ref','UrbMask','Tunnel'};

% Visual styles
lw_main  = 2.2;
lw_minor = 2.0;

c_ret0 = [0.00, 0.4470, 0.7410];
c_ret2 = [0.8500, 0.3250, 0.0980];

c_ret0_fig5 = [0.00, 0.4470, 0.7410];
c_ret2_fig5 = [0.9290, 0.6940, 0.1250];

gray_band_color = [0.75, 0.75, 0.75];
gray_band_alpha = 0.20;

font_axis  = 11;
font_title = 14;
font_note  = 10;

%% =========================
%  FIG2: p95 only, compact 2x3
%  Top row    = ret=2
%  Bottom row = ret=0
%  Solid      = NoCong
%  Dotted     = Cong
%  =========================
fig2 = figure('Color','w', 'Position',[60 60 1850 980]);

tl2 = tiledlayout(2,3, 'TileSpacing','compact', 'Padding','compact');

% Keep handles from first plotted panel if needed later
h_r0_no = gobjects(1);
h_r0_co = gobjects(1);
h_r2_no = gobjects(1);
h_r2_co = gobjects(1);

for i = 1:numel(scenarios)
    sc = scenarios{i};

    % -------- top row: ret=2 --------
    ax = nexttile(tl2, i);
    hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');

    T_no = read_summary_table(root_results, run_id_no, sc, 2);
    T_co = read_summary_table(root_results, run_id_co, sc, 2);

    x_no = get_numeric_col(T_no, ["dist_bin_center","dist_center_m","distance_m"]);
    y_no = get_numeric_col(T_no, ["delay_p95_ms","p95_ms","delay_p95"]);
    x_co = get_numeric_col(T_co, ["dist_bin_center","dist_center_m","distance_m"]);
    y_co = get_numeric_col(T_co, ["delay_p95_ms","p95_ms","delay_p95"]);

    m_no = isfinite(x_no) & isfinite(y_no) & x_no >= 0 & x_no <= 200;
    m_co = isfinite(x_co) & isfinite(y_co) & x_co >= 0 & x_co <= 200;

    [x_no, idx] = sort(x_no(m_no)); y_no = y_no(m_no); y_no = y_no(idx);
    [x_co, idx] = sort(x_co(m_co)); y_co = y_co(m_co); y_co = y_co(idx);

    h1 = plot(ax, x_no, y_no, '-',  'Color', c_ret2, 'LineWidth', lw_main);
    h2 = plot(ax, x_co, y_co, ':',  'Color', c_ret2, 'LineWidth', lw_minor);

    if i == 1
        h_r2_no = h1;
        h_r2_co = h2;
    end

    xlim(ax, [0 200]);
    ylim(ax, [15 48]);
    xticks(ax, 0:50:200);

    title(ax, sprintf('%s\nret=2', sc), 'FontSize', font_title, 'FontWeight','normal');
    ylabel(ax, 'p95 delay (ms)', 'FontSize', font_axis);

    if i == 1
        text(ax, 0.03, 0.08, ...
            'Upper: ret=2 | Solid=NoCong, Dotted=Cong', ...
            'Units','normalized', 'FontSize', font_note, 'Color',[0.25 0.25 0.25], ...
            'HorizontalAlignment','left', 'VerticalAlignment','bottom');
    end

    % -------- bottom row: ret=0 --------
    ax = nexttile(tl2, i+3);
    hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');

    T_no = read_summary_table(root_results, run_id_no, sc, 0);
    T_co = read_summary_table(root_results, run_id_co, sc, 0);

    x_no = get_numeric_col(T_no, ["dist_bin_center","dist_center_m","distance_m"]);
    y_no = get_numeric_col(T_no, ["delay_p95_ms","p95_ms","delay_p95"]);
    x_co = get_numeric_col(T_co, ["dist_bin_center","dist_center_m","distance_m"]);
    y_co = get_numeric_col(T_co, ["delay_p95_ms","p95_ms","delay_p95"]);

    m_no = isfinite(x_no) & isfinite(y_no) & x_no >= 0 & x_no <= 200;
    m_co = isfinite(x_co) & isfinite(y_co) & x_co >= 0 & x_co <= 200;

    [x_no, idx] = sort(x_no(m_no)); y_no = y_no(m_no); y_no = y_no(idx);
    [x_co, idx] = sort(x_co(m_co)); y_co = y_co(m_co); y_co = y_co(idx);

    h1 = plot(ax, x_no, y_no, '-',  'Color', c_ret0, 'LineWidth', lw_main);
    h2 = plot(ax, x_co, y_co, ':',  'Color', c_ret0, 'LineWidth', lw_minor);

    if i == 1
        h_r0_no = h1;
        h_r0_co = h2;
    end

    xlim(ax, [0 200]);
    ylim(ax, [0 8.5]);
    xticks(ax, 0:50:200);

    title(ax, 'ret=0', 'FontSize', font_title-1, 'FontWeight','normal');
    xlabel(ax, 'Distance (m)', 'FontSize', font_axis);
    ylabel(ax, 'p95 delay (ms)', 'FontSize', font_axis);

    if i == 1
        text(ax, 0.03, 0.08, ...
            'Lower: ret=0 | Solid=NoCong, Dotted=Cong', ...
            'Units','normalized', 'FontSize', font_note, 'Color',[0.25 0.25 0.25], ...
            'HorizontalAlignment','left', 'VerticalAlignment','bottom');
    end
end

sgtitle(tl2, 'Tail delay of timely successes versus distance (p95 only)', ...
    'FontSize', 18, 'FontWeight','normal');

% Create a small custom legend using annotation, to avoid tiledlayout legend issues
annotation(fig2,'textbox',[0.36 0.005 0.30 0.03], ...
    'String','Blue = ret=0, Orange = ret=2 | Solid = NoCong, Dotted = Cong', ...
    'EdgeColor','none', 'HorizontalAlignment','center', ...
    'FontSize',11, 'FontWeight','normal');

drawnow;

exportgraphics(fig2, fullfile(out_dir, 'Fig02_refined_p95_compact.png'), 'Resolution', 350);
exportgraphics(fig2, fullfile(out_dir, 'Fig02_refined_p95_compact.pdf'), 'ContentType','vector');

%% =========================
%  FIG5: keep only the upper panel
%  Use NoCong only, ret=0 and ret=2
%  Add gray blockage bands inferred from UrbMask model
%  =========================
fig5 = figure('Color','w', 'Position',[80 80 1850 760]);

ax5 = axes(fig5);
hold(ax5, 'on'); box(ax5, 'on'); grid(ax5, 'on');

% ------------------------------------------------------------
% Main curves: use standard heterogeneity tables (NoCong)
% ------------------------------------------------------------
Tb0 = readtable(fullfile(root_results, 'runs', run_id_no, 'tables', ...
    'position_heterogeneity__UrbMask__ret0__band80-100__seed1-10.csv'), ...
    'VariableNamingRule','preserve');

Tb2 = readtable(fullfile(root_results, 'runs', run_id_no, 'tables', ...
    'position_heterogeneity__UrbMask__ret2__band80-100__seed1-10.csv'), ...
    'VariableNamingRule','preserve');

x0 = get_numeric_col(Tb0, ["mid_x_bin_center","mid_x_center","mid_x"]);
x2 = get_numeric_col(Tb2, ["mid_x_bin_center","mid_x_center","mid_x"]);

y0 = get_numeric_col_allow_missing(Tb0, ...
    ["timely_success_rate","pdr_band","phy_success_rate"], nan(size(x0)));
y2 = get_numeric_col_allow_missing(Tb2, ...
    ["timely_success_rate","pdr_band","phy_success_rate"], nan(size(x2)));

n0 = get_numeric_col_allow_missing(Tb0, ["n_total"], inf(size(x0)));
n2 = get_numeric_col_allow_missing(Tb2, ["n_total"], inf(size(x2)));

% Remove sparse bins at the far tail to avoid misleading sharp collapse
min_count_main = 50;

m0 = isfinite(x0) & isfinite(y0) & isfinite(n0) & x0 >= 0 & x0 <= 3000 & n0 >= min_count_main;
m2 = isfinite(x2) & isfinite(y2) & isfinite(n2) & x2 >= 0 & x2 <= 3000 & n2 >= min_count_main;

[x0, idx] = sort(x0(m0)); y0 = y0(m0); y0 = y0(idx);
[x2, idx] = sort(x2(m2)); y2 = y2(m2); y2 = y2(idx);

% Light smoothing only for visual continuity
if numel(y0) >= 3
    y0_plot = movmean(y0, 3, 'omitnan');
else
    y0_plot = y0;
end

if numel(y2) >= 3
    y2_plot = movmean(y2, 3, 'omitnan');
else
    y2_plot = y2;
end

% ------------------------------------------------------------
% Gray blockage bands: use TCE heterogeneity table, because it
% contains avg_blockage_b from the UrbMask construction
% ------------------------------------------------------------
Tb_band = readtable(fullfile(root_results, 'runs', run_id_no, 'tables', ...
    'tce_position_heterogeneity__UrbMask__ret0__pre_crash__band80-100__seed1-10.csv'), ...
    'VariableNamingRule','preserve');

xb = get_numeric_col(Tb_band, ["mid_x_bin_center","mid_x_center","mid_x"]);
bb = get_numeric_col_allow_missing(Tb_band, ...
    ["avg_blockage_b","blockage_b","blockage_score"], nan(size(xb)));
nb = get_numeric_col_allow_missing(Tb_band, ["n_total"], inf(size(xb)));

min_count_band = 50;
mb = isfinite(xb) & isfinite(bb) & isfinite(nb) & xb >= 0 & xb <= 3000 & nb >= min_count_band;

[xb, idx] = sort(xb(mb));
bb = bb(mb); bb = bb(idx);

band_intervals = zeros(0,2);

if ~isempty(bb)
    bb_norm = normalize_to_01(bb);

    if numel(bb_norm) >= 3
        bb_norm = movmean(bb_norm, 3, 'omitnan');
    end

    % Threshold for "high blockage" bands
    high_mask = bb_norm >= 0.58;

    % Fill very short gaps so that bands look like regions
    high_mask = close_small_false_gaps(high_mask, 2);

    band_intervals = mask_to_intervals(xb, high_mask);
end

% ------------------------------------------------------------
% Draw bands first
% ------------------------------------------------------------
y_max_data = max([y0_plot(:); y2_plot(:)], [], 'omitnan');
if isempty(y_max_data) || ~isfinite(y_max_data)
    y_max_data = 0.7;
end
y_top = max(0.72, 1.08 * y_max_data);

for k = 1:size(band_intervals,1)
    xl = band_intervals(k,1);
    xr = band_intervals(k,2);
    patch(ax5, [xl xr xr xl], [0 0 y_top y_top], gray_band_color, ...
        'FaceAlpha', gray_band_alpha, ...
        'EdgeColor','none', ...
        'HandleVisibility','off');
end

% ------------------------------------------------------------
% Draw main curves
% ------------------------------------------------------------
h50 = plot(ax5, x0, y0_plot, '-', 'Color', c_ret0_fig5, 'LineWidth', 2.4);
h52 = plot(ax5, x2, y2_plot, '-', 'Color', c_ret2_fig5, 'LineWidth', 2.4);

xlim(ax5, [0 3000]);
ylim(ax5, [0 y_top]);

xlabel(ax5, 'mid\_x (m)', 'FontSize', font_axis);
ylabel(ax5, 'PDR\_band (NoCong)', 'FontSize', font_axis);

title(ax5, sprintf(['UrbMask spatial heterogeneity (band 80-100 m)\n' ...
    'Gray bands: high-blockage intervals inferred from the UrbMask model']), ...
    'FontSize', 17, 'FontWeight','normal');

legend(ax5, [h50 h52], {'ret=0','ret=2'}, ...
    'Location','southoutside', 'Orientation','horizontal', ...
    'Box','off', 'FontSize',11);

text(ax5, 0.02, 0.93, ...
    'Gray bands indicate high-blockage segments inferred from the UrbMask construction.', ...
    'Units','normalized', 'FontSize',11, 'Color',[0.35 0.35 0.35], ...
    'HorizontalAlignment','left', 'VerticalAlignment','top');

drawnow;

exportgraphics(fig5, fullfile(out_dir, 'Fig05_refined_urbmask_upper_only.png'), 'Resolution', 350);
exportgraphics(fig5, fullfile(out_dir, 'Fig05_refined_urbmask_upper_only.pdf'), 'ContentType','vector');

%% =========================
%  Local helper functions
%  =========================
function T = read_summary_table(root_results, run_id, scenario, retrans)
    f = fullfile(root_results, 'runs', run_id, 'tables', ...
        sprintf('summary_metrics__%s__ret%d__seed1-10.csv', scenario, retrans));
    if ~isfile(f)
        error('Summary CSV not found:\n%s', f);
    end
    T = readtable(f, 'VariableNamingRule','preserve');
end

function T = read_heterogeneity_table(root_results, run_id, scenario, retrans)
    f1 = fullfile(root_results, 'runs', run_id, 'tables', ...
        sprintf('position_heterogeneity__%s__ret%d__band80-100__seed1-10.csv', scenario, retrans));
    f2 = fullfile(root_results, 'runs', run_id, 'tables', ...
        sprintf('tce_position_heterogeneity__%s__ret%d__pre_crash__band80-100__seed1-10.csv', scenario, retrans));

    if isfile(f1)
        T = readtable(f1, 'VariableNamingRule','preserve');
    elseif isfile(f2)
        T = readtable(f2, 'VariableNamingRule','preserve');
    else
        error('No heterogeneity CSV found for %s ret=%d.\nTried:\n%s\n%s', ...
            scenario, retrans, f1, f2);
    end
end

function v = get_numeric_col(T, names)
    names = string(names);
    vn = string(T.Properties.VariableNames);

    idx = find(ismember(vn, names), 1, 'first');
    if isempty(idx)
        error('Column not found: %s', strjoin(names, ' / '));
    end

    raw = T.(T.Properties.VariableNames{idx});
    v = convert_to_numeric_vector(raw);
end

function v = get_numeric_col_allow_missing(T, names, default_val)
    names = string(names);
    vn = string(T.Properties.VariableNames);

    idx = find(ismember(vn, names), 1, 'first');
    if isempty(idx)
        v = default_val;
        return;
    end

    raw = T.(T.Properties.VariableNames{idx});
    v = convert_to_numeric_vector(raw);
end

function v = convert_to_numeric_vector(raw)
    if isnumeric(raw)
        v = double(raw);
        return;
    end

    if islogical(raw)
        v = double(raw);
        return;
    end

    if iscell(raw)
        try
            v = cellfun(@str2double, raw);
        catch
            v = nan(size(raw));
            for k = 1:numel(raw)
                try
                    v(k) = str2double(string(raw{k}));
                catch
                    v(k) = NaN;
                end
            end
        end
        v = double(v(:));
        return;
    end

    if isstring(raw)
        v = str2double(raw);
        v = double(v(:));
        return;
    end

    if ischar(raw)
        v = str2double(string(raw));
        v = double(v(:));
        return;
    end

    try
        v = str2double(string(raw));
        v = double(v(:));
    catch
        error('Unsupported column type for numeric conversion.');
    end
end

function y = normalize_to_01(x)
    x = double(x(:));
    xmin = min(x, [], 'omitnan');
    xmax = max(x, [], 'omitnan');

    if ~isfinite(xmin) || ~isfinite(xmax) || abs(xmax - xmin) < 1e-12
        y = zeros(size(x));
    else
        y = (x - xmin) ./ (xmax - xmin);
    end
end

function mask2 = close_small_false_gaps(mask, max_gap_len)
    % Fill short false gaps between true runs
    mask = logical(mask(:));
    mask2 = mask;

    n = numel(mask2);
    i = 1;
    while i <= n
        if ~mask2(i)
            j = i;
            while j <= n && ~mask2(j)
                j = j + 1;
            end

            left_true  = (i > 1) && mask2(i-1);
            right_true = (j <= n) && mask2(j);

            gap_len = j - i;
            if left_true && right_true && gap_len <= max_gap_len
                mask2(i:j-1) = true;
            end
            i = j;
        else
            i = i + 1;
        end
    end
end

function intervals = mask_to_intervals(x, mask)
    x = x(:);
    mask = logical(mask(:));

    if isempty(x) || isempty(mask) || numel(x) ~= numel(mask)
        intervals = zeros(0,2);
        return;
    end

    dx = median(diff(x), 'omitnan');
    if ~isfinite(dx) || dx <= 0
        dx = 10;
    end

    d = diff([false; mask; false]);
    starts = find(d == 1);
    ends   = find(d == -1) - 1;

    intervals = zeros(numel(starts), 2);
    for k = 1:numel(starts)
        xl = x(starts(k)) - dx/2;
        xr = x(ends(k))   + dx/2;
        intervals(k,:) = [xl, xr];
    end
end