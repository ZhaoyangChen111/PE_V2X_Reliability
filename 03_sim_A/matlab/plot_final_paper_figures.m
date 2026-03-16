function plot_final_paper_figures()
% PLOT_FINAL_PAPER_FIGURES
% Final paper-ready MATLAB figures for the PE report.
%
% Main refinements in this version:
%   - Save figures into a timestamped folder under 05_results_A
%   - Unified top-title font size across all 7 figures
%   - Fig1 / Fig2: move global notes upward to avoid overlap with x-labels
%   - Fig4: clearer scenario-vs-mean rendering, and fix p_col title text
%   - Fig4: keep only one mean line for a cleaner presentation
%   - Fig5: use a tiledlayout title with the same size as the other figures
%   - Fig6: multiline text layout above bars + separate n labels below bars
%   - Fig7: remove in-panel summary text and keep only the curves + bottom legend
%
% Recommended working directory:
%   D:\study\France\PE\PE_V2X_Reliability\03_sim_A\py
%
% The script assumes the following run folders exist:
%   A_Day17_Final_NoCong_S10_v2
%   A_Day17_Final_Cong_S10_v2

    close all;

    %% -------------------- User settings --------------------
    ridNo = 'A_Day17_Final_NoCong_S10_v2';
    ridCo = 'A_Day17_Final_Cong_S10_v2';

    scenarios = {'Ref','UrbMask','Tunnel'};
    retAll = [0 1 2];

    % Colors
    cRet0   = [0.0000 0.4470 0.7410];
    cRet1   = [0.8500 0.3250 0.0980];
    cRet2   = [0.9290 0.6940 0.1250];
    cGray   = [0.72 0.72 0.72];
    cMean   = [0.00 0.32 0.72];
    cTimely = [0.18 0.67 0.22];

    % Fig4 scenario colors (clearer than light gray-only)
    cRefLine = [0.55 0.55 0.55];
    cUrbLine = [0.88 0.43 0.12];
    cTunLine = [0.20 0.62 0.40];

    % Common styles
    lwMain = 2.4;
    lwAux  = 2.0;
    lwThin = 1.15;
    fsAx   = 13;
    fsTop  = 23;   % unified top-title size for all 7 figures
    fsSub  = 17;
    fsLab  = 15;
    fsAnno = 12;

    % Figure export
    thisDir = fileparts(mfilename('fullpath'));
    if isempty(thisDir)
        thisDir = pwd;
    end
    runsDir = fullfile(thisDir, '..', '..', '05_results_A', 'runs');

    outRoot = fullfile(thisDir, '..', '..', '05_results_A');
    stamp   = datestr(now, 'yyyymmdd_HHMMSS');
    outDir  = fullfile(outRoot, ['paper_figs_matlab_' stamp]);
    ensure_dir(outDir);

    %% ======================================================
    %% Fig1: Timely reliability versus distance
    %% ======================================================
    f1 = figure('Color','w','Position',[60 60 1760 620]);
    tl1 = tiledlayout(1,3,'TileSpacing','compact','Padding','compact');
    title(tl1, 'Timely reliability versus distance (dist<=200 m)', ...
        'FontSize', fsTop, 'FontWeight', 'normal');

    retColors = {cRet0, cRet1, cRet2};
    axList1 = gobjects(numel(scenarios),1);

    axTop2 = gobjects(numel(scenarios),1);
    axBot2 = gobjects(numel(scenarios),1);

    for iS = 1:numel(scenarios)
        sc = scenarios{iS};
        ax = nexttile(tl1);
        axList1(iS) = ax;
        hold(ax,'on'); grid(ax,'on'); box(ax,'on');

        for iR = 1:numel(retAll)
            r = retAll(iR);
            Tno = read_csv_safe(runsDir, ridNo, sprintf('summary_metrics__%s__ret%d__seed1-10.csv', sc, r));
            Tco = read_csv_safe(runsDir, ridCo, sprintf('summary_metrics__%s__ret%d__seed1-10.csv', sc, r));

            xNo = choose_numeric_col(Tno, {'dist_bin_center','dist_m','distance_m'});
            yNo = choose_numeric_col(Tno, {'timely_success_rate','pdr','pdr_timely','timely_pdr'});
            xCo = choose_numeric_col(Tco, {'dist_bin_center','dist_m','distance_m'});
            yCo = choose_numeric_col(Tco, {'timely_success_rate','pdr','pdr_timely','timely_pdr'});

            plot(ax, xNo, yNo, '-', 'Color', retColors{iR}, 'LineWidth', lwMain);
            plot(ax, xCo, yCo, ':', 'Color', retColors{iR}, 'LineWidth', lwAux);
        end

        title(ax, sc, 'FontSize', fsSub, 'FontWeight', 'normal');
        xlabel(ax, 'Distance (m)', 'FontSize', fsLab);
        ylabel(ax, 'PDR (timely)', 'FontSize', fsLab);
        xlim(ax, [0 200]);
        ylim(ax, [0 1.0]);
        set(ax, 'FontSize', fsAx);
    end

    h11 = plot(axList1(1), nan, nan, '-', 'Color', cRet0, 'LineWidth', lwMain);
    h12 = plot(axList1(1), nan, nan, '-', 'Color', cRet1, 'LineWidth', lwMain);
    h13 = plot(axList1(1), nan, nan, '-', 'Color', cRet2, 'LineWidth', lwMain);
    h14 = plot(axList1(1), nan, nan, '-', 'Color', [0.20 0.20 0.20], 'LineWidth', lwMain);
    h15 = plot(axList1(1), nan, nan, ':', 'Color', [0.20 0.20 0.20], 'LineWidth', lwAux);
    lg1 = legend(axList1(1), [h11 h12 h13 h14 h15], ...
        {'blue=ret0','orange=ret1','yellow=ret2','solid=NoCong','dotted=Cong'}, ...
        'Orientation','horizontal', 'Box','off', 'FontSize', fsAnno);
    lg1.Layout.Tile = 'south';

    save_fig(f1, outDir, 'Fig01_timely_reliability_vs_distance');

    %% ======================================================
    %% Fig2: Tail delay (p95 and p99), compact 2x3 layout
    %% Row 1 = ret=2, Row 2 = ret=0
    %% Color = percentile (blue=p95, orange=p99)
    %% Style = condition (solid=NoCong, dotted=Cong)
    %% ======================================================
    f2 = figure('Color','w','Position',[60 60 1760 800]);
    tl2 = tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
    title(tl2, 'Tail delay of timely successes versus distance (p95 and p99)', ...
        'FontSize', fsTop, 'FontWeight', 'normal');

    axTop2 = gobjects(numel(scenarios),1);
    axBot2 = gobjects(numel(scenarios),1);

    cP95 = [0.0000 0.4470 0.7410];
    cP99 = [0.8500 0.3250 0.0980];

    for iS = 1:numel(scenarios)
        sc = scenarios{iS};

        % ---------- upper: ret=2 ----------
        axU = nexttile(tl2, iS);
        axTop2(iS) = axU;
        hold(axU,'on'); grid(axU,'on'); box(axU,'on');

        Tno2 = read_csv_safe(runsDir, ridNo, sprintf('summary_metrics__%s__ret2__seed1-10.csv', sc));
        Tco2 = read_csv_safe(runsDir, ridCo, sprintf('summary_metrics__%s__ret2__seed1-10.csv', sc));

        xNo2   = choose_numeric_col(Tno2, {'dist_bin_center','dist_center_m','distance_m','dist_m'});
        p95No2 = choose_numeric_col(Tno2, {'delay_p95_ms','p95_ms','delay_p95','p95'});
        p99No2 = choose_numeric_col(Tno2, {'delay_p99_ms','p99_ms','delay_p99','p99'});

        xCo2   = choose_numeric_col(Tco2, {'dist_bin_center','dist_center_m','distance_m','dist_m'});
        p95Co2 = choose_numeric_col(Tco2, {'delay_p95_ms','p95_ms','delay_p95','p95'});
        p99Co2 = choose_numeric_col(Tco2, {'delay_p99_ms','p99_ms','delay_p99','p99'});

        mNo2 = isfinite(xNo2) & xNo2 >= 0 & xNo2 <= 200;
        mCo2 = isfinite(xCo2) & xCo2 >= 0 & xCo2 <= 200;

        [xNo2s, p95No2s] = sort_xy_masked(xNo2, p95No2, mNo2);
        [~,      p99No2s] = sort_xy_masked(xNo2, p99No2, mNo2);
        [xCo2s, p95Co2s] = sort_xy_masked(xCo2, p95Co2, mCo2);
        [~,      p99Co2s] = sort_xy_masked(xCo2, p99Co2, mCo2);

        plot(axU, xNo2s, p95No2s, '-', 'Color', cP95, 'LineWidth', lwMain);
        plot(axU, xCo2s, p95Co2s, ':', 'Color', cP95, 'LineWidth', lwAux);
        plot(axU, xNo2s, p99No2s, '-', 'Color', cP99, 'LineWidth', lwMain);
        plot(axU, xCo2s, p99Co2s, ':', 'Color', cP99, 'LineWidth', lwAux);

        yTopU = max([p95No2s(:); p99No2s(:); p95Co2s(:); p99Co2s(:)], [], 'omitnan');
        if isempty(yTopU) || ~isfinite(yTopU)
            yTopU = 48;
        end

        xlim(axU, [0 200]);
        ylim(axU, [15 max(48, 1.05*yTopU)]);
        xticks(axU, 0:50:200);
        title(axU, sprintf('%s\nret=2', sc), 'FontSize', fsSub-1, 'FontWeight','normal');
        ylabel(axU, 'delay (ms)', 'FontSize', fsLab);
        set(axU, 'FontSize', fsAx);

        % ---------- lower: ret=0 ----------
        axL = nexttile(tl2, 3+iS);
        axBot2(iS) = axL;
        hold(axL,'on'); grid(axL,'on'); box(axL,'on');

        Tno0 = read_csv_safe(runsDir, ridNo, sprintf('summary_metrics__%s__ret0__seed1-10.csv', sc));
        Tco0 = read_csv_safe(runsDir, ridCo, sprintf('summary_metrics__%s__ret0__seed1-10.csv', sc));

        xNo0   = choose_numeric_col(Tno0, {'dist_bin_center','dist_center_m','distance_m','dist_m'});
        p95No0 = choose_numeric_col(Tno0, {'delay_p95_ms','p95_ms','delay_p95','p95'});
        p99No0 = choose_numeric_col(Tno0, {'delay_p99_ms','p99_ms','delay_p99','p99'});

        xCo0   = choose_numeric_col(Tco0, {'dist_bin_center','dist_center_m','distance_m','dist_m'});
        p95Co0 = choose_numeric_col(Tco0, {'delay_p95_ms','p95_ms','delay_p95','p95'});
        p99Co0 = choose_numeric_col(Tco0, {'delay_p99_ms','p99_ms','delay_p99','p99'});

        mNo0 = isfinite(xNo0) & xNo0 >= 0 & xNo0 <= 200;
        mCo0 = isfinite(xCo0) & xCo0 >= 0 & xCo0 <= 200;

        [xNo0s, p95No0s] = sort_xy_masked(xNo0, p95No0, mNo0);
        [~,      p99No0s] = sort_xy_masked(xNo0, p99No0, mNo0);
        [xCo0s, p95Co0s] = sort_xy_masked(xCo0, p95Co0, mCo0);
        [~,      p99Co0s] = sort_xy_masked(xCo0, p99Co0, mCo0);

        plot(axL, xNo0s, p95No0s, '-', 'Color', cP95, 'LineWidth', lwMain);
        plot(axL, xCo0s, p95Co0s, ':', 'Color', cP95, 'LineWidth', lwAux);
        plot(axL, xNo0s, p99No0s, '-', 'Color', cP99, 'LineWidth', lwMain);
        plot(axL, xCo0s, p99Co0s, ':', 'Color', cP99, 'LineWidth', lwAux);

        yTopL = max([p95No0s(:); p99No0s(:); p95Co0s(:); p99Co0s(:)], [], 'omitnan');
        if isempty(yTopL) || ~isfinite(yTopL)
            yTopL = 8.5;
        end

        xlim(axL, [0 200]);
        ylim(axL, [0 max(8.5, 1.08*yTopL)]);
        xticks(axL, 0:50:200);
        title(axL, 'ret=0', 'FontSize', fsSub-1, 'FontWeight','normal');
        xlabel(axL, 'Distance (m)', 'FontSize', fsLab);
        ylabel(axL, 'delay (ms)', 'FontSize', fsLab);
        set(axL, 'FontSize', fsAx);
    end

    h21 = plot(axBot2(1), nan, nan, '-', 'Color', cP95, 'LineWidth', lwMain);
    h22 = plot(axBot2(1), nan, nan, '-', 'Color', cP99, 'LineWidth', lwMain);
    h23 = plot(axBot2(1), nan, nan, '-', 'Color', [0.20 0.20 0.20], 'LineWidth', lwMain);
    h24 = plot(axBot2(1), nan, nan, ':', 'Color', [0.20 0.20 0.20], 'LineWidth', lwAux);
    lg2 = legend(axBot2(1), [h21 h22 h23 h24], ...
        {'blue=p95','orange=p99','solid=NoCong','dotted=Cong'}, ...
        'Orientation','horizontal', 'Box','off', 'FontSize', fsAnno);
    lg2.Layout.Tile = 'south';

    save_fig(f2, outDir, 'Fig02_tail_delay_p95_p99_compact');

    %% ======================================================
    %% Fig3: Delivery-state decomposition under congestion
    %% ======================================================
    f3 = figure('Color','w','Position',[60 60 1760 580]);
    tl3 = tiledlayout(1,3,'TileSpacing','compact','Padding','loose');
    title(tl3, 'Delivery-state decomposition under congestion', ...
        'FontSize', fsTop, 'FontWeight', 'normal');

    legHandles3 = [];
    axTop2 = gobjects(numel(scenarios),1);
    axBot2 = gobjects(numel(scenarios),1);

    for iS = 1:numel(scenarios)
        sc = scenarios{iS};
        ax = nexttile(tl3);
        hold(ax,'on'); grid(ax,'on'); box(ax,'on');

        M = zeros(3,3); % [timely, late_received, phy_fail]
        for r = 0:2
            Ts = read_csv_safe(runsDir, ridCo, sprintf('tce_summary__%s__ret%d__pre_crash__seed1-10.csv', sc, r));

            timely = scalar_col(Ts, {'timely_success_rate','pdr','pdr_timely'});
            phy    = scalar_col(Ts, {'phy_success_rate'});
            lateR  = max(0, phy - timely);
            failR  = max(0, 1 - phy);

            M(r+1,:) = [timely, lateR, failR];
        end

        bh = bar(ax, 0:2, M, 'stacked', 'BarWidth', 0.68);
        bh(1).FaceColor = cTimely;
        bh(2).FaceColor = [0.92 0.58 0.10];
        bh(3).FaceColor = [0.75 0.75 0.75];
        bh(1).EdgeColor = [0.35 0.35 0.35];
        bh(2).EdgeColor = [0.35 0.35 0.35];
        bh(3).EdgeColor = [0.35 0.35 0.35];
        if isempty(legHandles3)
            legHandles3 = bh;
        end

        title(ax, sprintf('%s | Cong', sc), 'FontSize', fsSub, 'FontWeight', 'normal');
        ylabel(ax, 'Share of total packets', 'FontSize', fsLab);
        xlim(ax, [-0.8 2.8]);
        ylim(ax, [0 1]);
        xticks(ax, 0:2);
        xticklabels(ax, {'ret=0','ret=1','ret=2'});
        set(ax, 'FontSize', fsAx);

        for k = 1:3
            t1 = M(k,1);
            t2 = M(k,2);

            if t1 > 0.035
                text(ax, k-1, t1/2, sprintf('%.1f%%', 100*t1), ...
                    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
                    'FontSize', fsAnno);
            end
            if t2 > 0.025
                text(ax, k-1, t1 + t2/2, sprintf('%.1f%%', 100*t2), ...
                    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
                    'FontSize', fsAnno);
            end
        end

    end

    lg3 = legend(legHandles3, {'green=Timely success','orange=Late but received','gray=PHY fail'}, ...
        'Orientation','horizontal', 'Box','off');
    lg3.Layout.Tile = 'south';
    save_fig(f3, outDir, 'Fig03_delivery_state_decomposition');

    %% ======================================================
    %% Fig4: Congestion proxy evidence (Cong only, ret=0 baseline)
    %% ======================================================
    f4 = figure('Color','w','Position',[60 60 1760 590]);
    tl4 = tiledlayout(1,3,'TileSpacing','compact','Padding','compact');
    title(tl4, 'Congestion proxy evidence (Cong only, ret=0 baseline)', ...
        'FontSize', fsTop, 'FontWeight', 'normal');

    metricSpecs = {
        'avg_cbr',            'Avg CBR | Cong',                   'Avg CBR';
        'avg_p_col',          'Avg p_col | Cong',                 'Avg p_col';
        'avg_cong_delay_ms',  'Avg congestion delay (ms) | Cong', 'Avg congestion delay (ms)'
    };

    axList4 = gobjects(3,1);

    for iM = 1:3
        key  = metricSpecs{iM,1};
        tit  = metricSpecs{iM,2};
        ylab = metricSpecs{iM,3};

        ax = nexttile(tl4);
        axList4(iM) = ax;
        hold(ax,'on'); grid(ax,'on'); box(ax,'on');

        YY = [];
        XX = [];

        for iS = 1:numel(scenarios)
            sc = scenarios{iS};
            T = read_csv_safe(runsDir, ridCo, sprintf('summary_metrics__%s__ret0__seed1-10.csv', sc));

            x = choose_numeric_col(T, {'dist_bin_center','dist_m','distance_m'});
            y = choose_numeric_col(T, {key});

            x = x(:);
            y = y(:);
            good = isfinite(x) & isfinite(y);
            x = x(good);
            y = y(good);

            if isempty(XX)
                XX = x;
                YY = nan(numel(x), numel(scenarios));
            end

            if numel(x) ~= numel(XX) || any(abs(x(:) - XX(:)) > 1e-9)
                yInterp = interp1(x, y, XX, 'linear', 'extrap');
            else
                yInterp = y;
            end

            YY(:,iS) = yInterp;
        end

        mu = row_nanmean(YY);
        plot(ax, XX, mu, '-', 'Color', cMean, 'LineWidth', 1.9);

        title(ax, tit, 'FontSize', fsSub, 'FontWeight', 'normal', 'Interpreter', 'none');
        xlabel(ax, 'Distance (m)', 'FontSize', fsLab);
        ylabel(ax, ylab, 'FontSize', fsLab, 'Interpreter', 'none');
        xlim(ax, [min(XX) max(XX)]);
        ylim(ax, padded_limits(mu(:), 0.10));
        set(ax, 'FontSize', fsAx);
    end

    h41 = plot(axList4(1), nan, nan, '-', 'Color', cMean, 'LineWidth', 1.9);
    lg4 = legend(axList4(1), h41, 'dark blue=mean over Ref/UrbMask/Tunnel', ...
        'Orientation','horizontal', 'Box','off', 'FontSize', fsAnno);
    lg4.Layout.Tile = 'south';

    save_fig(f4, outDir, 'Fig04_congestion_proxy_evidence');

    %% ======================================================
    %% Fig5: UrbMask spatial heterogeneity (ONLY upper panel)
    %% ======================================================
    f5 = figure('Color','w','Position',[60 60 1760 680]);
    tl5 = tiledlayout(f5,1,1,'TileSpacing','compact','Padding','compact');
    title(tl5, 'UrbMask spatial heterogeneity (band 80-100 m)', ...
        'FontSize', fsTop, 'FontWeight', 'normal');
    ax5 = nexttile(tl5);
    hold(ax5,'on'); grid(ax5,'on'); box(ax5,'on');

    T50 = read_csv_safe(runsDir, ridNo, 'position_heterogeneity__UrbMask__ret0__band80-100__seed1-10.csv');
    T52 = read_csv_safe(runsDir, ridNo, 'position_heterogeneity__UrbMask__ret2__band80-100__seed1-10.csv');

    x0 = choose_numeric_col(T50, {'mid_x_bin_center','mid_x_center','mid_x','x_bin_center'});
    x2 = choose_numeric_col(T52, {'mid_x_bin_center','mid_x_center','mid_x','x_bin_center'});

    y0 = choose_numeric_col_allow_missing(T50, ...
        {'timely_success_rate','pdr_band','phy_success_rate'}, nan(size(x0)));
    y2 = choose_numeric_col_allow_missing(T52, ...
        {'timely_success_rate','pdr_band','phy_success_rate'}, nan(size(x2)));

    n0 = choose_numeric_col_allow_missing(T50, {'n_total'}, inf(size(x0)));
    n2 = choose_numeric_col_allow_missing(T52, {'n_total'}, inf(size(x2)));

    minCountMain = 50;

    m0 = isfinite(x0) & isfinite(y0) & isfinite(n0) & x0 >= 0 & x0 <= 3000 & n0 >= minCountMain;
    m2 = isfinite(x2) & isfinite(y2) & isfinite(n2) & x2 >= 0 & x2 <= 3000 & n2 >= minCountMain;

    [x0, idx] = sort(x0(m0)); y0 = y0(m0); y0 = y0(idx);
    [x2, idx] = sort(x2(m2)); y2 = y2(m2); y2 = y2(idx);

    if numel(y0) >= 3
        y0p = movmean(y0, 3, 'omitnan');
    else
        y0p = y0;
    end

    if numel(y2) >= 3
        y2p = movmean(y2, 3, 'omitnan');
    else
        y2p = y2;
    end

    Tband = read_csv_safe(runsDir, ridNo, ...
        'tce_position_heterogeneity__UrbMask__ret0__pre_crash__band80-100__seed1-10.csv');

    xb = choose_numeric_col(Tband, {'mid_x_bin_center','mid_x_center','mid_x','x_bin_center'});
    bb = choose_numeric_col_allow_missing(Tband, ...
        {'avg_blockage_b','blockage_b','blockage_score'}, nan(size(xb)));
    nb = choose_numeric_col_allow_missing(Tband, {'n_total'}, inf(size(xb)));

    minCountBand = 50;
    mb = isfinite(xb) & isfinite(bb) & isfinite(nb) & xb >= 0 & xb <= 3000 & nb >= minCountBand;

    [xb, idx] = sort(xb(mb));
    bb = bb(mb); bb = bb(idx);

    bandIntervals = zeros(0,2);
    if ~isempty(bb)
        bbNorm = normalize01(bb);
        if numel(bbNorm) >= 3
            bbNorm = movmean(bbNorm, 3, 'omitnan');
        end
        highMask = bbNorm >= 0.58;
        highMask = close_small_false_gaps(highMask, 2);
        bandIntervals = mask_to_intervals_refined(xb, highMask);
    end

    yMaxData = max([y0p(:); y2p(:)], [], 'omitnan');
    if isempty(yMaxData) || ~isfinite(yMaxData)
        yMaxData = 0.7;
    end
    yTop = max(0.72, 1.08 * yMaxData);

    for k = 1:size(bandIntervals,1)
        xl = bandIntervals(k,1);
        xr = bandIntervals(k,2);
        patch(ax5, [xl xr xr xl], [0 0 yTop yTop], [0.75 0.75 0.75], ...
            'FaceAlpha', 0.20, 'EdgeColor','none', 'HandleVisibility','off');
    end

    hBand = patch(ax5, nan, nan, [0.75 0.75 0.75], ...
        'FaceAlpha', 0.20, 'EdgeColor', 'none');
    h50 = plot(ax5, x0, y0p, '-', 'Color', cRet0, 'LineWidth', 2.6);
    h52 = plot(ax5, x2, y2p, '-', 'Color', cRet2, 'LineWidth', 2.6);

    xlim(ax5, [0 3000]);
    ylim(ax5, [0 yTop]);
    xlabel(ax5, 'mid_x (m)', 'FontSize', fsLab);
    ylabel(ax5, 'PDR_band (NoCong)', 'FontSize', fsLab);
    set(ax5, 'FontSize', fsAx);

    lg5 = legend(ax5, [h50 h52 hBand], {'blue=ret0','yellow=ret2','gray band=high blockage'}, ...
        'Location','southoutside', 'Orientation','horizontal', ...
        'Box','off', 'FontSize', fsAnno);
    lg5.Layout.Tile = 'south';

    save_fig(f5, outDir, 'Fig05_urbmask_spatial_heterogeneity_clean');

    %% ======================================================
    %% Fig6: Tunnel inside versus outside comparison
    %% ======================================================
    f6 = figure('Color','w','Position',[60 60 1760 830]);
    tl6 = tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
    title(tl6, 'Tunnel inside versus outside comparison (pre-crash, band 80-100 m)', ...
        'FontSize', fsTop, 'FontWeight', 'normal');

    condNames = {'NoCong','Cong'};
    ridList   = {ridNo, ridCo};

    maxTimely = 0;

    for iC = 1:2
        for r = 0:2
            Tseg = read_csv_safe(runsDir, ridList{iC}, sprintf('tce_tunnel_segments__Tunnel__ret%d__pre_crash__band80-100__seed1-10.csv', r));
            [insideAgg, outsideAgg] = aggregate_tunnel_segment(Tseg);
            maxTimely = max(maxTimely, insideAgg.timely);
            maxTimely = max(maxTimely, outsideAgg.timely);
        end
    end
    yTop = max(0.22, ceil((maxTimely*1.22)*100)/100);

    axList6 = gobjects(6,1);

    for iC = 1:2
        for r = 0:2
            ax = nexttile(tl6, (iC-1)*3 + (r+1));
            axList6((iC-1)*3 + (r+1)) = ax;
            hold(ax,'on'); grid(ax,'on'); box(ax,'on');

            Tseg = read_csv_safe(runsDir, ridList{iC}, sprintf('tce_tunnel_segments__Tunnel__ret%d__pre_crash__band80-100__seed1-10.csv', r));
            [insideAgg, outsideAgg] = aggregate_tunnel_segment(Tseg);

            vals = [insideAgg.timely, outsideAgg.timely];
            bh = bar(ax, 1:2, vals, 0.58);
            bh.FaceColor = 'flat';
            bh.CData(1,:) = [0.24 0.54 0.82];
            bh.CData(2,:) = [0.85 0.47 0.20];
            bh.EdgeColor = [0.35 0.35 0.35];

            title(ax, sprintf('%s | ret=%d', condNames{iC}, r), ...
                'FontSize', fsSub, 'FontWeight', 'normal');

            ylabel(ax, 'Timely PDR in band', 'FontSize', fsLab);
            xticks(ax, [1 2]);
            xticklabels(ax, {'inside(0~1)','outside(<0 or >1)'});
            ylim(ax, [0 yTop]);
            xlim(ax, [0.3 2.7]);
            set(ax, 'FontSize', fsAx);

            txt1 = sprintf('PHY=%.3f\nLate=%.3f', insideAgg.phy, insideAgg.lateRatioPhy);
            txt2 = sprintf('PHY=%.3f\nLate=%.3f', outsideAgg.phy, outsideAgg.lateRatioPhy);
            text(ax, 1, vals(1) + 0.018*yTop, txt1, ...
                'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
                'FontSize', fsAnno);
            text(ax, 2, vals(2) + 0.018*yTop, txt2, ...
                'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
                'FontSize', fsAnno);

            text(ax, 1, 0.04*yTop, sprintf('n=%d', insideAgg.nTotal), ...
                'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
                'FontSize', fsAnno, 'Color',[0.25 0.25 0.25]);
            text(ax, 2, 0.04*yTop, sprintf('n=%d', outsideAgg.nTotal), ...
                'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
                'FontSize', fsAnno, 'Color',[0.25 0.25 0.25]);
        end
    end

    h61 = patch(axList6(1), nan, nan, [0.24 0.54 0.82], 'EdgeColor', [0.35 0.35 0.35]);
    h62 = patch(axList6(1), nan, nan, [0.85 0.47 0.20], 'EdgeColor', [0.35 0.35 0.35]);
    lg6 = legend(axList6(1), [h61 h62], {'blue=inside (0~1)','orange=outside (<0 or >1)'}, ...
        'Orientation','horizontal', 'Box','off', 'FontSize', fsAnno);
    lg6.Layout.Tile = 'south';

    save_fig(f6, outDir, 'Fig06_tunnel_inside_outside');

    %% ======================================================
    %% Fig7: UrbMask TCE decomposition under congestion
    %% ======================================================
    f7 = figure('Color','w','Position',[60 60 1760 680]);
    tl7 = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
    title(tl7, 'UrbMask TCE decomposition under congestion (pre-crash)', ...
        'FontSize', fsTop, 'FontWeight', 'normal');

    legHandles7 = gobjects(3,1);
    retShow = [0 2];

    for iR = 1:2
        rr = retShow(iR);

        ax = nexttile(tl7, iR);
        hold(ax,'on'); grid(ax,'on'); box(ax,'on');
        T = read_csv_safe(runsDir, ridCo, sprintf('tce_by_distance__UrbMask__ret%d__pre_crash__seed1-10.csv', rr));

        x      = choose_numeric_col(T, {'dist_bin_center','dist_m','distance_m'});
        phy    = choose_numeric_col(T, {'phy_success_rate'});
        tce    = choose_numeric_col(T, {'tce'});
        timely = choose_numeric_col(T, {'timely_success_rate','pdr','pdr_timely'});

        h1 = plot(ax, x, phy,    '-', 'Color', cRet0,   'LineWidth', 2.6);
        h2 = plot(ax, x, tce,    '-', 'Color', cRet1,   'LineWidth', 2.6);
        h3 = plot(ax, x, timely, '-', 'Color', cTimely, 'LineWidth', 2.6);

        if iR == 1
            legHandles7 = [h1; h2; h3];
        end

        xline(ax, 1000, ':', 'Color', [0.65 0.65 0.65], 'LineWidth', 1.0);
        xline(ax, 2000, ':', 'Color', [0.65 0.65 0.65], 'LineWidth', 1.0);

        title(ax, sprintf('ret=%d', rr), 'FontSize', fsSub, 'FontWeight', 'normal');
        xlabel(ax, 'Distance (m)', 'FontSize', fsLab);
        ylabel(ax, 'Rate / utility', 'FontSize', fsLab);
        xlim(ax, [0 3000]);
        ylim(ax, [0 0.62]);
        set(ax, 'FontSize', fsAx);
    end

    lg7 = legend(legHandles7, {'blue=PHY success','orange=TCE','green=Timely success'}, ...
        'Orientation','horizontal', 'Box','off');
    lg7.Layout.Tile = 'south';
    save_fig(f7, outDir, 'Fig07_urbmask_tce_decomposition');

    fprintf('\n[OK] All figures exported to:\n%s\n\n', outDir);
