function psychometric_results = analyze_psychometrics(session_data, metrics)
% ANALYZE_PSYCHOMETRICS Perform psychometric analysis on behavioral data
%
% Inputs:
%   session_data - Session data structure from load_noise_game_data
%   metrics - Performance metrics from calculate_performance_metrics
%
% Output:
%   psychometric_results - Structure with:
%     .contrast_levels - Array of contrast values tested
%     .hit_rates - Hit rate for each contrast
%     .false_alarm_rates - FA rate for each contrast
%     .dprime - d' for each contrast
%     .accuracy - Accuracy for each contrast
%     .n_trials - Number of trials per contrast
%     .curve_fit - Fitted psychometric curve parameters
%     .threshold - Estimated detection threshold

    fprintf('Performing psychometric analysis...\n');
    
    % Add utils path
    addpath(fullfile(fileparts(mfilename('fullpath')), 'utils'));
    
    % Extract contrast-wise performance from metrics
    by_contrast = metrics.by_contrast;
    n_contrasts = length(by_contrast);
    
    % Initialize output arrays
    contrast_levels = zeros(n_contrasts, 1);
    hit_rates = zeros(n_contrasts, 1);
    fa_rates = zeros(n_contrasts, 1);
    dprime = zeros(n_contrasts, 1);
    accuracy = zeros(n_contrasts, 1);
    n_trials = zeros(n_contrasts, 1);
    criterion = zeros(n_contrasts, 1);
    
    % Extract data
    for i = 1:n_contrasts
        contrast_levels(i) = by_contrast(i).contrast;
        hit_rates(i) = by_contrast(i).hit_rate;
        fa_rates(i) = by_contrast(i).false_alarm_rate;
        dprime(i) = by_contrast(i).sdt.dprime;
        criterion(i) = by_contrast(i).sdt.criterion;
        accuracy(i) = by_contrast(i).accuracy;
        n_trials(i) = by_contrast(i).n_trials;
    end
    
    % Sort by contrast
    [contrast_levels, sort_idx] = sort(contrast_levels);
    hit_rates = hit_rates(sort_idx);
    fa_rates = fa_rates(sort_idx);
    dprime = dprime(sort_idx);
    criterion = criterion(sort_idx);
    accuracy = accuracy(sort_idx);
    n_trials = n_trials(sort_idx);
    
    % Calculate standard errors (binomial proportion)
    hit_rate_se = sqrt(hit_rates .* (1 - hit_rates) ./ n_trials);
    accuracy_se = sqrt(accuracy .* (1 - accuracy) ./ n_trials);
    
    % Fit psychometric curve to hit rate data
    % Only use non-zero contrasts for fitting
    valid_idx = contrast_levels > 0 & ~isnan(hit_rates);
    
    if sum(valid_idx) >= 3
        [fit_params, fitted_curve, gof] = fit_psychometric_curve(...
            contrast_levels(valid_idx), hit_rates(valid_idx), 'sigmoid');
        
        % Generate smooth curve for plotting
        x_smooth = linspace(min(contrast_levels(valid_idx)), ...
                           max(contrast_levels(valid_idx)), 100);
        y_smooth = fitted_curve(x_smooth);
        
        curve_fit = struct();
        curve_fit.params = fit_params;
        curve_fit.x = x_smooth;
        curve_fit.y = y_smooth;
        curve_fit.gof = gof;
        
        % Estimate threshold (e.g., 75% correct)
        threshold_criterion = 0.75;
        if isfield(fit_params, 'threshold')
            curve_fit.threshold_75 = fit_params.threshold;
        else
            % Find threshold by inverting the curve
            [~, thresh_idx] = min(abs(y_smooth - threshold_criterion));
            curve_fit.threshold_75 = x_smooth(thresh_idx);
        end
    else
        warning('Insufficient data points for curve fitting');
        curve_fit = struct();
        curve_fit.insufficient_data = true;
    end
    
    % Compile results
    psychometric_results = struct();
    psychometric_results.contrast_levels = contrast_levels;
    psychometric_results.hit_rates = hit_rates;
    psychometric_results.hit_rate_se = hit_rate_se;
    psychometric_results.false_alarm_rates = fa_rates;
    psychometric_results.dprime = dprime;
    psychometric_results.criterion = criterion;
    psychometric_results.accuracy = accuracy;
    psychometric_results.accuracy_se = accuracy_se;
    psychometric_results.n_trials = n_trials;
    psychometric_results.curve_fit = curve_fit;
    
    % Print summary
    fprintf('\n=== Psychometric Analysis Results ===\n');
    fprintf('Contrast  Hit Rate  Accuracy  d''      N Trials\n');
    fprintf('--------  --------  --------  ------  --------\n');
    for i = 1:n_contrasts
        fprintf('%6.2f    %6.2f%%  %6.2f%%  %6.2f  %8d\n', ...
                contrast_levels(i), hit_rates(i)*100, accuracy(i)*100, ...
                dprime(i), n_trials(i));
    end
    
    if ~isfield(curve_fit, 'insufficient_data')
        fprintf('\nPsychometric Curve Fit:\n');
        fprintf('  Threshold (75%%): %.3f\n', curve_fit.threshold_75);
        fprintf('  R-squared: %.3f\n', curve_fit.gof.rsquared);
        fprintf('  RMSE: %.3f\n', curve_fit.gof.rmse);
    end
    fprintf('====================================\n\n');
end

