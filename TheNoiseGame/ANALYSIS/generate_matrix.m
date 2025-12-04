% generate_matrix.m
% Script to generate black/white matrices using XorShift32 RNG
% Compatible with Swift implementation for reproducible matrix generation
%
% Usage:
%   generate_matrix              % Generate one matrix with random seed
%   generate_matrix(seed)        % Generate matrix with specific seed
%   generate_matrix(seed, n)     % Generate n×n matrix with specific seed
%   generate_matrix([], n)       % Generate n×n matrix with random seed
%
% Output:
%   - Prints seed and matrix to console
%   - Saves matrix to CSV file: bw_<seed>.csv

function generate_matrix(seed, n)
    % Default parameters
    if nargin < 2
        n = 40;  % Default matrix size
    end
    
    if nargin < 1 || isempty(seed)
        % Generate random seed (similar to Swift's XorShift32.generateSeed())
        seed = randi([1, intmax('uint32')], 1, 'uint32');
        if seed == 0
            seed = uint32(2463534242);  % Fallback if zero
        end
    end
    
    % Convert seed to uint32
    seed = uint32(seed);
    
    % Generate matrix using the SeedGenerator function
    M = bw_matrix_from_seed(seed, n);
    
    % Convert logical matrix to 0/1 integer matrix for CSV output
    % (true = black = 1, false = white = 0)
    matrix_int = double(M);
    
    % Print seed
    fprintf('seed=%u\n', seed);
    
    % Print matrix row by row (comma-separated, matching Swift format)
    for i = 1:n
        row_str = '';
        for j = 1:n
            if j < n
                row_str = [row_str, num2str(matrix_int(i, j)), ','];
            else
                row_str = [row_str, num2str(matrix_int(i, j))];
            end
        end
        fprintf('%s\n', row_str);
    end
    
    % Save to CSV file (matching Swift output format)
    filename = sprintf('bw_%u.csv', seed);
    
    % Write CSV file
    writematrix(matrix_int, filename);
    
    fprintf('Matrix saved to: %s\n', filename);
    
    % Return matrix if called as function, otherwise just display
    if nargout > 0
        varargout{1} = matrix_int;
        if nargout > 1
            varargout{2} = seed;
        end
    end
end