end

%% ========================================================================
%% Helper functions
%% ========================================================================

function ensure_dir(d)
    if ~exist(d, 'dir')
        mkdir(d);
    end
end

function T = read_csv_safe(runsDir, runId, fileName)
    fp = fullfile(runsDir, runId, 'tables', fileName);
    if ~exist(fp, 'file')
        error('CSV not found:\n%s', fp);
    end
    T = readtable(fp, 'VariableNamingRule', 'preserve');
end

function tf = has_col(T, colName)
    tf = ismember(colName, T.Properties.VariableNames);
end

function x = choose_numeric_col(T, candidates)
    for i = 1:numel(candidates)
        c = candidates{i};
        if has_col(T, c)
            x = to_numeric_column(T.(c));
            x = x(:);
            return;
        end
    end
    error('Column not found. Candidates tried:\n%s', strjoin(candidates, ', '));
end

function v = choose_numeric_col_allow_missing(T, candidates, defaultValue)
    for i = 1:numel(candidates)
        c = candidates{i};
        if has_col(T, c)
            v = to_numeric_column(T.(c));
            v = v(:);
            return;
        end
    end
    v = defaultValue(:);
end

function v = scalar_col(T, candidates)
    x = choose_numeric_col(T, candidates);
    v = x(1);
end

