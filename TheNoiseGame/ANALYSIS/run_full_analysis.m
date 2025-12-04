% RUN_FULL_ANALYSIS.m
% Run complete analysis with all outputs saved

fprintf('=== RUNNING FULL ANALYSIS ===\n\n');

% Configure options
options = struct();
options.save_figures = true;
options.output_dir = './analysis_results';
options.formats = {'png'};  % Save as PNG only
options.reconstruct_all_frames = false;  % Set to true if you want all frames reconstructed
options.reconstruct_stimuli = true;  % Show examples in figures
options.verbose = true;

% Run analysis
data_file = 'export-data/noise_game_data_20251110_181556.csv';
fprintf('Analyzing: %s\n\n', data_file);

try
    results = analyze_noise_game(data_file, options);
    
    fprintf('\n=== ANALYSIS COMPLETE ===\n');
    fprintf('All results saved to: %s\n', results.output_dir);
    fprintf('\nYou can now:\n');
    fprintf('  1. Check the figures directory for all plots\n');
    fprintf('  2. Open the text report for detailed statistics\n');
    fprintf('  3. Load the MAT file to explore results interactively\n');
    
catch ME
    fprintf('\n=== ERROR ===\n');
    fprintf('Error: %s\n', ME.message);
    fprintf('\nStack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
    rethrow(ME);
end

