function figures = generate_visualizations(session_data, metrics, psychometric_results, rt_results, options)
% GENERATE_VISUALIZATIONS Create comprehensive visualization suite
%
% Inputs:
%   session_data - Session data structure
%   metrics - Performance metrics structure
%   psychometric_results - Psychometric analysis results
%   rt_results - Reaction time analysis results
%   options - Optional structure with:
%       .save_figures - Save figures to disk (default: false)
%       .output_dir - Directory for saved figures (default: './figures')
%       .formats - Cell array of formats {'png', 'pdf'} (default: {'png'})
%       .reconstruct_stimuli - Show stimulus reconstruction (default: true)
%
% Output:
%   figures - Structure with figure handles

    fprintf('Generating visualizations...\n');
    
    % Add utils path
    addpath(fullfile(fileparts(mfilename('fullpath')), 'utils'));
    
    % Parse options
    if nargin < 5
        options = struct();
    end
    if ~isfield(options, 'save_figures')
        options.save_figures = false;
    end
    if ~isfield(options, 'output_dir')
        options.output_dir = './figures';
    end
    if ~isfield(options, 'formats')
        options.formats = {'png'};
    end
    if ~isfield(options, 'reconstruct_stimuli')
        options.reconstruct_stimuli = true;
    end
    
    % Create output directory if saving
    if options.save_figures && ~exist(options.output_dir, 'dir')
        mkdir(options.output_dir);
    end
    
    figures = struct();
    
    %% Figure 1: Session Overview
    fprintf('  Creating Figure 1: Session Overview...\n');
    figures.fig1 = create_session_overview(session_data, metrics);
    if options.save_figures
        export_figures(figures.fig1, fullfile(options.output_dir, 'fig1_session_overview'), options.formats);
    end
    
    %% Figure 2: Psychometric Curves
    fprintf('  Creating Figure 2: Psychometric Curves...\n');
    figures.fig2 = create_psychometric_figure(psychometric_results);
    if options.save_figures
        export_figures(figures.fig2, fullfile(options.output_dir, 'fig2_psychometric'), options.formats);
    end
    
    %% Figure 3: Reaction Time Analysis
    fprintf('  Creating Figure 3: Reaction Time Analysis...\n');
    if ~isfield(rt_results, 'no_data')
        figures.fig3 = create_rt_figure(rt_results);
        if options.save_figures
            export_figures(figures.fig3, fullfile(options.output_dir, 'fig3_reaction_times'), options.formats);
        end
    else
        fprintf('  Skipping RT figure (no data)\n');
    end
    
    %% Figure 4: Stimulus Reconstruction Examples
    if options.reconstruct_stimuli
        fprintf('  Creating Figure 4: Stimulus Reconstruction...\n');
        figures.fig4 = create_stimulus_reconstruction_figure(session_data);
        if options.save_figures
            export_figures(figures.fig4, fullfile(options.output_dir, 'fig4_stimulus_reconstruction'), options.formats);
        end
    end
    
    %% Figure 5: Temporal Dynamics
    fprintf('  Creating Figure 5: Temporal Dynamics...\n');
    figures.fig5 = create_temporal_dynamics_figure(session_data, metrics);
    if options.save_figures
        export_figures(figures.fig5, fullfile(options.output_dir, 'fig5_temporal_dynamics'), options.formats);
    end
    
    %% Figure 6: Performance Heatmaps
    fprintf('  Creating Figure 6: Performance Heatmaps...\n');
    figures.fig6 = create_performance_heatmap(session_data, metrics);
    if options.save_figures
        export_figures(figures.fig6, fullfile(options.output_dir, 'fig6_performance_heatmap'), options.formats);
    end
    
    %% Figure 7: Speed-Accuracy Tradeoff
    if ~isfield(rt_results, 'no_data')
        fprintf('  Creating Figure 7: Speed-Accuracy Tradeoff...\n');
        figures.fig7 = create_speed_accuracy_figure(rt_results, metrics);
        if options.save_figures
            export_figures(figures.fig7, fullfile(options.output_dir, 'fig7_speed_accuracy'), options.formats);
        end
    end
    
    %% Figure 8: Signal Detection Theory Analysis
    fprintf('  Creating Figure 8: SDT Analysis...\n');
    figures.fig8 = create_sdt_figure(psychometric_results, metrics);
    if options.save_figures
        export_figures(figures.fig8, fullfile(options.output_dir, 'fig8_sdt_analysis'), options.formats);
    end
    
    fprintf('Visualization complete! Generated %d figures.\n', length(fieldnames(figures)));