function x = to_numeric_column(raw)
    if isnumeric(raw)
        x = double(raw);
    elseif islogical(raw)
        x = double(raw);
    elseif iscell(raw)
        x = nan(numel(raw),1);
        for k = 1:numel(raw)
            if isnumeric(raw{k})
                x(k) = double(raw{k});
            elseif isstring(raw{k}) || ischar(raw{k})
                x(k) = str2double(string(raw{k}));
            else
                x(k) = NaN;
            end
        end
    elseif isstring(raw)
        x = str2double(raw);
    elseif ischar(raw)
        x = str2double(cellstr(raw));
    elseif iscategorical(raw)
        x = str2double(string(raw));
    else
        error('Unsupported column type.');
    end
    x = double(x);
end

function lims = padded_limits(x, frac)
    x = x(isfinite(x));
    if isempty(x)
        lims = [0 1];
        return;
    end
    xmin = min(x);
    xmax = max(x);
    if abs(xmax - xmin) < 1e-12
        pad = max(0.1, 0.1*max(1,abs(xmax)));
    else
        pad = frac * (xmax - xmin);
    end
    lims = [xmin - pad, xmax + pad];
end

function y = normalize01(x)
    x = x(:);
    finiteMask = isfinite(x);
    if ~any(finiteMask)
        y = zeros(size(x));
        return;
    end
    m = min(x(finiteMask));
    M = max(x(finiteMask));
    if ~isfinite(m) || ~isfinite(M) || abs(M-m) < 1e-12
        y = zeros(size(x));
    else
        y = (x - m) / (M - m);
    end
