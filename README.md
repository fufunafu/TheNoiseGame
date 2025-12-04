# The Noise Game

A psychophysical iOS application for studying visual detection thresholds using dynamic noise stimuli and embedded Gabor patterns.

## Overview

The Noise Game is a research application designed to measure participants' ability to detect oriented gratings embedded in dynamic checkerboard noise. The app provides:

- **Real-time stimulus presentation** with precise timing control
- **Adaptive contrast adjustment** for psychometric curve estimation
- **Comprehensive data logging** with frame-by-frame seed values for stimulus reconstruction
- **Built-in performance visualization** including psychometric curves
- **Trial-by-trial feedback** for participants

## Project Components

This project consists of two main components:

### 1. iOS Application (`TheNoiseGame/`)

Native iOS app built with Swift that runs the experiment on iPad or iPhone devices.

**Key Features:**
- Dynamic checkerboard noise generation (30 Hz default)
- Gabor grating stimulus overlay with adjustable contrast
- Four-quadrant stimulus presentation
- Reaction time measurement with configurable RT windows
- Real-time performance monitoring
- CSV data export with complete trial metadata

### 2. MATLAB Analysis Suite (`TheNoiseGame/ANALYSIS/`)

Comprehensive analysis pipeline for processing experimental data.

**Key Features:**
- Automated data loading and parsing
- Stimulus reconstruction from seed values
- Psychometric curve fitting and threshold estimation
- Reaction time analysis
- Signal detection theory metrics (d-prime, criterion)
- 8-figure publication-quality visualization suite
- Batch processing for multiple sessions

## Quick Start

### Running the iOS App

1. Open `TheNoiseGame.xcodeproj` in Xcode
2. Select your target device (iPad recommended)
3. Build and run (⌘R)
4. Configure experiment parameters in the app settings
5. Tap "Start" to begin a session
6. Data is automatically exported to Files app after each session

**See [SETUP.md](SETUP.md) for detailed installation instructions.**

### Analyzing Data

1. Export CSV file from the iOS app (Files app → On My iPad → TheNoiseGame)
2. Open MATLAB and navigate to `TheNoiseGame/ANALYSIS/`
3. Run analysis:

```matlab
results = analyze_noise_game('your_data_file.csv');
```

That's it! Results, figures, and reports are automatically saved to `analysis_results/`.

**See [TheNoiseGame/ANALYSIS/README.md](TheNoiseGame/ANALYSIS/README.md) for detailed analysis documentation.**

## System Requirements

### iOS App
- **Device:** iPad or iPhone running iOS 13.0 or later
- **Xcode:** Version 13.0 or later
- **macOS:** 11.0 (Big Sur) or later for development
- **Display:** iPad recommended for optimal stimulus visibility

### MATLAB Analysis
- **MATLAB:** R2019b or later
- **Toolboxes:** Statistics and Machine Learning Toolbox (for curve fitting)
- **OS:** macOS, Windows, or Linux

## Documentation

- **[SETUP.md](SETUP.md)** - Installation and build instructions
- **[TheNoiseGame/ANALYSIS/README.md](TheNoiseGame/ANALYSIS/README.md)** - Complete MATLAB analysis guide
- **[docs/](docs/)** - Comprehensive documentation hub
  - **[docs/data-format/](docs/data-format/)** - CSV export format specification
  - **[docs/matlab-analysis/](docs/matlab-analysis/)** - Stimulus generation and implementation details
  - **[docs/ios-app/](docs/ios-app/)** - iOS app architecture (coming soon)

## Project Structure

```
TheNoiseGame/
├── README.md                          # This file
├── SETUP.md                           # Installation guide
├── TheNoiseGame.xcodeproj/           # Xcode project
├── TheNoiseGame/                      # iOS app source code
│   ├── ViewControllers/              # Main view controllers
│   ├── Views/                        # Custom UI views
│   ├── Core/                         # Core engine (DisplayTicker)
│   ├── Extensions/                   # Swift extensions
│   ├── Utils/                        # Utility functions
│   ├── TheNoiseGameCore.swift        # Experiment logic
│   ├── TheNoiseGameModels.swift      # Data models
│   ├── ANALYSIS/                     # MATLAB analysis suite
│   │   ├── README.md                 # Analysis documentation
│   │   ├── analyze_noise_game.m      # Main analysis function
│   │   ├── utils/                    # Analysis utilities
│   │   └── archive/                  # Legacy code (reference only)
│   └── Assets.xcassets/              # App icons and assets
└── docs/                              # Additional documentation
```

## Data Export Format

The app exports trial data in CSV format with the following structure:

- **Session metadata** in header comments (participant info, experiment settings)
- **Trial-by-trial events** including:
  - Frame updates with RNG seeds for reconstruction
  - User responses with reaction times
  - Trial outcomes (hit, miss, false alarm)
  - Stimulus parameters (contrast, quadrant, timing)

Each frame's stimulus can be perfectly reconstructed using the logged seed values.

**See [CSV Format Documentation](docs/data-format/CSV_FORMAT_CHANGES.md) for complete format specification.**

## Typical Workflow

1. **Configure experiment** parameters in iOS app (contrast levels, timing, etc.)
2. **Run participant** through experimental session
3. **Export data** from iOS app (automatic CSV generation)
4. **Transfer CSV** to computer with MATLAB
5. **Run analysis** using `analyze_noise_game.m`
6. **Review results** in automatically generated figures and reports
7. **Archive data** and results for publication

## Features

### Stimulus Generation
- Dynamic checkerboard noise with independent per-frame seeds
- Gaussian-enveloped Gabor gratings overlaid on noise
- Configurable spatial frequency and orientation
- Precise contrast control (0-100%)
- Reproducible from seed values

### Experimental Control
- Randomized stimulus onset timing (prevents anticipation)
- Four-quadrant spatial randomization
- Configurable RT windows
- Optional early-response penalties
- Block-based structure with breaks

### Data Quality
- Frame-by-frame logging with exact timestamps
- Complete parameter recording for reproducibility
- Automated trial outcome classification
- RT validation and windowing
- Seed-based stimulus reconstruction

### Analysis Capabilities
- Psychometric curve fitting (Weibull functions)
- Threshold estimation (50%, 75% correct)
- d-prime and bias calculation (SDT)
- RT distribution analysis
- Speed-accuracy tradeoff
- Temporal dynamics (learning curves)
- Spatial bias detection (quadrant analysis)

## Development

### iOS App Development

The app is structured with clean separation of concerns:

- `TheNoiseGameCore.swift` - Main experiment state machine
- `DisplayTicker.swift` - High-precision frame timing
- `CheckerboardView.swift` - Stimulus rendering
- `ViewController.swift` - User interface and interaction

### MATLAB Development

The analysis suite is modular and extensible:

- Each function handles one analysis component
- Functions can be used independently or via main pipeline
- Documented with extensive comments
- Examples provided in `ANALYSIS/examples/`

## Citation

If you use The Noise Game in your research, please cite:

```
The Noise Game: Visual Detection Threshold Measurement
Swamy Lab, McGill University
Version 1.0, November 2025
```

## Support & Contact

For questions, bug reports, or feature requests:
- Contact: fu.gao@mail.mcgill.ca
- Lab: Swamy Lab, McGill University

## License

This software is provided for research purposes. All rights reserved.

---

**Version:** 1.0  
**Last Updated:** November 2025  
**Maintained by:** Swamy Lab, McGill University