end


%% Helper Functions for Each Figure Type

function fig = create_session_overview(session_data, metrics)
    fig = figure('Position', [100, 100, 1200, 800], 'Color', 'w', 'Renderer', 'painters');
    
    % Trial timeline
    subplot(2, 3, [1, 2]);
    trials = session_data.trials;
    trial_nums = [trials.trial_index];
    outcomes = {trials.outcome};
    
    % Color code by outcome
    hold on;
    for i = 1:length(trials)
        switch outcomes{i}
            case 'hit'
                color = [0, 0.7, 0];  % Green
                marker = 'o';
            case 'miss'
                color = [0.8, 0, 0];  % Red
                marker = 'x';
            case 'false_alarm'
                color = [0.8, 0.4, 0];  % Orange
                marker = 's';
            case 'correct_reject'
                color = [0, 0.5, 0.8];  % Blue
                marker = 'd';
            otherwise
                color = [0.5, 0.5, 0.5];  % Gray
                marker = '.';
        end
        plot(i, trials(i).contrast, marker, 'Color', color, 'MarkerSize', 8, 'LineWidth', 1.5);
    end
    xlabel('Trial Number', 'FontSize', 12);
    ylabel('Contrast Level', 'FontSize', 12);
    title('Trial Timeline', 'FontSize', 14, 'FontWeight', 'bold');
    legend({'Hit', 'Miss', 'FA', 'CR'}, 'Location', 'best');
    grid on;
    
    % Performance by contrast
    subplot(2, 3, 3);
    contrasts = [metrics.by_contrast.contrast];
    accuracies = [metrics.by_contrast.accuracy];
    bar(contrasts, accuracies * 100, 'FaceColor', [0.3, 0.5, 0.8]);
    xlabel('Contrast Level', 'FontSize', 12);
    ylabel('Accuracy (%)', 'FontSize', 12);
    title('Accuracy by Contrast', 'FontSize', 14, 'FontWeight', 'bold');
    ylim([0, 100]);
    grid on;
    
    % Outcome distribution
    subplot(2, 3, 4);
    outcome_counts = [metrics.overall.n_hits, metrics.overall.n_misses, ...
                     metrics.overall.n_false_alarms, metrics.overall.n_correct_rejects];
    outcome_labels = {'Hit', 'Miss', 'False Alarm', 'Correct Reject'};
    
    % Filter out zero values for better pie chart rendering
    nonzero_idx = outcome_counts > 0;
    if sum(nonzero_idx) > 0
        pie(outcome_counts(nonzero_idx), outcome_labels(nonzero_idx));
        colormap(subplot(2,3,4), [0, 0.7, 0; 0.8, 0, 0; 0.8, 0.4, 0; 0, 0.5, 0.8]);
    else
        text(0.5, 0.5, 'No data', 'HorizontalAlignment', 'center', 'FontSize', 12);
        axis off;
    end
    title('Outcome Distribution', 'FontSize', 14, 'FontWeight', 'bold');
    
    % Performance over time
    subplot(2, 3, [5, 6]);
    if ~isfield(metrics.temporal, 'insufficient_data')
        plot(metrics.temporal.trial_numbers, metrics.temporal.moving_avg * 100, ...
             'LineWidth', 2, 'Color', [0.2, 0.4, 0.7]);
        xlabel('Trial Number', 'FontSize', 12);
        ylabel('Accuracy (%) - Moving Average', 'FontSize', 12);
        title('Performance Over Time', 'FontSize', 14, 'FontWeight', 'bold');
        ylim([0, 100]);
        grid on;
    else
        text(0.5, 0.5, 'Insufficient data for temporal analysis', ...
             'HorizontalAlignment', 'center', 'FontSize', 12);
        axis off;
    end
    
    sgtitle(sprintf('Session Overview: %s', session_data.metadata.session_info.sessionId), ...
            'FontSize', 16, 'FontWeight', 'bold');
