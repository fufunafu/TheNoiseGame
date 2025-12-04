function mask = generate_gabor_mask(rows, cols, quadrant)
% GENERATE_GABOR_MASK Generate Gabor patch mask for a specific quadrant
%
% Inputs:
%   rows - Number of rows in checkerboard grid
%   cols - Number of columns in checkerboard grid
%   quadrant - Quadrant position: 'top_left', 'top_right', 'bottom_left', 'bottom_right'
%
% Output:
%   mask - Matrix (rows × cols) with Gabor values (0.0 to 1.0)
%          Higher values indicate stronger signal presence
%
% This function replicates the Swift implementation from TheNoiseGameCore.swift
% lines 339-393 to ensure exact stimulus reconstruction.

    % Gabor parameters (matching Swift StimulusParams)
    gaborWidth = 1.0;          % Half-width (1 = 2 squares total width)
    gaborHeight = 3.5;         % Half-height (3.5 = 7 squares total height)
    gaborSigmaX = 0.5;         % Gaussian std dev in X (tighter for narrow columns)
    gaborSigmaY = 2.0;         % Gaussian std dev in Y (for tall columns)
    gaborOrientation = 0.0;    % Orientation in radians (0 = vertical)
    
    % Initialize mask with zeros
    mask = zeros(rows, cols);
    
    % Calculate Gabor centers for the specified quadrant
    centers = calculate_gabor_centers(rows, cols, quadrant);
    
    if isempty(centers)
        warning('Invalid quadrant: %s. Using top_left.', quadrant);
        centers = calculate_gabor_centers(rows, cols, 'top_left');
    end
    
    % Generate Gaussian envelope for each of the 3 columns
    gaborTileCount = 0;
    for c = 1:size(centers, 1)
        centerX = centers(c, 1);
        centerY = centers(c, 2);
        
        for row = 1:rows
            for col = 1:cols
                % Calculate distance from center
                dx = col - centerX;
                dy = row - centerY;
                
                % Rotate coordinates based on orientation
                x_rot = dx * cos(gaborOrientation) + dy * sin(gaborOrientation);
                y_rot = -dx * sin(gaborOrientation) + dy * cos(gaborOrientation);
                
                % Only compute Gabor within rectangular bounds
                if abs(x_rot) <= gaborWidth && abs(y_rot) <= gaborHeight
                    gaborTileCount = gaborTileCount + 1;
                    
                    % Compute Gaussian envelope (no sinusoidal grating)
                    % This creates solid columns instead of striped patterns
                    gaussianX = exp(-(x_rot * x_rot) / (2.0 * gaborSigmaX * gaborSigmaX));
                    gaussianY = exp(-(y_rot * y_rot) / (2.0 * gaborSigmaY * gaborSigmaY));
                    gaussian = gaussianX * gaussianY;
                    
                    % Clamp to [0, 1]
                    normalizedGabor = max(0.0, min(1.0, gaussian));
                    
                    % Take maximum if multiple Gabors overlap
                    mask(row, col) = max(mask(row, col), normalizedGabor);
                end
            end
        end
    end
    
    % Report statistics (optional, for validation)
    if nargout == 0 || nargout > 1
        fprintf('📊 Gabor Mask Generated:\n');
        fprintf('   Grid: %d×%d\n', cols, rows);
        fprintf('   Quadrant: %s\n', quadrant);
        fprintf('   Centers: ');
        for c = 1:size(centers, 1)
            fprintf('(%d,%d) ', centers(c,1), centers(c,2));
        end
        fprintf('\n');
        fprintf('   Total Gabor tiles: %d\n', gaborTileCount);
        fprintf('   Max Gabor value: %.4f\n', max(mask(:)));
    end
end


function centers = calculate_gabor_centers(rows, cols, quadrant)
% CALCULATE_GABOR_CENTERS Calculate center positions for 3 Gabor columns
%
% Replicates Swift gaborCenters() from TheNoiseGameModels.swift lines 363-396
%
% Returns: Nx2 matrix where each row is [x_center, y_center]
%          (using 1-based MATLAB indexing)

    centerX = cols / 2;
    centerY = rows / 2;
    
    % Determine quadrant offset
    % Each quadrant center is at 1/4 and 3/4 of grid dimensions
    switch lower(quadrant)
        case 'top_left'
            quadrantOffsetX = -cols / 4;
            quadrantOffsetY = -rows / 4;
        case 'top_right'
            quadrantOffsetX = cols / 4;
            quadrantOffsetY = -rows / 4;
        case 'bottom_left'
            quadrantOffsetX = -cols / 4;
            quadrantOffsetY = rows / 4;
        case 'bottom_right'
            quadrantOffsetX = cols / 4;
            quadrantOffsetY = rows / 4;
        otherwise
            warning('Unknown quadrant: %s', quadrant);
            centers = [];
            return;
    end
    
    % Calculate quadrant center
    quadrantCenterX = centerX + quadrantOffsetX;
    quadrantCenterY = centerY + quadrantOffsetY;
    
    % Position three columns around the quadrant center
    % Note: MATLAB uses 1-based indexing, but the offsets are relative
    centers = [
        quadrantCenterX - 4, quadrantCenterY;  % Left column
        quadrantCenterX,     quadrantCenterY;  % Center column
        quadrantCenterX + 4, quadrantCenterY   % Right column
    ];
end

