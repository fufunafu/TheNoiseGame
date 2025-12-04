# The Noise Game - Comprehensive MATLAB Analysis Suite

A complete analysis pipeline for The Noise Game experimental data, featuring stimulus reconstruction, psychometric analysis, reaction time analysis, and comprehensive visualizations.

## Overview

This analysis suite processes CSV export files from The Noise Game iOS application, providing:

- **Data Loading**: Parse CSV files with session metadata and trial-by-trial data
- **Stimulus Reconstruction**: Reproduce exact checkerboard stimuli from seed values
- **Performance Metrics**: Calculate hit rates, accuracies, and signal detection theory metrics
- **Psychometric Analysis**: Fit psychometric curves and estimate detection thresholds
- **Reaction Time Analysis**: Comprehensive RT statistics and speed-accuracy tradeoffs
- **Visualization Suite**: 8 comprehensive figure types for publication-quality plots
- **Batch Processing**: Analyze multiple sessions and aggregate results
- **Report Generation**: Automatic text reports, CSV summaries, and MAT files

## Quick Start

### Basic Usage

```matlab
% Single session analysis
results = analyze_noise_game('noise_game_data_20251109_135350.csv');
```

**New to the analysis suite?** Check out [examples/example_analysis.m](examples/example_analysis.m) for a comprehensive walkthrough.

That's it! This single command will:
1. Load and parse your data
2. Calculate all performance metrics
3. Perform psychometric and RT analyses
4. Generate 8 comprehensive figures
5. Save results to `./analysis_results/`

### Batch Processing

```matlab
% Process multiple files
files = {'session1.csv', 'session2.csv', 'session3.csv'};
batch_results = analyze_noise_game(files);

% Or process entire directory
batch_results = analyze_noise_game('./data_folder/');
```

### Custom Options

```matlab
options = struct();
options.save_figures = true;
options.output_dir = './my_results';
options.formats = {'png', 'pdf', 'eps'};
options.reconstruct_all_frames = true;  % Reconstruct all stimulus frames
options.reconstruct_stimuli = true;     % Show examples in figures

results = analyze_noise_game('data.csv', options);
```

## File Structure

```
TheNoiseGame/ANALYSIS/
├── analyze_noise_game.m              # Main analysis function (START HERE)
├── load_noise_game_data.m            # Data loading and parsing
├── calculate_performance_metrics.m   # Performance metrics calculation
├── analyze_psychometrics.m           # Psychometric analysis
├── analyze_reaction_times.m          # Reaction time analysis
├── reconstruct_trial_stimuli.m       # Stimulus reconstruction from seeds
├── generate_gabor_mask.m             # Gabor patch mask generation (NEW!)
├── apply_grating_to_noise.m          # Grating pattern compositor (NEW!)
├── generate_visualizations.m         # Comprehensive visualization suite
├── batch_process_sessions.m          # Batch processing multiple sessions
├── generate_analysis_report.m        # Report generation
├── bw_matrix_from_seed.m            # Seed-based stimulus generator (existing)
├── generate_matrix.m                 # Matrix generation wrapper (existing)
├── utils/
│   ├── parse_csv_header.m           # CSV header parsing
│   ├── fit_psychometric_curve.m     # Psychometric curve fitting
│   └── export_figures.m             # Figure export utility
├── examples/                         # Example scripts and tutorials
│   ├── example_analysis.m           # Comprehensive analysis example
│   ├── quick_test.m                 # Quick test script
│   └── README.md                    # Examples documentation
├── archive/                          # Legacy code from previous experiments
└── README.md                         # This file
```

## Output Structure

When you run the analysis, the following directory structure is created:

```
analysis_results/
└── [session_name]/
    ├── figures/
    │   ├── fig1_session_overview.png
    │   ├── fig2_psychometric.png
    │   ├── fig3_reaction_times.png
    │   ├── fig4_stimulus_reconstruction.png
    │   ├── fig5_temporal_dynamics.png
    │   ├── fig6_performance_heatmap.png
    │   ├── fig7_speed_accuracy.png
    │   └── fig8_sdt_analysis.png
    ├── [session_name]_results.mat      # Complete MATLAB results structure
    ├── [session_name]_report.txt       # Human-readable text report
    ├── [session_name]_summary.csv      # Summary statistics table
    └── [session_name]_by_contrast.csv  # Detailed contrast-wise results
```

## Detailed Usage

### 1. Data Loading

```matlab
% Load data directly
session_data = load_noise_game_data('data.csv');

% Explore the structure
session_data.metadata          % Session info and experimental parameters
session_data.trials           % Array of trial structures
session_data.summary          % Quick summary statistics
session_data.all_events       % Complete event table
```