end


function fig = create_psychometric_figure(psychometric_results)
    fig = figure('Position', [100, 100, 1200, 800], 'Color', 'w');
    
    % Hit Rate vs Contrast
    subplot(2, 2, 1);
    hold on;
    errorbar(psychometric_results.contrast_levels, ...
             psychometric_results.hit_rates * 100, ...
             psychometric_results.hit_rate_se * 100, ...
             'o-', 'LineWidth', 2, 'MarkerSize', 8, 'Color', [0.2, 0.4, 0.7]);
    
    % Add fitted curve if available
    if ~isfield(psychometric_results.curve_fit, 'insufficient_data')
        plot(psychometric_results.curve_fit.x, ...
             psychometric_results.curve_fit.y * 100, ...
             '--', 'LineWidth', 2, 'Color', [0.8, 0.2, 0.2]);
        legend('Data', 'Fitted Curve', 'Location', 'southeast');
    end
    
    xlabel('Contrast Level', 'FontSize', 12);
    ylabel('Hit Rate (%)', 'FontSize', 12);
    title('Psychometric Function', 'FontSize', 14, 'FontWeight', 'bold');
    ylim([0, 100]);
    grid on;
    
    % d-prime vs Contrast
    subplot(2, 2, 2);
    plot(psychometric_results.contrast_levels, psychometric_results.dprime, ...
         'o-', 'LineWidth', 2, 'MarkerSize', 8, 'Color', [0.7, 0.3, 0.2]);
    xlabel('Contrast Level', 'FontSize', 12);
    ylabel('d''', 'FontSize', 12);
    title('Sensitivity (d'') vs Contrast', 'FontSize', 14, 'FontWeight', 'bold');
    grid on;
    
    % Accuracy vs Contrast
    subplot(2, 2, 3);
    errorbar(psychometric_results.contrast_levels, ...
             psychometric_results.accuracy * 100, ...
             psychometric_results.accuracy_se * 100, ...
             'o-', 'LineWidth', 2, 'MarkerSize', 8, 'Color', [0.3, 0.6, 0.3]);
    xlabel('Contrast Level', 'FontSize', 12);
    ylabel('Accuracy (%)', 'FontSize', 12);
    title('Overall Accuracy', 'FontSize', 14, 'FontWeight', 'bold');
    ylim([0, 100]);
    grid on;
    
    % Criterion vs Contrast
    subplot(2, 2, 4);
    plot(psychometric_results.contrast_levels, psychometric_results.criterion, ...
         'o-', 'LineWidth', 2, 'MarkerSize', 8, 'Color', [0.6, 0.3, 0.6]);
    xlabel('Contrast Level', 'FontSize', 12);
    ylabel('Criterion (c)', 'FontSize', 12);
    title('Response Bias', 'FontSize', 14, 'FontWeight', 'bold');
    yline(0, '--k', 'LineWidth', 1.5);
    grid on;
    
    sgtitle('Psychometric Analysis', 'FontSize', 16, 'FontWeight', 'bold');
end


