% run_generate_matrix.m
% Standalone script to generate black/white matrices
% Compatible with Swift implementation for reproducible matrix generation
%
% Run this script directly in MATLAB:
%   >> run_generate_matrix
%
% Or modify the seed and size variables below before running

% Configuration
n = 40;  % Matrix size (n×n)

% Generate random seed (or set a specific seed)
% Option 1: Random seed
seed = randi([1, intmax('uint32')], 1, 'uint32');
if seed == 0
    seed = uint32(2463534242);  % Fallback if zero
end

% Option 2: Use specific seed (uncomment and modify as needed)
% seed = uint32(123456789);

% Generate matrix using the SeedGenerator function
M = bw_matrix_from_seed(seed, n);

% Convert logical matrix to 0/1 integer matrix for CSV output
% (true = black = 1, false = white = 0)
matrix_int = double(M);

% Print seed
fprintf('seed=%u\n', seed);

% Print matrix row by row (comma-separated, matching Swift format)
for i = 1:n
    % Remove trailing comma for last element in row
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
writematrix(matrix_int, filename);

fprintf('\nMatrix saved to: %s\n', filename);

