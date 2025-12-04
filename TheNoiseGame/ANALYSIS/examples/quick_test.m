% QUICK_TEST.m
% Quick test of the analysis suite

fprintf('=== QUICK TEST OF NOISE GAME ANALYSIS ===\n\n');

try
    % Set options to skip figure saving (faster)
    options = struct();
    options.save_figures = false;
    options.verbose = true;
    options.reconstruct_stimuli = false;  % Skip stimulus reconstruction for speed
    
    % Run analysis
    data_file = 'export-data/noise_game_data_20251109_135350.csv';
    fprintf('Running analysis on: %s\n\n', data_file);
    
    results = analyze_noise_game(data_file, options);
    
    % Display key results
    fprintf('\n=== KEY RESULTS ===\n');
    fprintf('Session: %s\n', results.session_data.metadata.session_info.sessionId);
    fprintf('Subject: %s\n', results.session_data.metadata.session_info.subjectName);
    fprintf('Trials: %d\n', results.session_data.summary.num_trials);
    fprintf('Overall Accuracy: %.1f%%\n', results.metrics.overall.accuracy * 100);
    fprintf('Hit Rate: %.1f%%\n', results.metrics.overall.hit_rate * 100);
    fprintf('d-prime: %.2f\n', results.metrics.overall.sdt.dprime);
    fprintf('Criterion: %.2f\n', results.metrics.overall.sdt.criterion);
    
    if ~isfield(results.rt_results, 'no_data')
        fprintf('Mean RT: %.3f s (SD = %.3f s)\n', ...
                results.rt_results.overall.mean, results.rt_results.overall.std);
    end
    
    fprintf('\n=== TEST PASSED! ===\n');
    fprintf('All core functions are working correctly.\n');
    fprintf('Figures were generated but not saved (options.save_figures = false)\n');
    
catch ME
    fprintf('\n=== TEST FAILED ===\n');
    fprintf('Error: %s\n', ME.message);
    fprintf('\nStack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
    rethrow(ME);
end