function fig = create_rt_figure(rt_results)
    fig = figure('Position', [100, 100, 1200, 800], 'Color', 'w');
    
    % RT Distribution (histogram)
    subplot(2, 3, 1);
    histogram(rt_results.all_rts, 30, 'FaceColor', [0.4, 0.6, 0.8], 'EdgeColor', 'k');
    xlabel('Reaction Time (s)', 'FontSize', 12);
    ylabel('Count', 'FontSize', 12);
    title('RT Distribution', 'FontSize', 14, 'FontWeight', 'bold');
    xline(rt_results.overall.mean, '--r', 'Mean', 'LineWidth', 2, 'LabelVerticalAlignment', 'bottom');
    xline(rt_results.overall.median, '--g', 'Median', 'LineWidth', 2, 'LabelVerticalAlignment', 'top');
    grid on;
    
    % RT by Contrast
    subplot(2, 3, 2);
    contrasts = [rt_results.by_contrast.contrast];
    mean_rts = [rt_results.by_contrast.mean];
    se_rts = [rt_results.by_contrast.se];
    errorbar(contrasts, mean_rts, se_rts, 'o-', 'LineWidth', 2, 'MarkerSize', 8, 'Color', [0.3, 0.5, 0.7]);
    xlabel('Contrast Level', 'FontSize', 12);
    ylabel('Mean RT (s)', 'FontSize', 12);
    title('RT vs Contrast', 'FontSize', 14, 'FontWeight', 'bold');
    grid on;
    
    % Cumulative Distribution
    subplot(2, 3, 3);
    sorted_rts = sort(rt_results.all_rts);
    cdf_y = (1:length(sorted_rts)) / length(sorted_rts);
    plot(sorted_rts, cdf_y * 100, 'LineWidth', 2, 'Color', [0.2, 0.4, 0.7]);
    xlabel('Reaction Time (s)', 'FontSize', 12);
    ylabel('Cumulative Probability (%)', 'FontSize', 12);
    title('Cumulative RT Distribution', 'FontSize', 14, 'FontWeight', 'bold');
    grid on;
    
    % RT by Outcome
    subplot(2, 3, 4);
    outcome_types = {rt_results.by_outcome.outcome};
    outcome_means = [rt_results.by_outcome.mean];
    bar(categorical(outcome_types), outcome_means, 'FaceColor', [0.5, 0.7, 0.5]);
    ylabel('Mean RT (s)', 'FontSize', 12);
    title('RT by Outcome Type', 'FontSize', 14, 'FontWeight', 'bold');
    grid on;
    
    % RT distribution by contrast (using scatter with error bars instead of boxplot)
    subplot(2, 3, [5, 6]);
    if length(rt_results.by_contrast) > 0
        hold on;
        for i = 1:length(rt_results.by_contrast)
            if ~isempty(rt_results.by_contrast(i).rts)
                rts = rt_results.by_contrast(i).rts;
                x_pos = rt_results.by_contrast(i).contrast;
                
                % Scatter individual points with jitter
                x_jitter = x_pos + (rand(length(rts), 1) - 0.5) * 0.02;
                scatter(x_jitter, rts, 30, [0.5, 0.5, 0.5], 'filled', 'MarkerFaceAlpha', 0.5);
                
                % Plot mean and std
                mean_rt = mean(rts);
                std_rt = std(rts);
                errorbar(x_pos, mean_rt, std_rt, 'o', 'LineWidth', 2, ...
                        'MarkerSize', 10, 'Color', [0.2, 0.4, 0.7], ...
                        'MarkerFaceColor', [0.2, 0.4, 0.7]);
            end
        end
        xlabel('Contrast Level', 'FontSize', 12);
        ylabel('Reaction Time (s)', 'FontSize', 12);
        title('RT Distribution by Contrast', 'FontSize', 14, 'FontWeight', 'bold');
        legend({'Individual RTs', 'Mean ± SD'}, 'Location', 'best');
        grid on;
    end
    
    sgtitle('Reaction Time Analysis', 'FontSize', 16, 'FontWeight', 'bold');
end


