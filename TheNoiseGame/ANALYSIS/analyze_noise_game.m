function results = analyze_noise_game(input, options)
% ANALYZE_NOISE_GAME Comprehensive analysis of Noise Game experimental data
%
% Main analysis function that orchestrates data loading, performance metrics,
% psychometric analysis, reaction time analysis, stimulus reconstruction,
% visualization, and report generation.
%
% Usage:
%   results = analyze_noise_game(filepath)
%   results = analyze_noise_game(filepath, options)
%   results = analyze_noise_game({file1, file2, ...})
%   results = analyze_noise_game(directory_path)
%
% Inputs:
%   input - Can be:
%       - Single CSV file path (string)
%       - Cell array of CSV file paths (for batch processing)
%       - Directory path containing CSV files (for batch processing)
%
%   options - Optional structure with fields:
%       .save_figures - Save generated figures (default: true)
%       .output_dir - Output directory (default: './analysis_results')
%       .formats - Figure formats: {'png', 'pdf', 'eps'} (default: {'png'})
%       .reconstruct_all_frames - Reconstruct all stimulus frames (default: false)
%       .reconstruct_stimuli - Show stimulus examples in figures (default: true)
%       .verbose - Display detailed progress (default: true)
%
% Output:
%   results - Structure containing:
%       .session_data - Loaded and parsed session data
%       .metrics - Performance metrics
%       .psychometric_results - Psychometric analysis
%       .rt_results - Reaction time analysis
%       .figures - Figure handles (if not saved)
%       .options - Analysis options used
%
% Examples:
%   % Single session analysis
%   results = analyze_noise_game('noise_game_data_20251109_135350.csv');
%
%   % With custom options
%   opts.save_figures = true;
%   opts.output_dir = './my_results';
%   opts.formats = {'png', 'pdf', 'eps'};
%   results = analyze_noise_game('data.csv', opts);
%
%   % Batch processing
%   files = {'session1.csv', 'session2.csv', 'session3.csv'};
%   results = analyze_noise_game(files);
%
%   % Process all files in directory
%   results = analyze_noise_game('./data_folder/');
%
% See also: load_noise_game_data, calculate_performance_metrics,
%           analyze_psychometrics, analyze_reaction_times,
%           batch_process_sessions

    %% Input Validation and Batch Detection
    if nargin < 1
        error('Usage: analyze_noise_game(filepath) or analyze_noise_game({file1, file2, ...})');
    end
    
    if nargin < 2
        options = struct();
    end
    
    % Set default options
    if ~isfield(options, 'save_figures')
        options.save_figures = true;
    end
    if ~isfield(options, 'output_dir')
        options.output_dir = './analysis_results';
    end
    if ~isfield(options, 'formats')
        options.formats = {'png'};  % PNG only by default
    end
    if ~isfield(options, 'reconstruct_all_frames')
        options.reconstruct_all_frames = false;
    end
    if ~isfield(options, 'reconstruct_stimuli')
        options.reconstruct_stimuli = true;
    end
    if ~isfield(options, 'verbose')
        options.verbose = true;
    end
    
    % Detect batch processing mode
    is_batch = false;
    
    if iscell(input)
        % Cell array of files - batch mode
        is_batch = true;
    elseif ischar(input) && isfolder(input)
        % Directory - batch mode
        is_batch = true;
    elseif ischar(input) && isfile(input)
        % Single file - single session mode
        is_batch = false;
    else
        error('Invalid input: must be a file path, cell array of paths, or directory');
    end
    
    %% Route to Appropriate Processing Function
    if is_batch
        % Batch processing mode
        if options.verbose
            fprintf('\n========================================\n');
            fprintf('BATCH PROCESSING MODE\n');
            fprintf('========================================\n\n');
        end
        
        results = batch_process_sessions(input, options);
        return;
    end
    
    %% Single Session Analysis
    if options.verbose
        fprintf('\n========================================\n');
        fprintf('THE NOISE GAME - ANALYSIS PIPELINE\n');
        fprintf('========================================\n\n');
    end
    
    start_time = tic;
    
    %% Step 1: Load Data
    if options.verbose
        fprintf('[1/7] Loading data...\n');
    end
    
    session_data = load_noise_game_data(input);
    
    %% Step 2: Calculate Performance Metrics
    if options.verbose
        fprintf('[2/7] Calculating performance metrics...\n');
    end
    
    metrics = calculate_performance_metrics(session_data);
    
    %% Step 3: Psychometric Analysis
    if options.verbose
        fprintf('[3/7] Performing psychometric analysis...\n');
    end
    
    psychometric_results = analyze_psychometrics(session_data, metrics);
    
    %% Step 4: Reaction Time Analysis
    if options.verbose
        fprintf('[4/7] Analyzing reaction times...\n');
    end
    
    rt_results = analyze_reaction_times(session_data, metrics);
    
    %% Step 5: Stimulus Reconstruction (optional)
    if options.reconstruct_all_frames
        if options.verbose
            fprintf('[5/7] Reconstructing all stimuli...\n');
        end
        
        reconstructed_trials = struct();
        for i = 1:length(session_data.trials)
            trial = session_data.trials(i);
            if trial.num_frames > 0
                [stim_seq, frame_info] = reconstruct_trial_stimuli(...
                    trial, ...
                    session_data.metadata.grid_rows, ...
                    session_data.metadata.grid_cols, ...
                    struct('verbose', false));
                
                reconstructed_trials(i).trial_index = trial.trial_index;
                reconstructed_trials(i).stimulus_sequence = stim_seq;
                reconstructed_trials(i).frame_info = frame_info;
            end
            
            if options.verbose && mod(i, 10) == 0
                fprintf('  Reconstructed %d/%d trials\n', i, length(session_data.trials));
            end
        end
        
        session_data.reconstructed_trials = reconstructed_trials;
    else
        if options.verbose
            fprintf('[5/7] Skipping full stimulus reconstruction (set options.reconstruct_all_frames=true to enable)\n');
        end
    end
    
    %% Step 6: Generate Visualizations
    if options.verbose
        fprintf('[6/7] Generating visualizations...\n');
    end
    
    % Set up visualization options
    viz_options = struct();
    viz_options.save_figures = options.save_figures;
    viz_options.formats = options.formats;
    viz_options.reconstruct_stimuli = options.reconstruct_stimuli;
    
    % Create output directory for this session
    if options.save_figures
        [~, filename, ~] = fileparts(input);
        session_output_dir = fullfile(options.output_dir, filename);
        viz_options.output_dir = fullfile(session_output_dir, 'figures');
    else
        viz_options.output_dir = options.output_dir;
    end
    
    figures = generate_visualizations(session_data, metrics, ...
                                     psychometric_results, rt_results, ...
                                     viz_options);
    
    %% Step 7: Generate Report
    if options.verbose
        fprintf('[7/7] Generating analysis report...\n');
    end
    
    % Compile complete results structure
    results = struct();
    results.session_data = session_data;
    results.metrics = metrics;
    results.psychometric_results = psychometric_results;
    results.rt_results = rt_results;
    results.options = options;
    
    if ~options.save_figures
        results.figures = figures;
    end
    
    % Generate report
    report_options = struct();
    if options.save_figures
        [~, filename, ~] = fileparts(input);
        report_options.output_dir = fullfile(options.output_dir, filename);
        report_options.session_name = filename;
    else
        report_options.output_dir = options.output_dir;
        report_options.session_name = session_data.metadata.session_info.sessionId;
    end
    
    generate_analysis_report(session_data, metrics, psychometric_results, ...
                           rt_results, results, report_options);
    
    %% Analysis Complete
    elapsed_time = toc(start_time);
    
    if options.verbose
        fprintf('\n========================================\n');
        fprintf('ANALYSIS COMPLETE\n');
        fprintf('========================================\n');
        fprintf('Total time: %.2f seconds\n', elapsed_time);
        fprintf('Session: %s\n', session_data.metadata.session_info.sessionId);
        fprintf('Subject: %s\n', session_data.metadata.session_info.subjectName);
        fprintf('Trials analyzed: %d\n', session_data.summary.num_trials);
        fprintf('Overall accuracy: %.1f%%\n', metrics.overall.accuracy * 100);
        fprintf('Sensitivity (d''): %.2f\n', metrics.overall.sdt.dprime);
        
        if ~isfield(rt_results, 'no_data')
            fprintf('Mean RT: %.3f s\n', rt_results.overall.mean);
        end
        
        if options.save_figures
            fprintf('\nResults saved to: %s\n', report_options.output_dir);
        end
        
        fprintf('========================================\n\n');
    end
    
    % Store final output directory in results
    results.output_dir = report_options.output_dir;
end