end

function mask2 = close_small_false_gaps(mask, maxGapLen)
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

            leftTrue  = (i > 1) && mask2(i-1);
            rightTrue = (j <= n) && mask2(j);
            gapLen = j - i;

            if leftTrue && rightTrue && gapLen <= maxGapLen
                mask2(i:j-1) = true;
            end
            i = j;
        else
            i = i + 1;
        end
    end
end

function intervals = mask_to_intervals_refined(x, mask)
    x = x(:);
    mask = logical(mask(:));

    if isempty(x) || isempty(mask) || numel(x) ~= numel(mask)
        intervals = zeros(0,2);
        return;
    end

    if numel(x) >= 2
        dx = median(diff(x), 'omitnan');
    else
        dx = 10;
    end
    if ~isfinite(dx) || dx <= 0
        dx = 10;
    end

    d = diff([false; mask; false]);
    starts = find(d == 1);
    ends   = find(d == -1) - 1;

    intervals = zeros(numel(starts), 2);
    for k = 1:numel(starts)
        xl = x(starts(k)) - dx/2;
        xr = x(ends(k)) + dx/2;
        intervals(k,:) = [xl, xr];
    end
end

function mu = row_nanmean(M)
    mu = nan(size(M,1),1);
    for i = 1:size(M,1)
        row = M(i,:);
        row = row(isfinite(row));
        if isempty(row)
            mu(i) = NaN;
        else
            mu(i) = mean(row);
        end
    end
