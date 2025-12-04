function rt_results = analyze_reaction_times(session_data, metrics)
% ANALYZE_REACTION_TIMES Analyze reaction time data
%
% Inputs:
%   session_data - Session data structure from load_noise_game_data
%   metrics - Performance metrics from calculate_performance_metrics
%
% Output:
%   rt_results - Structure with:
%     .all_rts - All valid reaction times
%     .by_contrast - RT statistics per contrast level
%     .by_outcome - RT statistics per outcome type
%     .distributions - RT distribution parameters
%     .outliers - Identified outlier RTs
%     .speed_accuracy - Speed-accuracy tradeoff data

    fprintf('Analyzing reaction times...\n');
    
    trials = session_data.trials;
    
    % Extract all valid reaction times
    all_rts = [];
    for i = 1:length(trials)
        rt = trials(i).reaction_time;
        if ~isempty(rt) && isnumeric(rt) && ~isnan(rt) && rt > 0
            all_rts = [all_rts, rt]; %#ok<AGROW>
        end
    end
    
    if isempty(all_rts)
        warning('No valid reaction times found');
        rt_results = struct();
        rt_results.no_data = true;
        return;
    end
    
    %% Overall RT Statistics
    overall = struct();
    overall.mean = mean(all_rts);
    overall.median = median(all_rts);
    overall.std = std(all_rts);
    overall.min = min(all_rts);
    overall.max = max(all_rts);
    overall.n = length(all_rts);
    
    % Percentiles
    overall.percentiles = prctile(all_rts, [5, 25, 50, 75, 95]);
    
    % Identify outliers (using IQR method)
    q1 = overall.percentiles(2);
    q3 = overall.percentiles(4);
    iqr = q3 - q1;
    lower_bound = q1 - 1.5 * iqr;
    upper_bound = q3 + 1.5 * iqr;
    
    outlier_idx = all_rts < lower_bound | all_rts > upper_bound;
    overall.n_outliers = sum(outlier_idx);
    overall.outlier_rate = overall.n_outliers / overall.n;
    
    %% RT by Contrast Level
    contrasts = arrayfun(@(t) t.contrast, trials);
    unique_contrasts = unique(contrasts);
    unique_contrasts = sort(unique_contrasts);
    
    by_contrast = struct();
    for i = 1:length(unique_contrasts)
        contrast = unique_contrasts(i);
        contrast_trials = trials(contrasts == contrast);
        
        % Extract RTs for this contrast
        contrast_rts = [contrast_trials.reaction_time];
        contrast_rts = contrast_rts(~isnan(contrast_rts) & contrast_rts > 0);
        
        by_contrast(i).contrast = contrast;
        by_contrast(i).n = length(contrast_rts);
        
        if ~isempty(contrast_rts)
            by_contrast(i).mean = mean(contrast_rts);
            by_contrast(i).median = median(contrast_rts);
            by_contrast(i).std = std(contrast_rts);
            by_contrast(i).se = std(contrast_rts) / sqrt(length(contrast_rts));
            by_contrast(i).rts = contrast_rts;
        else
            by_contrast(i).mean = NaN;
            by_contrast(i).median = NaN;
            by_contrast(i).std = NaN;
            by_contrast(i).se = NaN;
            by_contrast(i).rts = [];
        end
    end
    
    %% RT by Outcome Type
    outcomes = {trials.outcome};
    unique_outcomes = unique(outcomes);
    
    by_outcome = struct();
    for i = 1:length(unique_outcomes)
        outcome = unique_outcomes{i};
        outcome_trials = trials(strcmp(outcomes, outcome));
        
        % Extract RTs for this outcome
        outcome_rts = [outcome_trials.reaction_time];
        outcome_rts = outcome_rts(~isnan(outcome_rts) & outcome_rts > 0);
        
        by_outcome(i).outcome = outcome;
        by_outcome(i).n = length(outcome_rts);
        
        if ~isempty(outcome_rts)
            by_outcome(i).mean = mean(outcome_rts);
            by_outcome(i).median = median(outcome_rts);
            by_outcome(i).std = std(outcome_rts);
            by_outcome(i).rts = outcome_rts;
        else
            by_outcome(i).mean = NaN;
            by_outcome(i).median = NaN;
            by_outcome(i).std = NaN;
            by_outcome(i).rts = [];
        end
    end
    
    %% Distribution Analysis
    distributions = struct();
    distributions.histogram_edges = linspace(0, max(all_rts), 30);
    distributions.histogram_counts = histcounts(all_rts, distributions.histogram_edges);
    
    % Fit exponential distribution (common for RT data)
    try
        distributions.exp_fit = fitdist(all_rts', 'Exponential');
    catch
        distributions.exp_fit = [];
    end
    
    %% Speed-Accuracy Tradeoff
    speed_accuracy = struct();
    
    % Calculate for each trial
    n_trials = length(trials);
    trial_rt = zeros(n_trials, 1);
    trial_correct = zeros(n_trials, 1);
    trial_contrast = zeros(n_trials, 1);
    
    for i = 1:n_trials
        trial_rt(i) = trials(i).reaction_time;
        trial_contrast(i) = trials(i).contrast;
        
        % Mark if correct
        if strcmp(trials(i).outcome, 'hit') || strcmp(trials(i).outcome, 'correct_reject')
            trial_correct(i) = 1;
        end
    end
    
    % Remove invalid RTs
    valid_idx = ~isnan(trial_rt) & trial_rt > 0;
    trial_rt = trial_rt(valid_idx);
    trial_correct = trial_correct(valid_idx);
    trial_contrast = trial_contrast(valid_idx);
    
    speed_accuracy.rt = trial_rt;
    speed_accuracy.correct = trial_correct;
    speed_accuracy.contrast = trial_contrast;
    
    % Bin RTs and calculate accuracy per bin
    if length(trial_rt) >= 10
        n_bins = min(5, floor(length(trial_rt) / 10));
        rt_edges = prctile(trial_rt, linspace(0, 100, n_bins + 1));
        
        speed_accuracy.bins = struct();
        for b = 1:n_bins
            bin_idx = trial_rt >= rt_edges(b) & trial_rt < rt_edges(b+1);
            if b == n_bins  % Include upper edge in last bin
                bin_idx = trial_rt >= rt_edges(b) & trial_rt <= rt_edges(b+1);
            end
            
            speed_accuracy.bins(b).rt_range = [rt_edges(b), rt_edges(b+1)];
            speed_accuracy.bins(b).mean_rt = mean(trial_rt(bin_idx));
            speed_accuracy.bins(b).accuracy = mean(trial_correct(bin_idx));
            speed_accuracy.bins(b).n = sum(bin_idx);
        end
    end
    
    %% Statistical Tests
    stats = struct();
    
    % ANOVA: RT ~ Contrast (if multiple contrasts)
    if length(unique_contrasts) > 1
        % Prepare data for ANOVA
        contrast_labels = {};
        rt_values = [];
        
        for i = 1:length(by_contrast)
            if ~isempty(by_contrast(i).rts)
                n_rts = length(by_contrast(i).rts);
                contrast_labels = [contrast_labels; repmat({num2str(by_contrast(i).contrast)}, n_rts, 1)]; %#ok<AGROW>
                rt_values = [rt_values; by_contrast(i).rts(:)]; %#ok<AGROW>
            end
        end
        
        if length(unique(contrast_labels)) > 1
            try
                [stats.anova_p, stats.anova_table, stats.anova_stats] = ...
                    anova1(rt_values, contrast_labels, 'off');
            catch
                stats.anova_p = NaN;
            end
        else
            stats.anova_p = NaN;
        end
    else
        stats.anova_p = NaN;
    end
    
    %% Compile Results
    rt_results = struct();
    rt_results.overall = overall;
    rt_results.by_contrast = by_contrast;
    rt_results.by_outcome = by_outcome;
    rt_results.distributions = distributions;
    rt_results.speed_accuracy = speed_accuracy;
    rt_results.stats = stats;
    rt_results.all_rts = all_rts;
    
    %% Print Summary
    fprintf('\n=== Reaction Time Analysis ===\n');
    fprintf('Overall Statistics:\n');
    fprintf('  Mean RT: %.3f s (SD = %.3f s)\n', overall.mean, overall.std);
    fprintf('  Median RT: %.3f s\n', overall.median);
    fprintf('  Range: [%.3f, %.3f] s\n', overall.min, overall.max);
    fprintf('  N valid trials: %d\n', overall.n);
    fprintf('  Outliers: %d (%.1f%%)\n', overall.n_outliers, overall.outlier_rate * 100);
    
    fprintf('\nRT by Contrast:\n');
    fprintf('Contrast  Mean RT   Median RT  N\n');
    fprintf('--------  --------  ---------  ---\n');
    for i = 1:length(by_contrast)
        fprintf('%6.2f    %6.3f s  %6.3f s   %3d\n', ...
                by_contrast(i).contrast, by_contrast(i).mean, ...
                by_contrast(i).median, by_contrast(i).n);
    end
    
    if ~isnan(stats.anova_p)
        fprintf('\nANOVA (RT ~ Contrast): p = %.4f\n', stats.anova_p);
    end
    fprintf('==============================\n\n');
end

