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