function fig = create_stimulus_reconstruction_figure(session_data)
    fig = figure('Position', [100, 100, 1600, 1000], 'Color', 'w');
    
    % Select example trials with different contrasts
    trials = session_data.trials;
    contrasts = arrayfun(@(t) t.contrast, trials);
    unique_contrasts = unique(contrasts);
    
    % Select up to 4 example contrasts for clarity
    n_examples = min(4, length(unique_contrasts));
    selected_contrasts = unique_contrasts(round(linspace(1, length(unique_contrasts), n_examples)));
    
    for i = 1:n_examples
        contrast = selected_contrasts(i);
        
        % Find first trial with this contrast that has stimulus_on frames
        trial_idx = [];
        for t_idx = 1:length(trials)
            if contrasts(t_idx) == contrast
                % Check if this trial has stimulus_on frames
                % Handle both logical and string types
                stim_on_vals = {trials(t_idx).frames.stimulus_on};
                if iscell(stim_on_vals{1}) || ischar(stim_on_vals{1})
                    % String format
                    has_stim_on = any(cellfun(@(x) strcmpi(x, 'true'), stim_on_vals));
                else
                    % Logical format
                    has_stim_on = any([trials(t_idx).frames.stimulus_on]);
                end
                if has_stim_on
                    trial_idx = t_idx;
                    break;
                end
            end
        end
        
        if isempty(trial_idx)
            % Fall back to any trial with this contrast
            trial_idx = find(contrasts == contrast, 1);
        end
        
        if isempty(trial_idx)
            continue;
        end
        
        trial = trials(trial_idx);
        
        % Find frames where stimulus is ON
        % Handle both logical and string types
        stim_on_vals = {trial.frames.stimulus_on};
        if iscell(stim_on_vals{1}) || ischar(stim_on_vals{1})
            % String format
            stim_on_frames = find(cellfun(@(x) strcmpi(x, 'true'), stim_on_vals));
        else
            % Logical format
            stim_on_frames = find([trial.frames.stimulus_on]);
        end
        
        % Select one stimulus-on frame if available, otherwise middle frame
        if ~isempty(stim_on_frames)
            frame_idx = stim_on_frames(ceil(length(stim_on_frames)/2));
        else
            frame_idx = ceil(trial.num_frames/2);
        end
        
        % Reconstruct both noise-only and full stimulus
        [noise_seq, frame_info] = reconstruct_trial_stimuli(trial, ...
            session_data.metadata.grid_rows, session_data.metadata.grid_cols, ...
            struct('frame_indices', frame_idx, 'verbose', false, 'include_grating', false));
        
        [~, ~, full_seq] = reconstruct_trial_stimuli(trial, ...
            session_data.metadata.grid_rows, session_data.metadata.grid_cols, ...
            struct('frame_indices', frame_idx, 'verbose', false, 'include_grating', true));
        
        % Display noise-only (left column)
        subplot(n_examples, 2, (i-1)*2 + 1);
        imagesc(noise_seq(:,:,1));
        colormap(gca, gray);
        axis equal tight off;
        title(sprintf('Contrast %.2f - Noise Only\nFrame %d', contrast, frame_info(1).frame_number), ...
              'FontSize', 10);
        
        % Display full stimulus with grating (right column)
        subplot(n_examples, 2, (i-1)*2 + 2);
        % Create custom colormap: white=0, black=1, red=2
        imagesc(full_seq(:,:,1));
        cmap = [1 1 1; 0 0 0; 1 0 0];  % white, black, red
        colormap(gca, cmap);
        caxis([0 2]);
        axis equal tight off;
        stim_status = 'OFF';
        % Handle both logical and string types
        if ischar(frame_info(1).stimulus_on) || iscell(frame_info(1).stimulus_on)
            if strcmpi(frame_info(1).stimulus_on, 'true')
                stim_status = 'ON';
            end
        elseif frame_info(1).stimulus_on
            stim_status = 'ON';
        end
        title(sprintf('Full Stimulus (Noise+Grating)\nStimulus: %s, Quadrant: %s', ...
              stim_status, trial.quadrant), 'FontSize', 10);
    end
    
    sgtitle('Stimulus Reconstruction: Noise vs Full Stimulus', ...
            'FontSize', 16, 'FontWeight', 'bold');
    
    % Add legend
    annotation('textbox', [0.02, 0.02, 0.3, 0.05], ...
               'String', 'White = white tile | Black = black tile | Red = signal/grating', ...
               'FontSize', 10, 'EdgeColor', 'none', ...
               'HorizontalAlignment', 'left');
end