### 2. Performance Metrics

```matlab
metrics = calculate_performance_metrics(session_data);

% Access results
metrics.overall               % Overall performance across all trials
metrics.by_contrast          % Performance by contrast level
metrics.by_quadrant          % Performance by stimulus quadrant
metrics.temporal             % Performance over time (learning curves)
```

### 3. Psychometric Analysis

```matlab
psychometric_results = analyze_psychometrics(session_data, metrics);

% Fitted psychometric curve
psychometric_results.curve_fit.threshold_75  % 75% correct threshold
psychometric_results.dprime                  % d-prime by contrast
```

### 4. Reaction Time Analysis

```matlab
rt_results = analyze_reaction_times(session_data, metrics);

% RT statistics
rt_results.overall.mean      % Mean RT
rt_results.by_contrast      % RT by contrast level
rt_results.speed_accuracy   % Speed-accuracy tradeoff data
```

### 5. Stimulus Reconstruction

The analysis suite supports two types of stimulus reconstruction:

#### Noise-Only Reconstruction
Reconstruct the background checkerboard pattern from seeds:

```matlab
% Reconstruct noise-only frames
trial = session_data.trials(1);
[noise_seq, frame_info] = reconstruct_trial_stimuli(...
    trial, ...
    session_data.metadata.grid_rows, ...
    session_data.metadata.grid_cols);

% noise_seq is a 3D logical array (rows × cols × frames)
% true = black, false = white
imagesc(noise_seq(:,:,10));
colormap(gray);
title(sprintf('Noise Frame %d, Seed: %d', 10, frame_info(10).seed));
```

#### Full Stimulus Reconstruction (New!)
Reconstruct the complete stimulus including grating pattern:

```matlab
% Reconstruct full stimulus (noise + grating)
options = struct();
options.include_grating = true;  % Enable full reconstruction
options.verbose = false;

[noise_seq, frame_info, full_seq] = reconstruct_trial_stimuli(...
    trial, ...
    session_data.metadata.grid_rows, ...
    session_data.metadata.grid_cols, ...
    options);

% full_seq is a 3D array (rows × cols × frames)
% 0 = white, 1 = black, 2 = signal/grating tile
imagesc(full_seq(:,:,10));
colormap([1 1 1; 0 0 0; 1 0 0]);  % white, black, red
caxis([0 2]);
title(sprintf('Full Stimulus Frame %d (Contrast=%.2f)', 10, trial.contrast));
```

**What participants actually saw:**
- During `stimulusOn=false`: Only noise pattern
- During `stimulusOn=true`: Noise + Gabor grating in specified quadrant
- Grating contrast determines % of Gabor patch tiles showing signal
- Signal tiles appear in red (value=2) in reconstructed frames

### 6. Generate Specific Figures

```matlab
% You can call visualization functions directly
viz_options.save_figures = false;  % Display only, don't save
figures = generate_visualizations(session_data, metrics, ...
                                 psychometric_results, rt_results, ...
                                 viz_options);

% Access individual figure handles
figure(figures.fig1);  % Session overview
figure(figures.fig2);  % Psychometric curves
```

## Figure Gallery

### Figure 1: Session Overview
- Trial timeline with outcome markers
- Accuracy by contrast level
- Outcome distribution (pie chart)
- Performance over time

