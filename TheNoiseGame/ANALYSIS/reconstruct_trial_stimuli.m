function [stimulus_sequence, frame_info, full_stimulus] = reconstruct_trial_stimuli(trial_data, grid_rows, grid_cols, options)
% RECONSTRUCT_TRIAL_STIMULI Reconstruct visual stimuli from seed values
%
% Inputs:
%   trial_data - Trial structure from load_noise_game_data
%   grid_rows - Number of rows in checkerboard (default: 48)
%   grid_cols - Number of columns in checkerboard (default: 64)
%   options - Optional structure with fields:
%       .frame_indices - Specific frames to reconstruct (default: all)
%       .verbose - Display progress (default: false)
%       .include_grating - Reconstruct full stimulus with grating (default: false)
%
% Outputs:
%   stimulus_sequence - 3D logical array (rows × cols × frames)
%                       Background noise only: true = black, false = white
%   frame_info - Structure array with metadata for each frame
%   full_stimulus - 3D array (rows × cols × frames) with full stimulus
%                   0 = white, 1 = black, 2 = signal/grating tile
%                   Only returned if options.include_grating is true

    % Handle default arguments
    if nargin < 2 || isempty(grid_rows)
        grid_rows = 48;
    end
    if nargin < 3 || isempty(grid_cols)
        grid_cols = 64;
    end
    if nargin < 4
        options = struct();
    end
    
    % Parse options
    if ~isfield(options, 'frame_indices') || isempty(options.frame_indices)
        frame_indices = 1:trial_data.num_frames;
    else
        frame_indices = options.frame_indices;
    end
    
    if ~isfield(options, 'verbose')
        options.verbose = false;
    end
    
    if ~isfield(options, 'include_grating')
        options.include_grating = false;
    end
    
    num_frames_to_reconstruct = length(frame_indices);
    
    if options.verbose
        fprintf('Reconstructing %d frames for trial %d...\n', ...
                num_frames_to_reconstruct, trial_data.trial_index);
        if options.include_grating
            fprintf('  Including grating pattern (contrast = %.2f)\n', trial_data.contrast);
        end
    end
    
    % Pre-allocate stimulus arrays
    stimulus_sequence = false(grid_rows, grid_cols, num_frames_to_reconstruct);
    full_stimulus = [];
    frame_info = struct();
    
    % Generate Gabor mask if including grating
    gabor_mask = [];
    if options.include_grating
        gabor_mask = generate_gabor_mask(grid_rows, grid_cols, trial_data.quadrant);
        full_stimulus = zeros(grid_rows, grid_cols, num_frames_to_reconstruct);
        
        if options.verbose
            fprintf('  Generated Gabor mask for quadrant: %s\n', trial_data.quadrant);
        end
    end
    
    % Reconstruct each frame
    for i = 1:num_frames_to_reconstruct
        frame_idx = frame_indices(i);
        
        % Get seed for this frame
        seed = trial_data.frames(frame_idx).seed;
        stimulus_on_raw = trial_data.frames(frame_idx).stimulus_on;
        
        % Handle both logical and string types for stimulus_on
        if ischar(stimulus_on_raw) || iscell(stimulus_on_raw)
            stimulus_on = strcmpi(stimulus_on_raw, 'true');
        else
            stimulus_on = logical(stimulus_on_raw);
        end
        
        % Generate checkerboard using seed
        % Note: bw_matrix_from_seed expects (rows, cols) format
        frame_matrix = bw_matrix_from_seed_rect(seed, grid_rows, grid_cols);
        
        % Store noise-only sequence
        stimulus_sequence(:, :, i) = frame_matrix;
        
        % Apply grating if requested and stimulus is on
        if options.include_grating
            if stimulus_on
                % Apply grating pattern to create full stimulus
                [composite, ~] = apply_grating_to_noise(...
                    frame_matrix, gabor_mask, trial_data.contrast, seed);
                full_stimulus(:, :, i) = composite;
            else
                % Stimulus off - just store the noise
                full_stimulus(:, :, i) = double(frame_matrix);
            end
        end
        
        % Store frame metadata
        frame_info(i).frame_number = trial_data.frames(frame_idx).frame_number;
        frame_info(i).seed = seed;
        frame_info(i).timestamp = trial_data.frames(frame_idx).timestamp;
        frame_info(i).trial_time = trial_data.frames(frame_idx).trial_time;
        frame_info(i).stimulus_on = stimulus_on;
        
        % Progress indicator for long sequences
        if options.verbose && mod(i, 100) == 0
            fprintf('  Processed %d/%d frames\n', i, num_frames_to_reconstruct);
        end
    end
    
    if options.verbose
        fprintf('Reconstruction complete!\n');
    end
end


function M = bw_matrix_from_seed_rect(seed, rows, cols)
% BW_MATRIX_FROM_SEED_RECT Generate rectangular checkerboard from seed
%
% This is an extension of the square bw_matrix_from_seed function
% to handle rectangular grids (rows × cols)
%
% Inputs:
%   seed - UInt64 seed value
%   rows - Number of rows
%   cols - Number of columns
%
% Output:
%   M - Logical matrix (rows × cols) where true = black

    % Convert seed to uint32 (XorShift32 uses 32-bit)
    x = uint32(mod(seed, 2^32));
    
    % Handle zero seed (invalid for XorShift)
    if x == 0
        x = uint32(2463534242);
    end
    
    % Pre-allocate matrix
    M = false(rows, cols);
    
    % Generate matrix in row-major order (same as Swift implementation)
    for i = 1:rows
        for j = 1:cols
            % XorShift32 next() implementation
            x = bitxor(x, bitshift(x, 13, 'uint32'));
            x = bitxor(x, bitshift(x, -17, 'uint32'));
            x = bitxor(x, bitshift(x, 5, 'uint32'));
            
            % Test top bit to get boolean
            M(i, j) = bitand(x, uint32(hex2dec('80000000'))) ~= 0;
        end
    end
end

