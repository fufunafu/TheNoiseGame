# Checkerboard Stimulus Generation and Reproducibility Documentation

**Version:** 1.0  
**Date:** November 2025  
**Author:** The Noise Game Research Team

---

## Table of Contents

1. [Introduction & Purpose](#introduction--purpose)
2. [Technical Architecture](#technical-architecture)
3. [Random Number Generation Algorithms](#random-number-generation-algorithms)
4. [MATLAB Reproduction Guide](#matlab-reproduction-guide)
5. [Practical Examples](#practical-examples)
6. [Reference Section](#reference-section)
7. [Troubleshooting](#troubleshooting)

---

## 1. Introduction & Purpose

### Overview

The Noise Game experiment presents flickering checkerboard stimuli to subjects while recording behavioral and neural responses. A critical requirement for post-hoc analysis is the ability to **exactly reconstruct** the visual stimulus presented during each trial. This document describes how checkerboard frames are generated and how to reproduce them in MATLAB for analysis.

### Why Reproducibility Matters

Reproducible stimulus generation enables researchers to:
- Correlate specific visual patterns with neural responses
- Verify experimental conditions post-hoc
- Reconstruct stimulus sequences for computational modeling
- Debug experimental protocols by comparing intended vs. actual stimuli
- Ensure data integrity across analysis pipelines

### Key Design Principle: Seed-Based Generation

Each checkerboard frame is generated from a **single seed value**. By logging this seed, we can perfectly reconstruct the entire frame later in MATLAB, ensuring bit-exact reproducibility of all stimulus patterns.

**Important:** The entire checkerboard grid for any given frame is generated from one seed—not one seed per tile or per row, but one seed per complete frame.

---

## 2. Technical Architecture

### System Overview

The stimulus generation system uses two different Random Number Generators (RNGs) for different purposes:

1. **SeededRandomGenerator (LCG)**: Used during runtime in the Swift iOS application
2. **XorShift32**: Used for MATLAB-compatible reconstruction and verification

Both generators are **deterministic** and **reproducible** when initialized with the same seed.

### Frame Generation Pipeline

```
1. New Frame Request
        ↓
2. Generate/Retrieve Seed (UInt64 or UInt32)
        ↓
3. Initialize RNG with Seed
        ↓
4. Generate Grid (row-by-row, column-by-column)
        ↓
5. Each tile = Bool.random(using: RNG)
        ↓
6. Apply Balance Enforcement (50/50 black/white)
        ↓
7. Log Seed for Reproducibility
        ↓
8. Display Frame
```

### Grid Generation Order

The checkerboard grid is generated in **row-major order**:
- Iterate through each row (top to bottom)
- For each row, iterate through each column (left to right)
- Generate one boolean value per tile using the seeded RNG

```
Grid[0,0] → Grid[0,1] → ... → Grid[0,cols-1]
Grid[1,0] → Grid[1,1] → ... → Grid[1,cols-1]
...
Grid[rows-1,0] → ... → Grid[rows-1,cols-1]
```

This ordering **must** be preserved exactly for MATLAB reconstruction.

### Stimulus Types

The system generates two types of frames:

1. **Noise Frames**: Pure random checkerboard (50/50 black/white balance)
2. **Coherent Frames**: Background noise + Gabor patch with directional grating

Both types use the same seed-based generation approach.

---

## 3. Random Number Generation Algorithms

### 3.1 SeededRandomGenerator (Linear Congruential Generator)

**Purpose:** Used during runtime in the Swift application for actual stimulus generation.

**Algorithm:** Linear Congruential Generator (LCG) based on Knuth's MMIX

**Seed Type:** UInt64 (64-bit unsigned integer)

**Formula:**
```
state[n+1] = (state[n] × 6364136223846793005 + 1442695040888963407) mod 2^64
```

**Swift Implementation:**
```swift
struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        // LCG parameters from Knuth's MMIX
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
```

**Seed Generation:**
```swift
static func generateSeed() -> UInt64 {
    let time = UInt64(Date().timeIntervalSince1970 * 1_000_000)
    let random = UInt64.random(in: 0...UInt64.max)
    return time ^ random
}
```

New seeds combine microsecond-precision timestamps with system randomness for uniqueness.

### 3.2 XorShift32 (For MATLAB Compatibility)

**Purpose:** MATLAB-compatible RNG for stimulus reconstruction and verification.

**Algorithm:** 32-bit XorShift with specific shift parameters

**Seed Type:** UInt32 (32-bit unsigned integer)

**Formula:**
```
x = x XOR (x << 13)
x = x XOR (x >> 17)
x = x XOR (x << 5)
```

**Swift Implementation:**
```swift
struct XorShift32 {
    private(set) var state: UInt32
    
    init(seed: UInt32) {
        // State must be nonzero, use fallback if zero
        self.state = seed == 0 ? 2463534242 : seed
    }
    
    mutating func nextUInt32() -> UInt32 {
        var x = state
        x ^= x << 13
        x ^= x >> 17
        x ^= x << 5
        state = x
        return x
    }
    
    mutating func nextBool() -> Bool {
        return (nextUInt32() & 0x8000_0000) != 0
    }
}
```

**MATLAB Implementation:**
```matlab
function M = bw_matrix_from_seed(seed, n)
    % M is logical n-by-n matrix where true = black
    % seed is uint32 or convertible to uint32
    
    if nargin < 2, n = 40; end
    x = uint32(seed);
    if x == 0
        x = uint32(2463534242); % same nonzero fallback
    end
    
    function x = next_u32(x)
        x = bitxor(x, bitshift(x, 13, 'uint32'));
        x = bitxor(x, bitshift(x, -17, 'uint32')); % right shift
        x = bitxor(x, bitshift(x, 5, 'uint32'));
    end
    
    M = false(n, n);
    for i = 1:n
        for j = 1:n
            x = next_u32(x);
            % test the top bit to match Swift
            M(i,j) = bitand(x, uint32(hex2dec('80000000'))) ~= 0;
        end
    end
end
```

**Critical Implementation Details:**
- Seed value of 0 is invalid; automatically replaced with 2463534242
- Boolean values determined by testing the **top bit** (0x80000000)
- Bit operations use unsigned 32-bit arithmetic
- Both Swift and MATLAB implementations produce **identical** output

---

## 4. MATLAB Reproduction Guide

### 4.1 Prerequisites

You need two MATLAB functions (included in the codebase):
1. `bw_matrix_from_seed.m` (in `SeedGenerator.m`)
2. `generate_matrix.m` (wrapper function)

Both files are located in: `TheNoiseGame/ANALYSIS/`

### 4.2 Extracting Seeds from Experiment Logs

During experiments, the system logs frame information in CSV format to the console:

**Log Format:**
```
timestamp,updateIndex,seed,stimulusType,coherence,gratingContrast
1699365123.456,1,3894562178,noise,0.0,1.0
1699365123.489,2,1847293856,coherent,80.0,1.0
1699365123.522,3,2938475612,noise,0.0,1.0
```

**Column Definitions:**
- `timestamp`: Unix timestamp (seconds since epoch)
- `updateIndex`: Frame number in sequence
- `seed`: UInt32 or UInt64 seed value used for this frame
- `stimulusType`: "noise" or "coherent"
- `coherence`: Coherence percentage (0.0-100.0)
- `gratingContrast`: Grating contrast (0.0-1.0)

**To extract seeds:**
```matlab
% Read the log file
data = readtable('experiment_log.csv');

% Extract seed for frame 100
frame_index = 100;
seed = data.seed(frame_index);
```

### 4.3 Reproducing a Single Frame

**Method 1: Using the convenience function**
```matlab
% Generate and display matrix for a specific seed
seed = 3894562178;
n = 40;  % Grid size (e.g., 40x40)

generate_matrix(seed, n);
```

This will:
- Generate the n×n matrix
- Print the matrix to console
- Save to file: `bw_<seed>.csv`

**Method 2: Using the core function**
```matlab
% Generate matrix only (no file output)
seed = 3894562178;
n = 40;

M = bw_matrix_from_seed(seed, n);

% M is now a logical matrix where:
% true (1) = black tile
% false (0) = white tile

% Visualize
imagesc(M);
colormap(gray);
axis equal;
title(['Stimulus Frame - Seed: ' num2str(seed)]);
```

### 4.4 Reproducing an Entire Trial Sequence

```matlab
% Load experiment log
log = readtable('trial_001_log.csv');

% Get dimensions from experiment parameters
rows = 40;
cols = 40;

% Number of frames
num_frames = height(log);

% Preallocate 3D array: rows × cols × frames
stimulus_sequence = false(rows, cols, num_frames);

% Generate each frame
for i = 1:num_frames
    seed = log.seed(i);
    stimulus_sequence(:,:,i) = bw_matrix_from_seed(seed, rows);
    
    % Progress indicator
    if mod(i, 100) == 0
        fprintf('Generated %d/%d frames\n', i, num_frames);
    end
end

% Now stimulus_sequence contains the entire trial
% Frame i is accessible as: stimulus_sequence(:,:,i)
```

### 4.5 Verification Procedure

To verify correct reconstruction:

```matlab
% 1. Generate test frame with known seed
test_seed = 123456789;
test_matrix = bw_matrix_from_seed(test_seed, 40);

% 2. Check matrix properties
fprintf('Matrix size: %dx%d\n', size(test_matrix,1), size(test_matrix,2));
fprintf('Number of black tiles: %d\n', sum(test_matrix(:)));
fprintf('Number of white tiles: %d\n', sum(~test_matrix(:)));

% 3. Visual inspection
figure;
imagesc(test_matrix);
colormap(gray);
axis equal tight;
title(['Seed: ' num2str(test_seed)]);

% 4. Checksum verification (if available from logs)
% The app may log checksums: sum of all tile values
checksum = sum(test_matrix(:));
fprintf('Checksum: %d\n', checksum);
```

---

## 5. Practical Examples

### Example 1: Basic Frame Reconstruction

**Scenario:** You have a seed from your experiment log and want to see what was displayed.

```matlab
% From experiment log: frame 250 used seed 2847561923
seed = 2847561923;
grid_size = 40;

% Reconstruct the frame
frame = bw_matrix_from_seed(seed, grid_size);

% Visualize
figure('Position', [100 100 600 600]);
imagesc(frame);
colormap(gray);
axis equal tight off;
title(['Frame from Seed: ' num2str(seed)], 'FontSize', 14);

% Print statistics
fprintf('Black tiles: %d (%.1f%%)\n', sum(frame(:)), 100*mean(frame(:)));
fprintf('White tiles: %d (%.1f%%)\n', sum(~frame(:)), 100*mean(~frame(:)));
```

### Example 2: Comparing Multiple Frames

**Scenario:** Compare frames from different time points in a trial.

```matlab
% Seeds from three time points
seeds = [1234567890, 9876543210, 5555555555];
titles = {'Fixation Period', 'Stimulus Onset', 'Response Period'};

figure('Position', [100 100 1200 400]);
for i = 1:3
    subplot(1, 3, i);
    frame = bw_matrix_from_seed(seeds(i), 40);
    imagesc(frame);
    colormap(gray);
    axis equal tight off;
    title(titles{i}, 'FontSize', 12);
end
sgtitle('Stimulus Progression During Trial', 'FontSize', 14, 'FontWeight', 'bold');
```

### Example 3: Temporal Correlation Analysis

**Scenario:** Analyze how stimulus patterns change over time.

```matlab
% Load trial data
log = readtable('trial_data.csv');
num_frames = min(100, height(log));  % First 100 frames

% Generate frames
frames = false(40, 40, num_frames);
for i = 1:num_frames
    frames(:,:,i) = bw_matrix_from_seed(log.seed(i), 40);
end

% Calculate frame-to-frame correlation
correlations = zeros(num_frames-1, 1);
for i = 1:num_frames-1
    frame1 = double(frames(:,:,i));
    frame2 = double(frames(:,:,i+1));
    
    % Pearson correlation between consecutive frames
    r = corrcoef(frame1(:), frame2(:));
    correlations(i) = r(1,2);
end

% Plot correlation over time
figure;
plot(correlations, 'LineWidth', 2);
xlabel('Frame Number', 'FontSize', 12);
ylabel('Correlation with Next Frame', 'FontSize', 12);
title('Temporal Independence of Stimulus Frames', 'FontSize', 14);
grid on;

% Should be near zero for independent frames
fprintf('Mean correlation: %.4f (should be ~0 for random frames)\n', mean(correlations));
```

### Example 4: Batch Processing Multiple Trials

**Scenario:** Reconstruct stimuli from an entire experimental session.

```matlab
% Directory containing experiment logs
log_dir = 'experiment_2024_11_07/';
trial_files = dir(fullfile(log_dir, 'trial_*.csv'));

% Process each trial
for trial_idx = 1:length(trial_files)
    fprintf('Processing trial %d/%d: %s\n', trial_idx, length(trial_files), ...
            trial_files(trial_idx).name);
    
    % Load trial log
    log_path = fullfile(log_dir, trial_files(trial_idx).name);
    log = readtable(log_path);
    
    % Generate stimulus sequence
    num_frames = height(log);
    stimulus = false(40, 40, num_frames);
    
    for frame_idx = 1:num_frames
        stimulus(:,:,frame_idx) = bw_matrix_from_seed(log.seed(frame_idx), 40);
    end
    
    % Save reconstructed stimulus
    output_file = fullfile(log_dir, sprintf('stimulus_trial_%03d.mat', trial_idx));
    save(output_file, 'stimulus', 'log', '-v7.3');
    
    fprintf('  Saved %d frames to %s\n', num_frames, output_file);
end

fprintf('\nBatch processing complete!\n');
```

### Example 5: Verifying Grid Size

**Scenario:** Different experiments may use different grid sizes. Verify the correct size.

```matlab
% Common grid sizes in the experiment
possible_sizes = [20, 30, 40, 50];

% Test seed
test_seed = 1234567890;

% Generate and compare
figure('Position', [100 100 1000 250]);
for i = 1:length(possible_sizes)
    n = possible_sizes(i);
    M = bw_matrix_from_seed(test_seed, n);
    
    subplot(1, 4, i);
    imagesc(M);
    colormap(gray);
    axis equal tight;
    title(sprintf('%dx%d grid', n, n), 'FontSize', 12);
end
sgtitle(['Same Seed (' num2str(test_seed) '), Different Grid Sizes'], ...
        'FontSize', 14, 'FontWeight', 'bold');
```

---

## 6. Reference Section

### 6.1 File Locations in Codebase

**Swift Implementation:**
- **RNG Definitions**: `TheNoiseGame/TheNoiseGameModels.swift`
  - Lines 7-29: `SeededRandomGenerator` (LCG)
  - Lines 32-69: `XorShift32` (MATLAB-compatible)
  - Lines 72-89: `generateBlackWhiteMatrix()` utility function

- **Frame Generation**: `TheNoiseGame/TheNoiseGameCore.swift`
  - Lines 158-181: `makeNoiseFrame()` - Pure noise generation
  - Lines 190-246: `makeCoherentFrame()` - Coherent stimulus with Gabor patch
  - Lines 298-323: `flipRandomTiles()` - Balance enforcement

- **Display & Logging**: `TheNoiseGame/TheNoiseGameFlickerView.swift`
  - Lines 280-299: `updateAllTiles()` - Frame update with seed logging

**MATLAB Implementation:**
- **Core Function**: `TheNoiseGame/ANALYSIS/SeedGenerator.m`
  - `bw_matrix_from_seed(seed, n)` - Generate matrix from seed

- **Convenience Wrapper**: `TheNoiseGame/ANALYSIS/generate_matrix.m`
  - `generate_matrix(seed, n)` - Generate and save matrix

- **Example Usage**: `TheNoiseGame/SeedGenerator.swift`
  - Demonstrates seed generation and CSV export

### 6.2 Key Functions and Their Purposes

| Function | File | Purpose |
|----------|------|---------|
| `SeededRandomGenerator.init(seed:)` | TheNoiseGameModels.swift | Initialize LCG with seed |
| `SeededRandomGenerator.next()` | TheNoiseGameModels.swift | Generate next random UInt64 |
| `SeededRandomGenerator.generateSeed()` | TheNoiseGameModels.swift | Create new unique seed |
| `XorShift32.init(seed:)` | TheNoiseGameModels.swift | Initialize XorShift with seed |
| `XorShift32.nextBool()` | TheNoiseGameModels.swift | Generate random boolean |
| `generateBlackWhiteMatrix(seed:size:)` | TheNoiseGameModels.swift | Create full matrix from seed |
| `makeNoiseFrame(seed:)` | TheNoiseGameCore.swift | Generate noise stimulus frame |
| `makeCoherentFrame(coherence:seed:)` | TheNoiseGameCore.swift | Generate coherent stimulus frame |
| `bw_matrix_from_seed(seed, n)` | SeedGenerator.m (MATLAB) | Reconstruct matrix in MATLAB |
| `generate_matrix(seed, n)` | generate_matrix.m (MATLAB) | MATLAB wrapper with file output |

### 6.3 Data Structures

**Checkerboard Grid:**
- Type: 2D Boolean array
- Dimensions: `rows × cols` (typically 40×40)
- Values: `true` = black (1), `false` = white (0)
- Storage order: Row-major (row-by-row, left-to-right)

**Seed Values:**
- Swift Runtime: UInt64 (0 to 18,446,744,073,709,551,615)
- MATLAB Reconstruction: UInt32 (0 to 4,294,967,295)
- Invalid seed: 0 (automatically replaced with 2463534242)

### 6.4 Algorithm References

**Linear Congruential Generator (LCG):**
- Based on: Knuth, D. E. (1997). *The Art of Computer Programming, Volume 2: Seminumerical Algorithms* (3rd ed.). Addison-Wesley.
- Parameters from: MMIX (Knuth's 64-bit RISC architecture)
- Multiplier: 6364136223846793005
- Increment: 1442695040888963407
- Modulus: 2^64

**XorShift Random Number Generator:**
- Marsaglia, G. (2003). "Xorshift RNGs". *Journal of Statistical Software*, 8(14), 1-6.
- Variant: 32-bit XorShift with shifts [13, 17, 5]
- Period: 2^32 - 1 (all nonzero 32-bit values)
- Fast, simple, and platform-independent

### 6.5 Log File Format Specification

**CSV Format:**
```
timestamp,updateIndex,seed,stimulusType,coherence,gratingContrast
<float>,<int>,<uint64>,<string>,<float>,<float>
```

**Field Specifications:**
- `timestamp`: Unix timestamp (seconds.microseconds since 1970-01-01)
- `updateIndex`: Sequential frame number (1-indexed)
- `seed`: Seed value used for this frame (UInt64 or UInt32)
- `stimulusType`: Either "noise" or "coherent"
- `coherence`: Coherence level in percentage (0.0-100.0)
- `gratingContrast`: Contrast level as fraction (0.0-1.0)

**Example:**
```
1699365123.456,1,3894562178,noise,0.0,1.0
1699365123.489,2,1847293856,coherent,80.0,1.0
```

---

## 7. Troubleshooting

### Issue 1: MATLAB Matrix Doesn't Match Expected Output

**Symptoms:**
- Reconstructed frame looks different from expected
- Checksum mismatch

**Possible Causes & Solutions:**

1. **Wrong Grid Size**
   ```matlab
   % Check experiment parameters for correct grid dimensions
   % Common sizes: 20×20, 30×30, 40×40, 50×50
   M = bw_matrix_from_seed(seed, correct_grid_size);
   ```

2. **Seed Value Truncation**
   ```matlab
   % Ensure seed is read as uint32 or uint64, not double
   seed = uint64(seed_from_log);  % or uint32()
   M = bw_matrix_from_seed(seed, n);
   ```

3. **Row/Column Order Confusion**
   ```matlab
   % MATLAB matrices are row-major by default (correct)
   % If visualizing incorrectly, try:
   imagesc(M);  % Correct
   % NOT: imagesc(M');  % Incorrect (transposed)
   ```

### Issue 2: All Seeds Produce Same Pattern

**Symptoms:**
- Different seeds yield identical matrices
- No variation across frames

**Possible Causes & Solutions:**

1. **Seed Not Updating**
   ```matlab
   % Check that you're reading different seeds
   unique_seeds = unique(log.seed);
   fprintf('Found %d unique seeds\n', length(unique_seeds));
   
   % Should be ~equal to number of frames
   ```

2. **RNG State Not Resetting**
   ```matlab
   % Each call to bw_matrix_from_seed() should be independent
   % Ensure you're not reusing RNG state between calls
   
   % CORRECT:
   M1 = bw_matrix_from_seed(seed1, n);
   M2 = bw_matrix_from_seed(seed2, n);
   
   % These should be different (unless seed1 == seed2)
   ```

### Issue 3: Zero Seed Produces Error

**Symptoms:**
- Seed value of 0 causes unexpected results
- Matrix generation fails

**Solution:**
```matlab
% The functions automatically handle zero seeds
% But if implementing custom code, check:
if seed == 0
    seed = uint32(2463534242);  % Standard fallback
end
```

This is already implemented in `bw_matrix_from_seed()`, so should not occur with the provided functions.

### Issue 4: Checksum Verification Fails

**Symptoms:**
- Calculated checksum doesn't match logged value
- Frame reconstruction appears incorrect

**Solution:**
```matlab
% Recalculate checksum
M = bw_matrix_from_seed(seed, n);

% For noise frames: checksum = count of white tiles (value 1)
checksum_noise = sum(M(:));

% For coherent frames: may include red (value 2) tiles
% Check experiment log for checksum calculation method

fprintf('Calculated checksum: %d\n', checksum_noise);
fprintf('Expected checksum: %d\n', expected_from_log);

% Small differences may be due to balance enforcement
% or different grid sizes
```

### Issue 5: Performance Issues with Large Sequences

**Symptoms:**
- Slow reconstruction of many frames
- MATLAB runs out of memory

**Solutions:**

1. **Process in Batches**
   ```matlab
   batch_size = 1000;
   num_batches = ceil(num_frames / batch_size);
   
   for batch = 1:num_batches
       start_idx = (batch-1)*batch_size + 1;
       end_idx = min(batch*batch_size, num_frames);
       
       % Process this batch
       for i = start_idx:end_idx
           % Generate and process frame
       end
       
       % Save batch results
       save(sprintf('batch_%03d.mat', batch), ...);
   end
   ```

2. **Use Sparse Storage**
   ```matlab
   % If analyzing specific frames only
   frames_of_interest = [100, 500, 1000, 1500];
   stimulus = cell(length(frames_of_interest), 1);
   
   for i = 1:length(frames_of_interest)
       frame_idx = frames_of_interest(i);
       seed = log.seed(frame_idx);
       stimulus{i} = bw_matrix_from_seed(seed, n);
   end
   ```

### Issue 6: Inconsistent Results Across MATLAB Versions

**Symptoms:**
- Same code produces different results on different machines
- Bit operations behave differently

**Solution:**
```matlab
% Ensure using unsigned integer types explicitly
seed = uint32(seed_value);

% Check MATLAB version
ver('MATLAB')

% The provided code works on MATLAB R2016b and later
% For older versions, verify bitwise operations:
x = uint32(12345);
result = bitxor(x, bitshift(x, 13, 'uint32'));
% Should match expected XorShift behavior
```

---

## Appendix A: Quick Reference Card

### MATLAB Functions

```matlab
% Generate single matrix
M = bw_matrix_from_seed(seed, n);

% Generate and save to CSV
generate_matrix(seed, n);

% Generate with random seed
generate_matrix();  % Uses random seed, n=40
```

### Visualization Template

```matlab
seed = 1234567890;
M = bw_matrix_from_seed(seed, 40);

figure;
imagesc(M);
colormap(gray);
axis equal tight;
title(['Seed: ' num2str(seed)]);
colorbar;
```

### Common Grid Sizes

- Small: 20×20 (400 tiles)
- Medium: 30×30 (900 tiles)
- Standard: 40×40 (1600 tiles)
- Large: 50×50 (2500 tiles)

### Seed Value Ranges

- UInt32: 1 to 4,294,967,295
- UInt64: 1 to 18,446,744,073,709,551,615
- Invalid: 0 (auto-replaced with 2463534242)

---

## Appendix B: Validation Test Suite

Use this test suite to verify correct implementation:

```matlab
% Test 1: Deterministic Generation
fprintf('Test 1: Deterministic Generation...\n');
seed = 999888777;
M1 = bw_matrix_from_seed(seed, 40);
M2 = bw_matrix_from_seed(seed, 40);
assert(isequal(M1, M2), 'Same seed should produce identical matrices');
fprintf('  PASS: Deterministic generation verified\n\n');

% Test 2: Different Seeds Produce Different Matrices
fprintf('Test 2: Different Seeds...\n');
seed1 = 111222333;
seed2 = 444555666;
M1 = bw_matrix_from_seed(seed1, 40);
M2 = bw_matrix_from_seed(seed2, 40);
assert(~isequal(M1, M2), 'Different seeds should produce different matrices');
fprintf('  PASS: Different seeds produce different results\n\n');

% Test 3: Grid Size Handling
fprintf('Test 3: Grid Size Handling...\n');
seed = 123456789;
for n = [20, 30, 40, 50]
    M = bw_matrix_from_seed(seed, n);
    assert(size(M, 1) == n && size(M, 2) == n, ...
           sprintf('Matrix should be %dx%d', n, n));
end
fprintf('  PASS: All grid sizes handled correctly\n\n');

% Test 4: Zero Seed Handling
fprintf('Test 4: Zero Seed Handling...\n');
M_zero = bw_matrix_from_seed(0, 40);
M_fallback = bw_matrix_from_seed(2463534242, 40);
assert(isequal(M_zero, M_fallback), 'Zero seed should use fallback value');
fprintf('  PASS: Zero seed handled correctly\n\n');

% Test 5: Data Type Verification
fprintf('Test 5: Data Type Verification...\n');
M = bw_matrix_from_seed(123456, 40);
assert(islogical(M), 'Matrix should be logical type');
assert(all(M(:) == 0 | M(:) == 1), 'Matrix should contain only 0 and 1');
fprintf('  PASS: Data types correct\n\n');

fprintf('=== ALL TESTS PASSED ===\n');
```

---

## Document Revision History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | Nov 2025 | Initial documentation | Research Team |

---

## Contact & Support

For questions about stimulus generation or this documentation:
- Review the source code in `TheNoiseGame/TheNoiseGameCore.swift`
- Check MATLAB functions in `TheNoiseGame/ANALYSIS/`
- Verify seed values in experiment log files

---

**End of Documentation**