function fig = create_temporal_dynamics_figure(session_data, metrics)
    fig = figure('Position', [100, 100, 1200, 800], 'Color', 'w');
    
    trials = session_data.trials;
    
    % Performance over trials with moving average
    subplot(2, 2, 1);
    if ~isfield(metrics.temporal, 'insufficient_data')
        hold on;
        scatter(metrics.temporal.trial_numbers, metrics.temporal.correct * 100, ...
                20, [0.7, 0.7, 0.7], 'filled', 'MarkerFaceAlpha', 0.3);
        plot(metrics.temporal.trial_numbers, metrics.temporal.moving_avg * 100, ...
             'LineWidth', 3, 'Color', [0.2, 0.4, 0.7]);
        xlabel('Trial Number', 'FontSize', 12);
        ylabel('Accuracy (%)', 'FontSize', 12);
        title('Performance Over Trials', 'FontSize', 14, 'FontWeight', 'bold');
        ylim([0, 100]);
        legend('Individual Trials', 'Moving Average', 'Location', 'best');
        grid on;
    end
    
    % Block-wise performance
    subplot(2, 2, 2);
    if ~isfield(metrics.temporal, 'insufficient_data') && isfield(metrics.temporal, 'blocks')
        block_nums = [metrics.temporal.blocks.block_num];
        block_accs = [metrics.temporal.blocks.accuracy];
        bar(block_nums, block_accs * 100, 'FaceColor', [0.4, 0.6, 0.4]);
        xlabel('Block Number', 'FontSize', 12);
        ylabel('Accuracy (%)', 'FontSize', 12);
        title('Performance by Block', 'FontSize', 14, 'FontWeight', 'bold');
        ylim([0, 100]);
        grid on;
    end
    
    % Trial duration over time
    subplot(2, 2, 3);
    durations = [trials.duration];
    valid_durations = durations(~isnan(durations));
    if ~isempty(valid_durations)
        plot(find(~isnan(durations)), valid_durations, 'o-', ...
             'LineWidth', 1.5, 'MarkerSize', 6, 'Color', [0.6, 0.3, 0.6]);
        xlabel('Trial Number', 'FontSize', 12);
        ylabel('Trial Duration (s)', 'FontSize', 12);
        title('Trial Duration Over Time', 'FontSize', 14, 'FontWeight', 'bold');
        grid on;
    end
    
    % Reaction time over trials
    subplot(2, 2, 4);
    rts = arrayfun(@(t) t.reaction_time, trials, 'UniformOutput', false);
    rts = cell2mat(rts(cellfun(@(x) ~isempty(x) && isnumeric(x), rts)));
    valid_rt_idx = ~isnan(rts) & rts > 0;
    if sum(valid_rt_idx) > 0
        scatter(find(valid_rt_idx), rts(valid_rt_idx), 30, ...
                [0.3, 0.5, 0.8], 'filled');
        xlabel('Trial Number', 'FontSize', 12);
        ylabel('Reaction Time (s)', 'FontSize', 12);
        title('RT Over Trials', 'FontSize', 14, 'FontWeight', 'bold');
        grid on;
    end
    
    sgtitle('Temporal Dynamics', 'FontSize', 16, 'FontWeight', 'bold');
end


