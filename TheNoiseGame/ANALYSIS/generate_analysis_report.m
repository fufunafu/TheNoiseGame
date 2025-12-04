function generate_analysis_report(session_data, metrics, psychometric_results, rt_results, results, options)
% GENERATE_ANALYSIS_REPORT Generate comprehensive analysis report
%
% Inputs:
%   session_data - Session data structure
%   metrics - Performance metrics structure
%   psychometric_results - Psychometric analysis results
%   rt_results - Reaction time analysis results
%   results - Complete results structure from analysis
%   options - Options structure with:
%       .output_dir - Output directory (default: './analysis_results')
%       .session_name - Name for this session (default: from metadata)

    if nargin < 6
        options = struct();
    end
    
    if ~isfield(options, 'output_dir')
        options.output_dir = './analysis_results';
    end
    
    if ~isfield(options, 'session_name')
        options.session_name = session_data.metadata.session_info.sessionId;
    end
    
    % Create output directory
    if ~exist(options.output_dir, 'dir')
        mkdir(options.output_dir);
    end
    
    fprintf('Generating analysis report...\n');
    
    %% Save complete results to MAT file
    output_mat = fullfile(options.output_dir, sprintf('%s_results.mat', options.session_name));
    save(output_mat, 'session_data', 'metrics', 'psychometric_results', 'rt_results', 'results', '-v7.3');
    fprintf('  Saved MAT file: %s\n', output_mat);
    
    %% Generate text report
    output_txt = fullfile(options.output_dir, sprintf('%s_report.txt', options.session_name));
    fid = fopen(output_txt, 'w');
    
    fprintf(fid, '================================================================================\n');
    fprintf(fid, 'THE NOISE GAME - ANALYSIS REPORT\n');
    fprintf(fid, '================================================================================\n\n');
    
    % Session Information
    fprintf(fid, 'SESSION INFORMATION\n');
    fprintf(fid, '-------------------\n');
    fprintf(fid, 'Session ID: %s\n', session_data.metadata.session_info.sessionId);
    fprintf(fid, 'Subject: %s\n', session_data.metadata.session_info.subjectName);
    if isfield(session_data.metadata.session_info, 'sessionStartTime')
        fprintf(fid, 'Date: %s\n', session_data.metadata.session_info.sessionStartTime);
    end
    fprintf(fid, 'Total Trials: %d\n', session_data.summary.num_trials);
    fprintf(fid, 'Total Frames: %d\n', session_data.summary.total_frames);
    fprintf(fid, '\n');
    
    % Experimental Parameters
    fprintf(fid, 'EXPERIMENTAL PARAMETERS\n');
    fprintf(fid, '-----------------------\n');
    fprintf(fid, 'Grid Size: %d x %d\n', session_data.metadata.grid_cols, session_data.metadata.grid_rows);
    fprintf(fid, 'Stimulus Rate: %d Hz\n', session_data.metadata.trial_settings.stimulusHz);
    fprintf(fid, 'Contrast Levels: %s\n', mat2str(session_data.metadata.contrast_levels));
    fprintf(fid, 'Cue Duration: %.2f s\n', session_data.metadata.trial_settings.cueDuration);
    fprintf(fid, 'Stimulus Duration: %.2f s\n', session_data.metadata.trial_settings.stimulusDuration);
    fprintf(fid, '\n');
    
    % Overall Performance
    fprintf(fid, 'OVERALL PERFORMANCE\n');
    fprintf(fid, '-------------------\n');
    fprintf(fid, 'Hits: %d\n', metrics.overall.n_hits);
    fprintf(fid, 'Misses: %d\n', metrics.overall.n_misses);
    fprintf(fid, 'False Alarms: %d\n', metrics.overall.n_false_alarms);
    fprintf(fid, 'Correct Rejects: %d\n', metrics.overall.n_correct_rejects);
    fprintf(fid, 'Hit Rate: %.2f%%\n', metrics.overall.hit_rate * 100);
    fprintf(fid, 'False Alarm Rate: %.2f%%\n', metrics.overall.false_alarm_rate * 100);
    fprintf(fid, 'Overall Accuracy: %.2f%%\n', metrics.overall.accuracy * 100);
    fprintf(fid, '\n');
    
    % Signal Detection Theory
    fprintf(fid, 'SIGNAL DETECTION THEORY METRICS\n');
    fprintf(fid, '-------------------------------\n');
    fprintf(fid, 'd'' (Sensitivity): %.3f\n', metrics.overall.sdt.dprime);
    fprintf(fid, 'Criterion (c): %.3f\n', metrics.overall.sdt.criterion);
    fprintf(fid, 'Beta: %.3f\n', metrics.overall.sdt.beta);
    fprintf(fid, '\n');
    
    % Performance by Contrast
    fprintf(fid, 'PERFORMANCE BY CONTRAST LEVEL\n');
    fprintf(fid, '-----------------------------\n');
    fprintf(fid, 'Contrast  Trials  Hit Rate  Accuracy  d''      Criterion\n');
    fprintf(fid, '--------  ------  --------  --------  ------  ---------\n');
    for i = 1:length(metrics.by_contrast)
        fprintf(fid, '%6.2f    %6d  %6.1f%%  %6.1f%%  %6.2f  %9.2f\n', ...
                metrics.by_contrast(i).contrast, ...
                metrics.by_contrast(i).n_trials, ...
                metrics.by_contrast(i).hit_rate * 100, ...
                metrics.by_contrast(i).accuracy * 100, ...
                metrics.by_contrast(i).sdt.dprime, ...
                metrics.by_contrast(i).sdt.criterion);
    end
    fprintf(fid, '\n');
    
    % Performance by Quadrant
    fprintf(fid, 'PERFORMANCE BY QUADRANT\n');
    fprintf(fid, '-----------------------\n');
    fprintf(fid, 'Quadrant         Trials  Hit Rate  Accuracy\n');
    fprintf(fid, '---------------  ------  --------  --------\n');
    for i = 1:length(metrics.by_quadrant)
        fprintf(fid, '%-15s  %6d  %6.1f%%  %6.1f%%\n', ...
                metrics.by_quadrant(i).quadrant, ...
                metrics.by_quadrant(i).n_trials, ...
                metrics.by_quadrant(i).hit_rate * 100, ...
                metrics.by_quadrant(i).accuracy * 100);
    end
    fprintf(fid, '\n');
    
    % Reaction Time Analysis
    if ~isfield(rt_results, 'no_data')
        fprintf(fid, 'REACTION TIME ANALYSIS\n');
        fprintf(fid, '----------------------\n');
        fprintf(fid, 'Valid RT Trials: %d\n', rt_results.overall.n);
        fprintf(fid, 'Mean RT: %.3f s (SD = %.3f s)\n', rt_results.overall.mean, rt_results.overall.std);
        fprintf(fid, 'Median RT: %.3f s\n', rt_results.overall.median);
        fprintf(fid, 'RT Range: [%.3f, %.3f] s\n', rt_results.overall.min, rt_results.overall.max);
        fprintf(fid, 'Outliers: %d (%.1f%%)\n', rt_results.overall.n_outliers, rt_results.overall.outlier_rate * 100);
        fprintf(fid, '\n');
        
        fprintf(fid, 'RT by Contrast:\n');
        fprintf(fid, 'Contrast  Mean RT   Median RT  SD\n');
        fprintf(fid, '--------  --------  ---------  ------\n');
        for i = 1:length(rt_results.by_contrast)
            fprintf(fid, '%6.2f    %6.3f s  %6.3f s   %.3f s\n', ...
                    rt_results.by_contrast(i).contrast, ...
                    rt_results.by_contrast(i).mean, ...
                    rt_results.by_contrast(i).median, ...
                    rt_results.by_contrast(i).std);
        end
        fprintf(fid, '\n');
        
        if ~isnan(rt_results.stats.anova_p)
            fprintf(fid, 'ANOVA (RT ~ Contrast): F-test p-value = %.4f\n', rt_results.stats.anova_p);
            if rt_results.stats.anova_p < 0.05
                fprintf(fid, '  *** Significant effect of contrast on RT (p < 0.05)\n');
            else
                fprintf(fid, '  No significant effect of contrast on RT (p >= 0.05)\n');
            end
            fprintf(fid, '\n');
        end
    end
    
    % Psychometric Analysis
    fprintf(fid, 'PSYCHOMETRIC ANALYSIS\n');
    fprintf(fid, '---------------------\n');
    if ~isfield(psychometric_results.curve_fit, 'insufficient_data')
        fprintf(fid, 'Psychometric Curve Fit (Sigmoid):\n');
        if isfield(psychometric_results.curve_fit.params, 'threshold')
            fprintf(fid, '  Threshold: %.3f\n', psychometric_results.curve_fit.params.threshold);
            fprintf(fid, '  Slope: %.3f\n', psychometric_results.curve_fit.params.slope);
            fprintf(fid, '  Lapse Rate: %.3f\n', psychometric_results.curve_fit.params.lapse_rate);
        end
        fprintf(fid, '  75%% Threshold: %.3f\n', psychometric_results.curve_fit.threshold_75);
        fprintf(fid, '  R-squared: %.3f\n', psychometric_results.curve_fit.gof.rsquared);
        fprintf(fid, '  RMSE: %.3f\n', psychometric_results.curve_fit.gof.rmse);
    else
        fprintf(fid, 'Insufficient data for psychometric curve fitting\n');
    end
    fprintf(fid, '\n');
    
    % Temporal Dynamics
    if ~isfield(metrics.temporal, 'insufficient_data')
        fprintf(fid, 'TEMPORAL DYNAMICS\n');
        fprintf(fid, '-----------------\n');
        fprintf(fid, 'Performance by Block:\n');
        fprintf(fid, 'Block  Trials       Accuracy\n');
        fprintf(fid, '-----  -----------  --------\n');
        for i = 1:length(metrics.temporal.blocks)
            fprintf(fid, '%5d  %4d - %4d  %6.1f%%\n', ...
                    metrics.temporal.blocks(i).block_num, ...
                    metrics.temporal.blocks(i).start_trial, ...
                    metrics.temporal.blocks(i).end_trial, ...
                    metrics.temporal.blocks(i).accuracy * 100);
        end
        fprintf(fid, '\n');
    end
    
    % Analysis timestamp
    fprintf(fid, '================================================================================\n');
    fprintf(fid, 'Analysis completed: %s\n', datestr(now));
    fprintf(fid, 'MATLAB version: %s\n', version);
    fprintf(fid, '================================================================================\n');
    
    fclose(fid);
    fprintf('  Saved text report: %s\n', output_txt);
    
    %% Export summary statistics to CSV
    output_csv = fullfile(options.output_dir, sprintf('%s_summary.csv', options.session_name));
    
    % Create table with summary statistics
    summary_table = table();
    summary_table.Metric = {
        'Total_Trials';
        'Hits';
        'Misses';
        'False_Alarms';
        'Correct_Rejects';
        'Hit_Rate';
        'False_Alarm_Rate';
        'Accuracy';
        'Dprime';
        'Criterion';
        'Beta';
    };
    
    summary_table.Value = [
        session_data.summary.num_trials;
        metrics.overall.n_hits;
        metrics.overall.n_misses;
        metrics.overall.n_false_alarms;
        metrics.overall.n_correct_rejects;
        metrics.overall.hit_rate;
        metrics.overall.false_alarm_rate;
        metrics.overall.accuracy;
        metrics.overall.sdt.dprime;
        metrics.overall.sdt.criterion;
        metrics.overall.sdt.beta;
    ];
    
    if ~isfield(rt_results, 'no_data')
        rt_metrics = {
            'Mean_RT';
            'Median_RT';
            'SD_RT';
        };
        rt_values = [
            rt_results.overall.mean;
            rt_results.overall.median;
            rt_results.overall.std;
        ];
        
        % Create new rows and append to table
        rt_table = table(rt_metrics, rt_values, 'VariableNames', {'Metric', 'Value'});
        summary_table = [summary_table; rt_table];
    end
    
    writetable(summary_table, output_csv);
    fprintf('  Saved summary CSV: %s\n', output_csv);
    
    %% Export detailed results by contrast
    output_contrast_csv = fullfile(options.output_dir, sprintf('%s_by_contrast.csv', options.session_name));
    
    contrast_table = struct2table(metrics.by_contrast);
    % Expand SDT structure fields
    if ~isempty(contrast_table)
        sdt_fields = fieldnames(metrics.by_contrast(1).sdt);
        for f = 1:length(sdt_fields)
            field = sdt_fields{f};
            contrast_table.(field) = arrayfun(@(x) x.sdt.(field), metrics.by_contrast)';
        end
        contrast_table.sdt = [];  % Remove nested structure
    end
    
    writetable(contrast_table, output_contrast_csv);
    fprintf('  Saved contrast analysis CSV: %s\n', output_contrast_csv);
    
    fprintf('\nReport generation complete!\n');
    fprintf('All results saved to: %s\n', options.output_dir);
end