end

function [xs, ys] = sort_xy_masked(x, y, mask)
    x = x(:);
    y = y(:);
    mask = logical(mask(:));
    good = mask & isfinite(x) & isfinite(y);
    xs = x(good);
    ys = y(good);
    [xs, idx] = sort(xs);
    ys = ys(idx);
end

function save_fig(figHandle, outDir, baseName)
    pngFile = fullfile(outDir, [baseName '.png']);
    pdfFile = fullfile(outDir, [baseName '.pdf']);

    try
        exportgraphics(figHandle, pngFile, 'Resolution', 300);
        exportgraphics(figHandle, pdfFile, 'ContentType', 'vector');
    catch
        print(figHandle, pngFile, '-dpng', '-r300');
        print(figHandle, pdfFile, '-dpdf', '-painters');
    end
end

function [insideAgg, outsideAgg] = aggregate_tunnel_segment(T)
    u  = choose_numeric_col(T, {'u_bin_center','u_center','u'});
    nt = choose_numeric_col(T, {'n_total'});
    tp = choose_numeric_col(T, {'timely_success_rate','pdr','pdr_timely'});
    ph = choose_numeric_col(T, {'phy_success_rate'});

    if has_col(T, 'late_ratio_phy')
        lp = choose_numeric_col(T, {'late_ratio_phy'});
    else
        lateShare = max(0, ph - tp);
        denom = max(ph, 1e-12);
        lp = lateShare ./ denom;
    end

    inMask  = isfinite(u) & (u >= 0) & (u <= 1);
    outMask = isfinite(u) & ~inMask;

    insideAgg  = weighted_group_stats(nt(inMask),  tp(inMask),  ph(inMask),  lp(inMask));
    outsideAgg = weighted_group_stats(nt(outMask), tp(outMask), ph(outMask), lp(outMask));
end

function S = weighted_group_stats(w, timely, phy, lateRatioPhy)
    w = w(:);
    timely = timely(:);
    phy = phy(:);
    lateRatioPhy = lateRatioPhy(:);

    good = isfinite(w) & isfinite(timely) & isfinite(phy) & isfinite(lateRatioPhy) & (w > 0);
    w = w(good);
    timely = timely(good);
    phy = phy(good);
    lateRatioPhy = lateRatioPhy(good);

    if isempty(w)
        S.timely = NaN;
        S.phy = NaN;
        S.lateRatioPhy = NaN;
        S.nTotal = 0;
        return;
    end

    S.timely = sum(w .* timely) / sum(w);
    S.phy    = sum(w .* phy)    / sum(w);

    lateShare = max(0, phy - timely);
    if sum(w .* phy) > 1e-12
        S.lateRatioPhy = sum(w .* lateShare) / sum(w .* phy);
    else
        S.lateRatioPhy = 0;
    end

    S.nTotal = round(sum(w));
end
