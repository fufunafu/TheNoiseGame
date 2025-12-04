function batch_results = batch_process_sessions(file_list, options)
% BATCH_PROCESS_SESSIONS Process multiple Noise Game sessions
%
% Inputs:
%   file_list - Cell array of file paths OR directory path
%   options - Optional structure with analysis options
%
% Output:
%   batch_results - Structure with:
%     .sessions - Array of individual session results
%     .aggregated - Aggregated statistics across sessions
%     .comparisons - Between-session comparisons

    fprintf('=== BATCH PROCESSING SESSIONS ===\n\n');
    
    % Handle directory input
    if ischar(file_list) && isfolder(file_list)
        dir_path = file_list;
        files = dir(fullfile(dir_path, '*.csv'));
        file_list = {};
        for i = 1:length(files)
            file_list{i} = fullfile(dir_path, files(i).name);
        end
        fprintf('Found %d CSV files in directory: %s\n\n', length(file_list), dir_path);
    end
    
    % Validate input
    if isempty(file_list)
        error('No files provided for batch processing');
    end
    
    if ~iscell(file_list)
        file_list = {file_list};
    end
    
    n_sessions = length(file_list);
    fprintf('Processing %d session(s)...\n\n', n_sessions);
    
    % Set default options
    if nargin < 2
        options = struct();
    end
    if ~isfield(options, 'save_figures')
        options.save_figures = true;
    end
    if ~isfield(options, 'output_dir')
        options.output_dir = './batch_results';
    end
    if ~isfield(options, 'reconstruct_all_frames')
        options.reconstruct_all_frames = false;
    end
    
    % Create output directory
    if ~exist(options.output_dir, 'dir')
        mkdir(options.output_dir);
    end
    
    % Process each session
    sessions = struct();
    for i = 1:n_sessions
        fprintf('--- Processing Session %d/%d ---\n', i, n_sessions);
        fprintf('File: %s\n', file_list{i});
        
        try
            % Create session-specific output directory
            [~, filename, ~] = fileparts(file_list{i});
            session_output_dir = fullfile(options.output_dir, filename);
            
            session_options = options;
            session_options.output_dir = session_output_dir;
            
            % Run analysis on this session
            results = analyze_noise_game(file_list{i}, session_options);
            
            sessions(i).filename = filename;
            sessions(i).filepath = file_list{i};
            sessions(i).results = results;
            sessions(i).success = true;
            sessions(i).error = '';
            
            fprintf('Session %d processed successfully!\n\n', i);
            
        catch ME
            warning('Failed to process session %d: %s', i, ME.message);
            sessions(i).filename = filename;
            sessions(i).filepath = file_list{i};
            sessions(i).results = [];
            sessions(i).success = false;
            sessions(i).error = ME.message;
        end
    end
    
    % Count successful sessions
    n_successful = sum([sessions.success]);
    fprintf('\n=== BATCH PROCESSING SUMMARY ===\n');
    fprintf('Total sessions: %d\n', n_sessions);
    fprintf('Successful: %d\n', n_successful);
    fprintf('Failed: %d\n', n_sessions - n_successful);
    fprintf('\n');
    
    if n_successful == 0
        warning('No sessions processed successfully');
        batch_results = struct();
        batch_results.sessions = sessions;
        return;
    end
    
    %% Aggregate Statistics Across Sessions
    fprintf('Aggregating statistics across sessions...\n');
    
    aggregated = struct();
    
    % Extract successful sessions
    successful_sessions = sessions([sessions.success]);
    
    % Aggregate overall performance
    all_hit_rates = zeros(n_successful, 1);
    all_fa_rates = zeros(n_successful, 1);
    all_accuracies = zeros(n_successful, 1);
    all_dprimes = zeros(n_successful, 1);
    all_mean_rts = zeros(n_successful, 1);
    all_n_trials = zeros(n_successful, 1);
    
    for i = 1:n_successful
        all_hit_rates(i) = successful_sessions(i).results.metrics.overall.hit_rate;
        all_fa_rates(i) = successful_sessions(i).results.metrics.overall.false_alarm_rate;
        all_accuracies(i) = successful_sessions(i).results.metrics.overall.accuracy;
        all_dprimes(i) = successful_sessions(i).results.metrics.overall.sdt.dprime;
        all_n_trials(i) = successful_sessions(i).results.session_data.summary.num_trials;
        
        if ~isfield(successful_sessions(i).results.rt_results, 'no_data')
            all_mean_rts(i) = successful_sessions(i).results.rt_results.overall.mean;
        else
            all_mean_rts(i) = NaN;
        end
    end
    
    aggregated.overall = struct();
    aggregated.overall.mean_hit_rate = mean(all_hit_rates);
    aggregated.overall.std_hit_rate = std(all_hit_rates);
    aggregated.overall.mean_fa_rate = mean(all_fa_rates);
    aggregated.overall.std_fa_rate = std(all_fa_rates);
    aggregated.overall.mean_accuracy = mean(all_accuracies);
    aggregated.overall.std_accuracy = std(all_accuracies);
    aggregated.overall.mean_dprime = mean(all_dprimes);
    aggregated.overall.std_dprime = std(all_dprimes);
    aggregated.overall.mean_rt = nanmean(all_mean_rts);
    aggregated.overall.std_rt = nanstd(all_mean_rts);
    aggregated.overall.total_trials = sum(all_n_trials);
    
    % Aggregate by contrast
    % Get all unique contrasts across sessions
    all_contrasts = [];
    for i = 1:n_successful
        contrasts = [successful_sessions(i).results.metrics.by_contrast.contrast];
        all_contrasts = [all_contrasts, contrasts]; %#ok<AGROW>
    end
    unique_contrasts = unique(all_contrasts);
    
    aggregated.by_contrast = struct();
    for c = 1:length(unique_contrasts)
        contrast = unique_contrasts(c);
        
        contrast_hit_rates = [];
        contrast_accuracies = [];
        contrast_dprimes = [];
        
        for i = 1:n_successful
            session_contrasts = [successful_sessions(i).results.metrics.by_contrast.contrast];
            idx = find(session_contrasts == contrast, 1);
            
            if ~isempty(idx)
                contrast_hit_rates(end+1) = successful_sessions(i).results.metrics.by_contrast(idx).hit_rate; %#ok<AGROW>
                contrast_accuracies(end+1) = successful_sessions(i).results.metrics.by_contrast(idx).accuracy; %#ok<AGROW>
                contrast_dprimes(end+1) = successful_sessions(i).results.metrics.by_contrast(idx).sdt.dprime; %#ok<AGROW>
            end
        end
        
        aggregated.by_contrast(c).contrast = contrast;
        aggregated.by_contrast(c).n_sessions = length(contrast_hit_rates);
        aggregated.by_contrast(c).mean_hit_rate = mean(contrast_hit_rates);
        aggregated.by_contrast(c).std_hit_rate = std(contrast_hit_rates);
        aggregated.by_contrast(c).sem_hit_rate = std(contrast_hit_rates) / sqrt(length(contrast_hit_rates));
        aggregated.by_contrast(c).mean_accuracy = mean(contrast_accuracies);
        aggregated.by_contrast(c).std_accuracy = std(contrast_accuracies);
        aggregated.by_contrast(c).mean_dprime = mean(contrast_dprimes);
        aggregated.by_contrast(c).std_dprime = std(contrast_dprimes);
    end
    
    %% Create Aggregated Visualizations
    fprintf('Creating aggregated visualizations...\n');
    
    % Figure: Performance across sessions
    fig_aggregate = figure('Position', [100, 100, 1400, 800], 'Color', 'w');
    
    % Overall performance comparison
    subplot(2, 3, 1);
    bar(1:n_successful, all_accuracies * 100, 'FaceColor', [0.4, 0.6, 0.8]);
    xlabel('Session', 'FontSize', 12);
    ylabel('Accuracy (%)', 'FontSize', 12);
    title('Accuracy Across Sessions', 'FontSize', 14, 'FontWeight', 'bold');
    yline(aggregated.overall.mean_accuracy * 100, '--r', 'LineWidth', 2);
    ylim([0, 100]);
    grid on;
    
    % d-prime across sessions
    subplot(2, 3, 2);
    bar(1:n_successful, all_dprimes, 'FaceColor', [0.7, 0.4, 0.4]);
    xlabel('Session', 'FontSize', 12);
    ylabel('d''', 'FontSize', 12);
    title('Sensitivity Across Sessions', 'FontSize', 14, 'FontWeight', 'bold');
    yline(aggregated.overall.mean_dprime, '--r', 'LineWidth', 2);
    grid on;
    
    % RT across sessions
    subplot(2, 3, 3);
    valid_rt_idx = ~isnan(all_mean_rts);
    if sum(valid_rt_idx) > 0
        bar(find(valid_rt_idx), all_mean_rts(valid_rt_idx), 'FaceColor', [0.5, 0.7, 0.5]);
        xlabel('Session', 'FontSize', 12);
        ylabel('Mean RT (s)', 'FontSize', 12);
        title('Reaction Time Across Sessions', 'FontSize', 14, 'FontWeight', 'bold');
        yline(aggregated.overall.mean_rt, '--r', 'LineWidth', 2);
        grid on;
    end
    
    % Aggregated psychometric curve
    subplot(2, 3, [4, 5, 6]);
    contrast_levels = [aggregated.by_contrast.contrast];
    mean_hit_rates = [aggregated.by_contrast.mean_hit_rate];
    sem_hit_rates = [aggregated.by_contrast.sem_hit_rate];
    
    hold on;
    errorbar(contrast_levels, mean_hit_rates * 100, sem_hit_rates * 100, ...
             'o-', 'LineWidth', 3, 'MarkerSize', 12, 'Color', [0.2, 0.4, 0.7], ...
             'MarkerFaceColor', [0.2, 0.4, 0.7]);
    
    % Plot individual session curves (lighter)
    for i = 1:n_successful
        session_contrasts = [successful_sessions(i).results.metrics.by_contrast.contrast];
        session_hit_rates = [successful_sessions(i).results.metrics.by_contrast.hit_rate];
        plot(session_contrasts, session_hit_rates * 100, 'o-', 'Color', [0.7, 0.7, 0.7, 0.3], 'LineWidth', 1);
    end
    
    xlabel('Contrast Level', 'FontSize', 14);
    ylabel('Hit Rate (%)', 'FontSize', 14);
    title('Aggregated Psychometric Function', 'FontSize', 16, 'FontWeight', 'bold');
    legend('Mean ± SEM', 'Individual Sessions', 'Location', 'southeast');
    ylim([0, 100]);
    grid on;
    
    sgtitle(sprintf('Batch Analysis: %d Sessions', n_successful), 'FontSize', 18, 'FontWeight', 'bold');
    
    % Save aggregated figure
    if options.save_figures
        addpath(fullfile(fileparts(mfilename('fullpath')), 'utils'));
        export_figures(fig_aggregate, fullfile(options.output_dir, 'aggregated_analysis'), {'png', 'pdf'});
    end
    
    %% Generate Batch Summary Report
    fprintf('Generating batch summary report...\n');
    
    report_file = fullfile(options.output_dir, 'batch_summary.txt');
    fid = fopen(report_file, 'w');
    
    fprintf(fid, '================================================================================\n');
    fprintf(fid, 'BATCH ANALYSIS SUMMARY\n');
    fprintf(fid, '================================================================================\n\n');
    
    fprintf(fid, 'Analysis Date: %s\n', datestr(now));
    fprintf(fid, 'Total Sessions Processed: %d\n', n_sessions);
    fprintf(fid, 'Successful: %d\n', n_successful);
    fprintf(fid, 'Failed: %d\n\n', n_sessions - n_successful);
    
    fprintf(fid, 'AGGREGATED PERFORMANCE\n');
    fprintf(fid, '----------------------\n');
    fprintf(fid, 'Mean Hit Rate: %.2f%% (SD = %.2f%%)\n', ...
            aggregated.overall.mean_hit_rate * 100, aggregated.overall.std_hit_rate * 100);
    fprintf(fid, 'Mean Accuracy: %.2f%% (SD = %.2f%%)\n', ...
            aggregated.overall.mean_accuracy * 100, aggregated.overall.std_accuracy * 100);
    fprintf(fid, 'Mean d'': %.3f (SD = %.3f)\n', ...
            aggregated.overall.mean_dprime, aggregated.overall.std_dprime);
    if ~isnan(aggregated.overall.mean_rt)
        fprintf(fid, 'Mean RT: %.3f s (SD = %.3f s)\n', ...
                aggregated.overall.mean_rt, aggregated.overall.std_rt);
    end
    fprintf(fid, 'Total Trials: %d\n\n', aggregated.overall.total_trials);
    
    fprintf(fid, 'PERFORMANCE BY CONTRAST (AGGREGATED)\n');
    fprintf(fid, '------------------------------------\n');
    fprintf(fid, 'Contrast  N Sessions  Mean Hit Rate  Mean Accuracy  Mean d''\n');
    fprintf(fid, '--------  ---------  -------------  -------------  -------\n');
    for i = 1:length(aggregated.by_contrast)
        fprintf(fid, '%6.2f    %9d  %11.1f%%  %11.1f%%  %7.2f\n', ...
                aggregated.by_contrast(i).contrast, ...
                aggregated.by_contrast(i).n_sessions, ...
                aggregated.by_contrast(i).mean_hit_rate * 100, ...
                aggregated.by_contrast(i).mean_accuracy * 100, ...
                aggregated.by_contrast(i).mean_dprime);
    end
    fprintf(fid, '\n');
    
    fprintf(fid, 'INDIVIDUAL SESSION SUMMARIES\n');
    fprintf(fid, '----------------------------\n');
    for i = 1:n_sessions
        fprintf(fid, '\nSession %d: %s\n', i, sessions(i).filename);
        if sessions(i).success
            r = sessions(i).results;
            fprintf(fid, '  Status: SUCCESS\n');
            fprintf(fid, '  Trials: %d\n', r.session_data.summary.num_trials);
            fprintf(fid, '  Accuracy: %.1f%%\n', r.metrics.overall.accuracy * 100);
            fprintf(fid, '  d'': %.2f\n', r.metrics.overall.sdt.dprime);
        else
            fprintf(fid, '  Status: FAILED\n');
            fprintf(fid, '  Error: %s\n', sessions(i).error);
        end
    end
    
    fprintf(fid, '\n================================================================================\n');
    
    fclose(fid);
    fprintf('  Saved batch report: %s\n', report_file);
    
    %% Compile results
    batch_results = struct();
    batch_results.sessions = sessions;
    batch_results.aggregated = aggregated;
    batch_results.n_total = n_sessions;
    batch_results.n_successful = n_successful;
    batch_results.output_dir = options.output_dir;
    
    % Save batch results
    save(fullfile(options.output_dir, 'batch_results.mat'), 'batch_results', '-v7.3');
    
    fprintf('\n=== BATCH PROCESSING COMPLETE ===\n');
    fprintf('Results saved to: %s\n', options.output_dir);
end

