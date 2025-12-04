function [composite, signal_mask] = apply_grating_to_noise(noise_frame, gabor_mask, contrast, seed)
% APPLY_GRATING_TO_NOISE Apply grating pattern to noise background
%
% Inputs:
%   noise_frame - Logical matrix (rows × cols) with base noise pattern
%                 true = black, false = white
%   gabor_mask - Matrix (rows × cols) with Gabor values (0.0 to 1.0)
%                Higher values indicate stronger signal presence
%   contrast - Grating contrast level (0.0 to 1.0)
%              Percentage of Gabor tiles that should show signal
%   seed - RNG seed for reproducible tile selection
%
% Outputs:
%   composite - Numeric matrix (rows × cols) with values:
%               0 = white background
%               1 = black background
%               2 = signal tile (grating/red in original)
%   signal_mask - Logical matrix indicating which tiles show signal
%
% This function replicates the Swift implementation from TheNoiseGameCore.swift
% lines 219-240 to ensure exact stimulus reconstruction.

    [rows, cols] = size(noise_frame);
    
    % Initialize composite with noise pattern
    % 0 = white, 1 = black
    composite = double(noise_frame);
    signal_mask = false(rows, cols);
    
    % If contrast is zero, return pure noise
    if contrast <= 0.0
        return;
    end
    
    % Clamp contrast to valid range
    contrast = max(0.0, min(1.0, contrast));
    
    % Collect all Gabor patch tiles (where mask > 0.01)
    gaborTiles = [];
    for row = 1:rows
        for col = 1:cols
            if gabor_mask(row, col) > 0.01
                gaborTiles = [gaborTiles; row, col]; %#ok<AGROW>
            end
        end
    end
    
    numGaborTiles = size(gaborTiles, 1);
    
    if numGaborTiles == 0
        warning('No Gabor tiles found in mask. Check mask generation.');
        return;
    end
    
    % Select percentage of Gabor tiles based on contrast
    numActiveGaborTiles = round(numGaborTiles * contrast);
    
    % Shuffle tiles using seeded RNG (matching Swift's shuffled(using:))
    % This ensures reproducible tile selection
    selectedIndices = seeded_shuffle(numGaborTiles, seed);
    selectedIndices = selectedIndices(1:numActiveGaborTiles);
    
    % Mark selected tiles as signal (value = 2)
    for i = 1:length(selectedIndices)
        idx = selectedIndices(i);
        row = gaborTiles(idx, 1);
        col = gaborTiles(idx, 2);
        composite(row, col) = 2;  % Signal tile
        signal_mask(row, col) = true;
    end
end


function shuffled_indices = seeded_shuffle(n, seed)
% SEEDED_SHUFFLE Shuffle indices using seeded RNG
%
% Inputs:
%   n - Number of indices to shuffle (1 to n)
%   seed - UInt64 seed value
%
% Output:
%   shuffled_indices - Permutation of 1:n
%
% Uses XorShift32 to match Swift's SeededRandomGenerator behavior

    % Initialize XorShift32 state
    x = uint32(mod(seed, 2^32));
    if x == 0
        x = uint32(2463534242);
    end
    
    % Fisher-Yates shuffle algorithm
    indices = (1:n)';
    
    for i = n:-1:2
        % Generate random number in range [1, i] using XorShift32
        x = xorshift32_next(x);
        % Convert to range [1, i]
        rand_idx = mod(double(x), i) + 1;
        
        % Swap
        temp = indices(i);
        indices(i) = indices(rand_idx);
        indices(rand_idx) = temp;
    end
    
    shuffled_indices = indices;
end


function x = xorshift32_next(x)
% XORSHIFT32_NEXT Generate next XorShift32 value
%
% Matches the Swift implementation for reproducibility

    x = bitxor(x, bitshift(x, 13, 'uint32'));
    x = bitxor(x, bitshift(x, -17, 'uint32'));
    x = bitxor(x, bitshift(x, 5, 'uint32'));
end

