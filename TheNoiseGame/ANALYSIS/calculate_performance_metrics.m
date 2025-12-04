function metrics = calculate_performance_metrics(session_data)
% CALCULATE_PERFORMANCE_METRICS Compute comprehensive performance metrics
%
% Input:
%   session_data - Session data structure from load_noise_game_data
%
% Output:
%   metrics - Structure with performance metrics:
%     .overall - Overall performance across all trials
%     .by_contrast - Performance broken down by contrast level
%     .by_quadrant - Performance broken down by quadrant
%     .temporal - Performance over time (learning curves)
%     .sdt - Signal detection theory metrics (d', criterion, beta)

    trials = session_data.trials;
    num_trials = length(trials);
    
    fprintf('Calculating performance metrics for %d trials...\n', num_trials);
    
    %% Overall Performance Metrics
    overall = struct();
    
    % Extract outcomes
    outcomes = {trials.outcome};
    
    % Count each outcome type
    overall.n_hits = sum(strcmp(outcomes, 'hit'));
    overall.n_misses = sum(strcmp(outcomes, 'miss'));
    overall.n_false_alarms = sum(strcmp(outcomes, 'false_alarm'));
    overall.n_correct_rejects = sum(strcmp(outcomes, 'correct_reject'));
    overall.n_total = num_trials;
    
    % Calculate rates
    n_signal = overall.n_hits + overall.n_misses;
    n_noise = overall.n_false_alarms + overall.n_correct_rejects;
    
    if n_signal > 0
        overall.hit_rate = overall.n_hits / n_signal;
    else
        overall.hit_rate = NaN;
    end
    
    if n_noise > 0
        overall.false_alarm_rate = overall.n_false_alarms / n_noise;
    else
        overall.false_alarm_rate = NaN;
    end
    
    overall.accuracy = (overall.n_hits + overall.n_correct_rejects) / num_trials;
    
    % Signal Detection Theory metrics
    overall.sdt = calculate_sdt_metrics(overall.hit_rate, overall.false_alarm_rate);
    
    %% Performance by Contrast Level
    contrasts = arrayfun(@(t) t.contrast, trials);
    unique_contrasts = unique(contrasts);
    unique_contrasts = sort(unique_contrasts);
    
    by_contrast = struct();
    for i = 1:length(unique_contrasts)
        contrast = unique_contrasts(i);
        contrast_trials = trials(contrasts == contrast);
        
        contrast_outcomes = {contrast_trials.outcome};
        
        n_hits = sum(strcmp(contrast_outcomes, 'hit'));
        n_misses = sum(strcmp(contrast_outcomes, 'miss'));
        n_fa = sum(strcmp(contrast_outcomes, 'false_alarm'));
        n_cr = sum(strcmp(contrast_outcomes, 'correct_reject'));
        
        by_contrast(i).contrast = contrast;
        by_contrast(i).n_trials = length(contrast_trials);
        by_contrast(i).n_hits = n_hits;
        by_contrast(i).n_misses = n_misses;
        by_contrast(i).n_false_alarms = n_fa;
        by_contrast(i).n_correct_rejects = n_cr;
        
        n_signal = n_hits + n_misses;
        n_noise = n_fa + n_cr;
        
        if n_signal > 0
            by_contrast(i).hit_rate = n_hits / n_signal;
        else
            by_contrast(i).hit_rate = NaN;
        end
        
        if n_noise > 0
            by_contrast(i).false_alarm_rate = n_fa / n_noise;
        else
            by_contrast(i).false_alarm_rate = NaN;
        end
        
        by_contrast(i).accuracy = (n_hits + n_cr) / length(contrast_trials);
        by_contrast(i).sdt = calculate_sdt_metrics(by_contrast(i).hit_rate, ...
                                                    by_contrast(i).false_alarm_rate);
    end
    
    %% Performance by Quadrant
    quadrants = {trials.quadrant};
    unique_quadrants = unique(quadrants);
    
    by_quadrant = struct();
    for i = 1:length(unique_quadrants)
        quadrant = unique_quadrants{i};
        quadrant_trials = trials(strcmp(quadrants, quadrant));
        
        quadrant_outcomes = {quadrant_trials.outcome};
        
        n_hits = sum(strcmp(quadrant_outcomes, 'hit'));
        n_misses = sum(strcmp(quadrant_outcomes, 'miss'));
        
        by_quadrant(i).quadrant = quadrant;
        by_quadrant(i).n_trials = length(quadrant_trials);
        by_quadrant(i).n_hits = n_hits;
        by_quadrant(i).n_misses = n_misses;
        
        if (n_hits + n_misses) > 0
            by_quadrant(i).hit_rate = n_hits / (n_hits + n_misses);
        else
            by_quadrant(i).hit_rate = NaN;
        end
        
        by_quadrant(i).accuracy = n_hits / length(quadrant_trials);
    end
    
    %% Temporal Dynamics (Learning Curves)
    temporal = struct();
    
    % Performance over trials (moving average window)
    window_size = min(10, floor(num_trials / 5));
    if window_size >= 3
        temporal.trial_numbers = 1:num_trials;
        temporal.correct = zeros(num_trials, 1);
        
        for i = 1:num_trials
            if strcmp(outcomes{i}, 'hit') || strcmp(outcomes{i}, 'correct_reject')
                temporal.correct(i) = 1;
            end
        end
        
        % Calculate moving average
        temporal.moving_avg = movmean(temporal.correct, window_size);
        
        % Bin trials into blocks for block-wise analysis
        n_blocks = min(10, num_trials);
        block_size = floor(num_trials / n_blocks);
        
        temporal.blocks = struct();
        for b = 1:n_blocks
            start_idx = (b-1) * block_size + 1;
            end_idx = min(b * block_size, num_trials);
            
            block_outcomes = outcomes(start_idx:end_idx);
            n_correct = sum(strcmp(block_outcomes, 'hit') | ...
                          strcmp(block_outcomes, 'correct_reject'));
            
            temporal.blocks(b).block_num = b;
            temporal.blocks(b).start_trial = start_idx;
            temporal.blocks(b).end_trial = end_idx;
            temporal.blocks(b).n_trials = end_idx - start_idx + 1;
            temporal.blocks(b).accuracy = n_correct / (end_idx - start_idx + 1);
        end
    else
        temporal.insufficient_data = true;
    end
    
    %% Compile metrics structure
    metrics = struct();
    metrics.overall = overall;
    metrics.by_contrast = by_contrast;
    metrics.by_quadrant = by_quadrant;
    metrics.temporal = temporal;
    
    fprintf('Performance metrics calculated.\n');
end


function sdt = calculate_sdt_metrics(hit_rate, fa_rate)
% CALCULATE_SDT_METRICS Calculate Signal Detection Theory metrics
%
% Applies correction for extreme values (0 and 1) using log-linear rule

    % Apply correction for extreme rates (Hautus, 1995)
    % Replace 0 with 0.5/n and 1 with (n-0.5)/n
    % Here we assume reasonable n (e.g., 20 trials minimum)
    min_rate = 0.01;  % 1% floor
    max_rate = 0.99;  % 99% ceiling
    
    hit_rate_corrected = max(min_rate, min(max_rate, hit_rate));
    fa_rate_corrected = max(min_rate, min(max_rate, fa_rate));
    
    % Calculate d-prime (sensitivity)
    if ~isnan(hit_rate_corrected) && ~isnan(fa_rate_corrected)
        % Use norminv if available (Statistics Toolbox), otherwise use approximation
        if exist('norminv', 'file')
            z_hit = norminv(hit_rate_corrected);
            z_fa = norminv(fa_rate_corrected);
        else
            % Approximation of inverse normal CDF (accurate to ~0.001)
            z_hit = norminv_approx(hit_rate_corrected);
            z_fa = norminv_approx(fa_rate_corrected);
        end
        
        sdt.dprime = z_hit - z_fa;
        
        % Calculate criterion (response bias)
        sdt.criterion = -0.5 * (z_hit + z_fa);
        
        % Calculate beta (likelihood ratio)
        sdt.beta = exp(z_fa^2 - z_hit^2) / 2;
        
        % Calculate c (alternative criterion measure)
        sdt.c = -sdt.criterion;
    else
        sdt.dprime = NaN;
        sdt.criterion = NaN;
        sdt.beta = NaN;
        sdt.c = NaN;
    end
end


function z = norminv_approx(p)
% NORMINV_APPROX Approximation of inverse normal CDF
% Uses rational approximation from Abramowitz and Stegun
    
    if p <= 0 || p >= 1
        z = NaN;
        return;
    end
    
    % Constants for rational approximation
    a = [2.515517, 0.802853, 0.010328];
    b = [1.432788, 0.189269, 0.001308];
    
    if p < 0.5
        % Lower tail
        t = sqrt(-2 * log(p));
        z = -(t - (a(1) + a(2)*t + a(3)*t^2) / ...
             (1 + b(1)*t + b(2)*t^2 + b(3)*t^3));
    else
        % Upper tail
        t = sqrt(-2 * log(1 - p));
        z = t - (a(1) + a(2)*t + a(3)*t^2) / ...
            (1 + b(1)*t + b(2)*t^2 + b(3)*t^3);
    end
end

