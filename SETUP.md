# The Noise Game - Setup Guide

Complete installation and setup instructions for running The Noise Game iOS app and MATLAB analysis suite.

---

## Table of Contents

1. [iOS App Setup](#ios-app-setup)
2. [MATLAB Analysis Setup](#matlab-analysis-setup)
3. [First Run Guide](#first-run-guide)
4. [Troubleshooting](#troubleshooting)
5. [Configuration](#configuration)

---

## iOS App Setup

### Prerequisites

Before you begin, ensure you have:

- **Mac Computer** running macOS 11.0 (Big Sur) or later
- **Xcode** version 13.0 or later ([Download from Mac App Store](https://apps.apple.com/app/xcode/id497799835))
- **iOS Device** (iPad or iPhone) running iOS 13.0 or later
  - **Recommended:** iPad Pro or iPad Air for optimal display size
- **Apple Developer Account** (free account sufficient for device testing)
- **USB Cable** to connect device to Mac

### Step 1: Install Xcode

1. Open the **Mac App Store**
2. Search for "Xcode"
3. Click **Get** or **Install**
4. Wait for installation to complete (may take 30+ minutes)
5. Open Xcode and accept the license agreement
6. Wait for additional components to install

### Step 2: Configure Your Device

#### Enable Developer Mode on Mac

1. Open **System Settings** (or System Preferences)
2. Go to **Privacy & Security**
3. Scroll down and enable **Developer Mode** (if available)

#### Enable Developer Mode on iOS Device

1. On your iPad/iPhone, go to **Settings → Privacy & Security**
2. Scroll down and tap **Developer Mode**
3. Toggle **Developer Mode** to ON
4. Restart your device when prompted
5. After restart, confirm enabling Developer Mode

#### Trust Your Mac

1. Connect your iOS device to your Mac via USB cable
2. On the iOS device, tap **Trust** when prompted
3. Enter your device passcode if requested

### Step 3: Open the Project

1. Navigate to the project folder on your Mac
2. Double-click **TheNoiseGame.xcodeproj** to open in Xcode
3. Wait for Xcode to index the project (progress bar in top toolbar)

### Step 4: Configure Code Signing

#### Automatic Signing (Recommended)

1. In Xcode, select the **TheNoiseGame** project in the navigator (left panel)
2. Select the **TheNoiseGame** target
3. Go to the **Signing & Capabilities** tab
4. Check **Automatically manage signing**
5. Select your **Team** from the dropdown
   - If you don't see your team, click **Add Account** and sign in with your Apple ID
6. Xcode will automatically generate a provisioning profile

#### Change Bundle Identifier (If Needed)

If you see a signing error:

1. In the **Signing & Capabilities** tab, find **Bundle Identifier**
2. Change it to something unique, e.g., `com.yourname.TheNoiseGame`
3. Xcode will re-generate the provisioning profile

### Step 5: Select Your Device

1. At the top of Xcode, click the device selector (next to the Play/Stop buttons)
2. Choose your connected iPad or iPhone from the list
3. Make sure it shows your device name, not "Any iOS Device (arm64)"

### Step 6: Build and Run

1. Click the **Play button** (▶) in the top-left corner, or press **⌘R**
2. Xcode will:
   - Compile the app
   - Install it on your device
   - Launch the app
3. **First time only:** On your iOS device, go to **Settings → General → VPN & Device Management**
4. Tap your Apple ID and tap **Trust "Your Name"**
5. Return to the app and it should launch

### Step 7: Verify Installation

1. The app should launch and display the main screen
2. You should see:
   - Configuration controls at the top
   - A checkerboard display area
   - A "Start" button
   - Performance graphs at the bottom
3. **Test:** Tap the "Start" button to verify the app responds

---

## MATLAB Analysis Setup

### Prerequisites

- **MATLAB** R2019b or later
- **Statistics and Machine Learning Toolbox**
  - Check: Run `ver` in MATLAB command window and look for this toolbox
  - If missing, install via MATLAB Add-On Manager

### Step 1: Verify MATLAB Installation

```matlab
% Open MATLAB and run:
ver

% You should see:
% - MATLAB Version X.X (R20XXx)
% - Statistics and Machine Learning Toolbox
```

### Step 2: Add Analysis Path

```matlab
% Navigate to the ANALYSIS directory
cd('/path/to/TheNoiseGame/ANALYSIS')

% Or add to MATLAB path permanently:
addpath(genpath('/path/to/TheNoiseGame/ANALYSIS'))
savepath
```

### Step 3: Test Installation

```matlab
% Check that main function is accessible:
which analyze_noise_game

% You should see the full path to the function
% If you see "not found", verify the path was added correctly
```

### Step 4: Verify Dependencies

```matlab
% Test that required toolboxes are available:
license('test', 'statistics_toolbox')
% Should return 1 (true)

license('test', 'curve_fitting_toolbox')
% Should return 1 (true) - optional but recommended
```

---

## First Run Guide

### Running Your First Experiment

#### 1. Configure Experiment Parameters

On the iOS app main screen:

- **Grid Size:** Keep default (64×48) for most experiments
- **Stimulus Hz:** 30 Hz default (flicker rate)
- **Contrast Levels:** Configure the range you want to test (e.g., 0.1 to 0.9)
- **Trial Settings:**
  - **Trials per block:** 20-50 (depending on participant fatigue)
  - **Blocks:** 3-5 blocks per session
  - **RT Window:** 0.5-2.0 seconds (adjust based on task difficulty)

#### 2. Enter Participant Information

- Tap the settings/info icon
- Enter participant ID (e.g., "P01")
- Session information is automatically logged

#### 3. Run the Session

1. Tap **Start** to begin
2. Brief instructions will display
3. Participant responds by tapping the screen when they see the grating
4. Progress is shown between trials
5. Session automatically ends after all trials complete

#### 4. Export Data

**Automatic Export:**
- Data is automatically saved after each trial
- Complete CSV file is saved when session ends
- Location: **Files app → On My iPad → TheNoiseGame**

**Manual Export:**
1. Open the **Files** app on your iPad
2. Navigate to **On My iPad → TheNoiseGame**
3. Long-press the CSV file
4. Select **Share**
5. Choose AirDrop, email, or cloud storage

### Analyzing Your First Dataset

#### 1. Transfer Data to Computer

- Use AirDrop, email, or cloud storage
- Place CSV file in a known location (e.g., `~/Data/NoiseGame/`)

#### 2. Open MATLAB

```matlab
% Navigate to the ANALYSIS directory
cd('/path/to/TheNoiseGame/ANALYSIS')

% Or if already in path, navigate to your data
cd('~/Data/NoiseGame/')
```

#### 3. Run Analysis

```matlab
% Basic analysis (auto-saves figures and results)
results = analyze_noise_game('your_data_file.csv');

% The function will:
% - Load and parse the data
% - Calculate performance metrics
% - Fit psychometric curves
% - Analyze reaction times
% - Generate 8 comprehensive figures
% - Save results to analysis_results/ directory
```

#### 4. Review Results

Navigate to `TheNoiseGame/ANALYSIS/analysis_results/[session_name]/`:

- **Figures:** 8 publication-quality plots in `figures/` subfolder
- **Report:** Human-readable text summary (`*_report.txt`)
- **Data:** MATLAB structure (`*_results.mat`) and CSV summaries
- **Summary:** Performance metrics table (`*_summary.csv`)

---

## Troubleshooting

### iOS App Issues

#### "Could not launch TheNoiseGame"

**Solution:**
1. Go to **Settings → General → VPN & Device Management**
2. Trust your developer profile
3. Try launching again

#### "No code signing identities found"

**Solution:**
1. Sign in to Xcode with your Apple ID (**Xcode → Settings → Accounts**)
2. Re-select your team in **Signing & Capabilities**

#### "Failed to install the app"

**Solution:**
1. Delete the app from your device if it exists
2. In Xcode, go to **Product → Clean Build Folder** (⇧⌘K)
3. Build and run again

#### Device Not Showing in Xcode

**Solution:**
1. Unplug and replug the USB cable
2. Unlock your device
3. Trust the computer if prompted
4. Restart Xcode if device still doesn't appear

#### App Crashes on Launch

**Solution:**
1. Check Xcode console for error messages
2. Verify iOS version is 13.0 or later
3. Try running on a different device
4. Check for provisioning profile issues

### MATLAB Analysis Issues

#### "analyze_noise_game not found"

**Solution:**
```matlab
% Add the path explicitly:
addpath(genpath('/path/to/TheNoiseGame/ANALYSIS'))

% Verify:
which analyze_noise_game
```

#### "Insufficient data for curve fitting"

**Solution:**
- Ensure your data file has at least 3 different contrast levels
- Check that trials were completed (not just started)
- Verify CSV file format matches expected structure

#### "Undefined function or variable"

**Solution:**
- Check that Statistics and Machine Learning Toolbox is installed
- Run `ver` to verify toolbox availability
- Update MATLAB if using version older than R2019b

#### Figures Not Displaying

**Solution:**
```matlab
% Set options to display instead of save:
options.save_figures = false;
results = analyze_noise_game('data.csv', options);
```

#### Memory Errors with Large Datasets

**Solution:**
```matlab
% Reduce memory usage:
options.reconstruct_all_frames = false;  % Don't reconstruct stimuli
results = analyze_noise_game('data.csv', options);
```

---

## Configuration

### Customizing Experiment Parameters

#### In the iOS App

Most parameters can be adjusted in the app UI. For advanced settings, modify `TheNoiseGameCore.swift`:

```swift
// Trial timing
private var cueDuration: TimeInterval = 0.5
private var minGratingOnset: TimeInterval = 1.0
private var maxGratingOnset: TimeInterval = 8.0

// RT window
private var rtWindowDelay: TimeInterval = 0.0
private var rtWindowLength: TimeInterval = 2.0

// Stimulus parameters
private var stimulusHz: Double = 30.0
private var gratingFrequency: Double = 2.0  // cycles per degree
```

#### In MATLAB Analysis

Customize analysis with options structure:

```matlab
options = struct();
options.save_figures = true;              % Save figures to disk
options.output_dir = './my_results';      % Custom output directory
options.formats = {'png', 'pdf', 'eps'}; % Figure formats
options.reconstruct_stimuli = true;       % Show stimulus examples
options.verbose = true;                   % Print progress messages

results = analyze_noise_game('data.csv', options);
```

### Modifying Stimulus Appearance

Edit `CheckerboardView.swift` to change visual properties:

```swift
// Grid size
private var gridRows = 48
private var gridColumns = 64

// Square size (calculated automatically based on view size)
// Colors defined in updateColors() method
```

---

## Additional Resources

- **Main README:** [README.md](README.md)
- **Analysis Documentation:** [TheNoiseGame/ANALYSIS/README.md](TheNoiseGame/ANALYSIS/README.md)
- **Documentation Hub:** [docs/README.md](docs/README.md)
- **Data Format Specification:** [docs/data-format/CSV_FORMAT_CHANGES.md](docs/data-format/CSV_FORMAT_CHANGES.md)
- **Stimulus Generation:** [docs/matlab-analysis/StimulusGenerationDocumentation.md](docs/matlab-analysis/StimulusGenerationDocumentation.md)

---

## Getting Help

If you encounter issues not covered in this guide:

1. Check the **Xcode Console** for detailed error messages (iOS issues)
2. Check the **MATLAB Command Window** for error details (analysis issues)
3. Review the project documentation in the `docs/` directory
4. Contact the lab team for support

---

**Last Updated:** November 2025  
**Version:** 1.0