function fig = create_performance_heatmap(session_data, metrics)
    fig = figure('Position', [100, 100, 1000, 600], 'Color', 'w');
    
    trials = session_data.trials;
    
    % Create contrast × quadrant performance matrix
    contrasts = arrayfun(@(t) t.contrast, trials);
    quadrants = {trials.quadrant};
    outcomes = {trials.outcome};
    
    unique_contrasts = unique(contrasts);
    unique_quadrants = unique(quadrants);
    
    n_contrasts = length(unique_contrasts);
    n_quadrants = length(unique_quadrants);
    
    perf_matrix = nan(n_quadrants, n_contrasts);
    count_matrix = zeros(n_quadrants, n_contrasts);
    
    for i = 1:n_contrasts
        for j = 1:n_quadrants
            idx = (contrasts == unique_contrasts(i)) & strcmp(quadrants, unique_quadrants{j});
            trial_outcomes = outcomes(idx);
            
            if ~isempty(trial_outcomes)
                n_correct = sum(strcmp(trial_outcomes, 'hit') | strcmp(trial_outcomes, 'correct_reject'));
                perf_matrix(j, i) = n_correct / length(trial_outcomes);
                count_matrix(j, i) = length(trial_outcomes);
            end
        end
    end
    
    % Plot heatmap
    subplot(1, 2, 1);
    imagesc(perf_matrix * 100);
    colorbar;
    colormap(jet);
    caxis([0, 100]);
    
    % Set labels
    xticks(1:n_contrasts);
    xticklabels(arrayfun(@num2str, unique_contrasts, 'UniformOutput', false));
    yticks(1:n_quadrants);
    yticklabels(unique_quadrants);
    
    xlabel('Contrast Level', 'FontSize', 12);
    ylabel('Quadrant', 'FontSize', 12);
    title('Performance Heatmap (%)', 'FontSize', 14, 'FontWeight', 'bold');
    
    % Add text annotations
    for i = 1:n_contrasts
        for j = 1:n_quadrants
            if ~isnan(perf_matrix(j, i))
                text(i, j, sprintf('%.0f%%', perf_matrix(j, i) * 100), ...
                     'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold');
            end
        end
    end
    
    % Plot trial counts
    subplot(1, 2, 2);
    imagesc(count_matrix);
    colorbar;
    colormap(subplot(1,2,2), parula);
    
    xticks(1:n_contrasts);
    xticklabels(arrayfun(@num2str, unique_contrasts, 'UniformOutput', false));
    yticks(1:n_quadrants);
    yticklabels(unique_quadrants);
    
    xlabel('Contrast Level', 'FontSize', 12);
    ylabel('Quadrant', 'FontSize', 12);
    title('Trial Counts', 'FontSize', 14, 'FontWeight', 'bold');
    
    % Add text annotations
    for i = 1:n_contrasts
        for j = 1:n_quadrants
            text(i, j, sprintf('%d', count_matrix(j, i)), ...
                 'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold');
        end
    end
    
    sgtitle('Performance Heatmap: Quadrant × Contrast', 'FontSize', 16, 'FontWeight', 'bold');
end


function fig = create_speed_accuracy_figure(rt_results, metrics)
    fig = figure('Position', [100, 100, 1000, 800], 'Color', 'w');
    
    % Speed-accuracy tradeoff scatter
    subplot(2, 2, [1, 2]);
    if isfield(rt_results.speed_accuracy, 'rt')
        rt = rt_results.speed_accuracy.rt;
        correct = rt_results.speed_accuracy.correct;
        
        % Scatter plot
        hold on;
        scatter(rt(correct == 1), ones(sum(correct == 1), 1), 50, ...
                [0, 0.7, 0], 'filled', 'MarkerFaceAlpha', 0.5);
        scatter(rt(correct == 0), zeros(sum(correct == 0), 1), 50, ...
                [0.8, 0, 0], 'filled', 'MarkerFaceAlpha', 0.5);
        
        xlabel('Reaction Time (s)', 'FontSize', 12);
        ylabel('Outcome', 'FontSize', 12);
        yticks([0, 1]);
        yticklabels({'Incorrect', 'Correct'});
        title('Speed-Accuracy Scatter', 'FontSize', 14, 'FontWeight', 'bold');
        legend('Correct', 'Incorrect', 'Location', 'best');
        grid on;
    end
    
    % Binned speed-accuracy
    subplot(2, 2, 3);
    if isfield(rt_results.speed_accuracy, 'bins')
        bins = rt_results.speed_accuracy.bins;
        bin_rts = [bins.mean_rt];
        bin_accs = [bins.accuracy];
        
        plot(bin_rts, bin_accs * 100, 'o-', 'LineWidth', 2, 'MarkerSize', 10, 'Color', [0.3, 0.5, 0.7]);
        xlabel('Mean RT (s)', 'FontSize', 12);
        ylabel('Accuracy (%)', 'FontSize', 12);
        title('Binned Speed-Accuracy Tradeoff', 'FontSize', 14, 'FontWeight', 'bold');
        ylim([0, 100]);
        grid on;
    end
    
    % RT distributions for correct vs incorrect
    subplot(2, 2, 4);
    if isfield(rt_results.speed_accuracy, 'rt')
        rt = rt_results.speed_accuracy.rt;
        correct = rt_results.speed_accuracy.correct;
        
        hold on;
        histogram(rt(correct == 1), 20, 'FaceColor', [0, 0.7, 0], ...
                 'FaceAlpha', 0.5, 'Normalization', 'probability');
        histogram(rt(correct == 0), 20, 'FaceColor', [0.8, 0, 0], ...
                 'FaceAlpha', 0.5, 'Normalization', 'probability');
        
        xlabel('Reaction Time (s)', 'FontSize', 12);
        ylabel('Probability', 'FontSize', 12);
        title('RT Distributions', 'FontSize', 14, 'FontWeight', 'bold');
        legend('Correct', 'Incorrect', 'Location', 'best');
        grid on;
    end
    
    sgtitle('Speed-Accuracy Tradeoff Analysis', 'FontSize', 16, 'FontWeight', 'bold');
