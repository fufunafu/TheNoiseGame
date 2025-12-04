% EXAMPLE_ANALYSIS.m
% Example script demonstrating the use of the Noise Game analysis suite
%
% This script provides examples of:
%   1. Basic single-session analysis
%   2. Custom options
%   3. Batch processing
%   4. Manual step-by-step analysis
%   5. Custom visualizations

%% EXAMPLE 1: Basic Single-Session Analysis
% The simplest way to analyze your data - one line!

fprintf('=== EXAMPLE 1: Basic Analysis ===\n');

% Replace with your actual file path
data_file = 'export-data/noise_game_data_20251109_135350.csv';

% Run complete analysis
results = analyze_noise_game(data_file);

% Access results
fprintf('\nSession: %s\n', results.session_data.metadata.session_info.sessionId);
fprintf('Overall Accuracy: %.1f%%\n', results.metrics.overall.accuracy * 100);
fprintf('Sensitivity (d''): %.2f\n', results.metrics.overall.sdt.dprime);

% Results are saved to ./analysis_results/ by default

%% EXAMPLE 2: Custom Options
% Customize the analysis with options

fprintf('\n=== EXAMPLE 2: Custom Options ===\n');

options = struct();
options.save_figures = true;
options.output_dir = './my_custom_results';
options.formats = {'png', 'pdf'};  % Save as both PNG and PDF
options.reconstruct_all_frames = false;  % Don't reconstruct all frames (faster)
options.reconstruct_stimuli = true;  % Show stimulus examples in figures
options.verbose = true;  % Display detailed progress

results = analyze_noise_game(data_file, options);

%% EXAMPLE 3: Batch Processing Multiple Sessions
% Process multiple sessions at once

fprintf('\n=== EXAMPLE 3: Batch Processing ===\n');

% Option A: Provide list of files
file_list = {
    'export-data/session1.csv',
    'export-data/session2.csv',
    'export-data/session3.csv'
};

% Option B: Process entire directory
% batch_results = analyze_noise_game('./export-data/');

% For this example, we'll use a single file in a list
file_list = {data_file};  % Replace with your actual file list

batch_options = struct();
batch_options.save_figures = true;
batch_options.output_dir = './batch_analysis_results';

batch_results = analyze_noise_game(file_list, batch_options);

% Access aggregated results
if isfield(batch_results, 'aggregated')
    fprintf('\nAggregated across %d sessions:\n', batch_results.n_successful);
    fprintf('Mean Accuracy: %.1f%% (SD = %.1f%%)\n', ...
            batch_results.aggregated.overall.mean_accuracy * 100, ...
            batch_results.aggregated.overall.std_accuracy * 100);
end

%% EXAMPLE 4: Step-by-Step Manual Analysis
% If you want more control, run each step separately

fprintf('\n=== EXAMPLE 4: Manual Step-by-Step Analysis ===\n');

% Step 1: Load data
session_data = load_noise_game_data(data_file);

% Step 2: Calculate metrics
metrics = calculate_performance_metrics(session_data);

% Step 3: Psychometric analysis
psychometric_results = analyze_psychometrics(session_data, metrics);

% Step 4: Reaction time analysis
rt_results = analyze_reaction_times(session_data, metrics);

% Step 5: Generate specific figures
viz_options = struct();
viz_options.save_figures = false;  % Just display, don't save
viz_options.reconstruct_stimuli = true;

figures = generate_visualizations(session_data, metrics, ...
                                 psychometric_results, rt_results, ...
                                 viz_options);

fprintf('Generated %d figures\n', length(fieldnames(figures)));

%% EXAMPLE 5: Stimulus Reconstruction
% Reconstruct visual stimuli from seed values

fprintf('\n=== EXAMPLE 5: Stimulus Reconstruction ===\n');

% Get first trial
trial = session_data.trials(1);

fprintf('Reconstructing trial %d (contrast = %.2f)...\n', ...
        trial.trial_index, trial.contrast);

% Reconstruct a few sample frames
sample_frames = [1, 10, 20];  % Frame indices to reconstruct
[stim_seq, frame_info] = reconstruct_trial_stimuli(trial, ...
    session_data.metadata.grid_rows, ...
    session_data.metadata.grid_cols, ...
    struct('frame_indices', sample_frames, 'verbose', true));