### Figure 2: Psychometric Curves
- Hit rate vs contrast with fitted curve
- Sensitivity (d') vs contrast
- Overall accuracy
- Response bias (criterion)

### Figure 3: Reaction Time Analysis
- RT distribution histogram
- RT by contrast level
- Cumulative RT distribution
- RT by outcome type
- Box plots by contrast

### Figure 4: Stimulus Reconstruction Examples
- Side-by-side comparison: noise-only vs full stimulus (noise+grating)
- Sample frames from different contrast levels
- Shows Gabor grating pattern in correct quadrant
- Visual verification of stimulus generation
- Red tiles indicate signal/grating presence

### Figure 5: Temporal Dynamics
- Performance over trials with moving average
- Block-wise performance
- Trial duration over time
- Reaction time progression

### Figure 6: Performance Heatmaps
- Contrast × Quadrant performance matrix
- Trial count heatmap
- Visual identification of spatial biases

### Figure 7: Speed-Accuracy Tradeoff
- RT vs accuracy scatter plots
- Binned speed-accuracy curves
- RT distributions for correct/incorrect trials

### Figure 8: Signal Detection Theory Analysis
- ROC space visualization
- d-prime and criterion by contrast
- SDT summary statistics

## Batch Processing

Process multiple sessions and generate aggregate statistics:

```matlab
% Process all files in a directory
batch_results = analyze_noise_game('./data_folder/');

% Access aggregated results
batch_results.aggregated.overall           % Mean performance across sessions
batch_results.aggregated.by_contrast      % Aggregated psychometric curve
batch_results.sessions                    % Individual session results

% Aggregated figure is automatically generated showing:
% - Performance across sessions
% - Mean psychometric curve with SEM
% - Individual session overlays
```

## Advanced Features

### Custom Analysis Pipeline

You can run individual components separately:

```matlab
% Step 1: Load data
session_data = load_noise_game_data('data.csv');

% Step 2: Custom analysis
metrics = calculate_performance_metrics(session_data);

% Step 3: Filter data (e.g., high contrast only)
high_contrast_trials = session_data.trials([session_data.trials.contrast] > 0.5);

% Step 4: Custom visualizations
% ... your custom code here
```

### Stimulus Reconstruction for Analysis

```matlab
% Reconstruct all frames for correlation analysis
for i = 1:length(session_data.trials)
    trial = session_data.trials(i);
    [stim_seq, ~] = reconstruct_trial_stimuli(trial, 48, 64);
    
    % Calculate frame-to-frame correlation
    for f = 1:size(stim_seq, 3)-1
        frame1 = double(stim_seq(:,:,f));
        frame2 = double(stim_seq(:,:,f+1));
        r = corrcoef(frame1(:), frame2(:));
        correlations(f) = r(1,2);
    end
end
```

### Full Stimulus Reconstruction Functions

Two new functions enable complete stimulus reconstruction:

#### `generate_gabor_mask.m`
Generates the Gabor patch mask for any quadrant:

```matlab
% Generate Gabor mask for a specific quadrant
mask = generate_gabor_mask(48, 64, 'top_left');

% mask is a matrix (rows × cols) with values 0.0 to 1.0
% Higher values indicate stronger signal presence
% Visualize the mask
imagesc(mask);
colormap(hot);
colorbar;
title('Gabor Mask - Top Left Quadrant');
```

**Parameters:**
- 3 Gaussian columns per quadrant
- Width: 2 squares (gaborWidth = 1.0)
- Height: 7 squares (gaborHeight = 3.5)
- Gaussian envelope with σx=0.5, σy=2.0
- Matches Swift implementation exactly

#### `apply_grating_to_noise.m`
Applies grating pattern to noise background:

```matlab
% Apply grating with 40% contrast
noise_frame = bw_matrix_from_seed_rect(seed, 48, 64);
gabor_mask = generate_gabor_mask(48, 64, 'top_left');
contrast = 0.4;

[composite, signal_mask] = apply_grating_to_noise(...
    noise_frame, gabor_mask, contrast, seed);

% composite: 0=white, 1=black, 2=signal
% signal_mask: logical indicating signal tiles
```

**How it works:**
1. Collects all Gabor patch tiles (mask > 0.01)
2. Selects contrast% of tiles using seeded shuffle
3. Marks selected tiles as signal (value = 2)
4. Ensures reproducible reconstruction from seed

## Requirements

- MATLAB R2019b or later (recommended)
- Statistics and Machine Learning Toolbox (for curve fitting and ANOVA)
- No additional dependencies required

## Data Format

The analysis suite expects CSV files in the format exported by The Noise Game iOS app:

```csv
# SESSION_INFO
# sessionId: experiment_subject_date
# subjectName: subject_id
...
# TRIAL_SETTINGS
# gridSize: 64x48
# stimulusHz: 30
...
timestamp,sessionTime,trialTime,eventType,sessionId,trialIndex,coherence,gratingContrast,quadrant,frameNumber,seed,stimulusOn,response,reactionTime,withinRTWindow
```

## Troubleshooting

### "No data section found in file"
- Check that your CSV file has the correct header format
- Ensure there are no extra blank lines before the data section

### "Insufficient data for curve fitting"
- Need at least 3 different contrast levels with valid data
- Check that trials were completed successfully

### Figures not displaying
- Set `options.save_figures = false` to display figures instead of saving
- Check that output directory has write permissions

### Memory issues with large datasets
- Set `options.reconstruct_all_frames = false` (default)
- Process sessions individually rather than batch mode

## Citation

If you use this analysis suite in your research, please cite:

```
The Noise Game Analysis Suite
Version 1.0, November 2025
Swamy Lab, McGill University
```

## Support

For questions, bug reports, or feature requests, please contact the development team.

## License

This software is provided for research purposes. All rights reserved.

---

**Version:** 1.0  
**Last Updated:** November 2025  
**Compatible with:** The Noise Game iOS App (Current Version)