end


function fig = create_sdt_figure(psychometric_results, metrics)
    fig = figure('Position', [100, 100, 1000, 800], 'Color', 'w');
    
    % ROC Space
    subplot(2, 2, 1);
    hit_rates = psychometric_results.hit_rates;
    fa_rates = psychometric_results.false_alarm_rates;
    
    % Plot ROC points
    hold on;
    plot([0, 1], [0, 1], '--k', 'LineWidth', 1.5);  % Chance line
    scatter(fa_rates, hit_rates, 100, psychometric_results.contrast_levels, ...
            'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
    colorbar;
    xlabel('False Alarm Rate', 'FontSize', 12);
    ylabel('Hit Rate', 'FontSize', 12);
    title('ROC Space', 'FontSize', 14, 'FontWeight', 'bold');
    xlim([0, 1]);
    ylim([0, 1]);
    axis square;
    grid on;
    
    % d-prime vs Contrast
    subplot(2, 2, 2);
    plot(psychometric_results.contrast_levels, psychometric_results.dprime, ...
         'o-', 'LineWidth', 2, 'MarkerSize', 10, 'Color', [0.3, 0.5, 0.7]);
    xlabel('Contrast Level', 'FontSize', 12);
    ylabel('d'' (Sensitivity)', 'FontSize', 12);
    title('Sensitivity Index', 'FontSize', 14, 'FontWeight', 'bold');
    yline(0, '--k', 'LineWidth', 1.5);
    grid on;
    
    % Criterion vs Contrast
    subplot(2, 2, 3);
    plot(psychometric_results.contrast_levels, psychometric_results.criterion, ...
         'o-', 'LineWidth', 2, 'MarkerSize', 10, 'Color', [0.7, 0.3, 0.4]);
    xlabel('Contrast Level', 'FontSize', 12);
    ylabel('Criterion (c)', 'FontSize', 12);
    title('Response Bias', 'FontSize', 14, 'FontWeight', 'bold');
    yline(0, '--k', 'LineWidth', 1.5);
    grid on;
    
    % Summary table
    subplot(2, 2, 4);
    axis off;
    
    % Create text summary
    text_str = {
        sprintf('Overall Performance:');
        sprintf('  Hits: %d', metrics.overall.n_hits);
        sprintf('  Misses: %d', metrics.overall.n_misses);
        sprintf('  False Alarms: %d', metrics.overall.n_false_alarms);
        sprintf('  Correct Rejects: %d', metrics.overall.n_correct_rejects);
        sprintf('');
        sprintf('SDT Metrics:');
        sprintf('  d'': %.2f', metrics.overall.sdt.dprime);
        sprintf('  Criterion: %.2f', metrics.overall.sdt.criterion);
        sprintf('  Beta: %.2f', metrics.overall.sdt.beta);
    };
    
    text(0.1, 0.9, text_str, 'FontSize', 11, 'VerticalAlignment', 'top', 'FontName', 'FixedWidth');
    title('Summary Statistics', 'FontSize', 14, 'FontWeight', 'bold');
    
    sgtitle('Signal Detection Theory Analysis', 'FontSize', 16, 'FontWeight', 'bold');
end