% Visualize reconstructed frames
figure('Position', [100, 100, 1200, 400], 'Color', 'w');
for i = 1:length(sample_frames)
    subplot(1, 3, i);
    imagesc(stim_seq(:,:,i));
    colormap(gray);
    axis equal tight off;
    title(sprintf('Frame %d\nSeed: %d', ...
                  frame_info(i).frame_number, ...
                  frame_info(i).seed));
end
sgtitle(sprintf('Reconstructed Stimuli - Trial %d', trial.trial_index), ...
        'FontSize', 14, 'FontWeight', 'bold');

%% EXAMPLE 6: Custom Analysis - Performance by Quadrant

fprintf('\n=== EXAMPLE 6: Custom Analysis ===\n');

% Extract data
quadrants = {session_data.trials.quadrant};
outcomes = {session_data.trials.outcome};
contrasts = [session_data.trials.contrast];

% Analyze specific contrast level
target_contrast = 0.5;
contrast_trials = session_data.trials(contrasts == target_contrast);

fprintf('Analysis for contrast = %.2f:\n', target_contrast);
fprintf('  Total trials: %d\n', length(contrast_trials));

% Count by quadrant
unique_quads = unique({contrast_trials.quadrant});
for i = 1:length(unique_quads)
    quad = unique_quads{i};
    quad_trials = contrast_trials(strcmp({contrast_trials.quadrant}, quad));
    n_hits = sum(strcmp({quad_trials.outcome}, 'hit'));
    
    fprintf('  %s: %d trials, %d hits (%.1f%%)\n', ...
            quad, length(quad_trials), n_hits, ...
            n_hits / length(quad_trials) * 100);
end

%% EXAMPLE 7: Export Results for External Analysis

fprintf('\n=== EXAMPLE 7: Export for External Analysis ===\n');

% Create a summary table for export to Excel/CSV
trial_table = table();
trial_table.TrialIndex = [session_data.trials.trial_index]';
trial_table.Contrast = [session_data.trials.contrast]';
trial_table.Quadrant = {session_data.trials.quadrant}';
trial_table.Outcome = {session_data.trials.outcome}';
trial_table.ReactionTime = [session_data.trials.reaction_time]';
trial_table.NumFrames = [session_data.trials.num_frames]';

% Save to CSV
output_file = 'trial_by_trial_data.csv';
writetable(trial_table, output_file);
fprintf('Exported trial data to: %s\n', output_file);

%% EXAMPLE 8: Compare Across Contrasts

fprintf('\n=== EXAMPLE 8: Contrast Comparison ===\n');

% Create comparison figure
figure('Position', [100, 100, 1200, 600], 'Color', 'w');

% Panel 1: Hit Rate by Contrast
subplot(1, 3, 1);
contrasts = [metrics.by_contrast.contrast];
hit_rates = [metrics.by_contrast.hit_rate];
bar(contrasts, hit_rates * 100, 'FaceColor', [0.3, 0.5, 0.8]);
xlabel('Contrast Level', 'FontSize', 12);
ylabel('Hit Rate (%)', 'FontSize', 12);
title('Hit Rate vs Contrast', 'FontSize', 14, 'FontWeight', 'bold');
ylim([0, 100]);
grid on;

% Panel 2: d-prime by Contrast
subplot(1, 3, 2);
dprimes = [metrics.by_contrast.sdt];
dprimes = arrayfun(@(x) x.dprime, dprimes);
plot(contrasts, dprimes, 'o-', 'LineWidth', 2, 'MarkerSize', 10, ...
     'Color', [0.7, 0.3, 0.3]);
xlabel('Contrast Level', 'FontSize', 12);
ylabel('d'' (Sensitivity)', 'FontSize', 12);
title('Sensitivity vs Contrast', 'FontSize', 14, 'FontWeight', 'bold');
grid on;

% Panel 3: Trial Counts by Contrast
subplot(1, 3, 3);
trial_counts = [metrics.by_contrast.n_trials];
bar(contrasts, trial_counts, 'FaceColor', [0.5, 0.7, 0.5]);
xlabel('Contrast Level', 'FontSize', 12);
ylabel('Number of Trials', 'FontSize', 12);
title('Trial Distribution', 'FontSize', 14, 'FontWeight', 'bold');
grid on;

sgtitle('Contrast-wise Analysis', 'FontSize', 16, 'FontWeight', 'bold');

%% End of Examples

fprintf('\n=== ALL EXAMPLES COMPLETE ===\n');
fprintf('Check the output directories for saved figures and reports.\n');
fprintf('Type ''help analyze_noise_game'' for more information.\n\n');

