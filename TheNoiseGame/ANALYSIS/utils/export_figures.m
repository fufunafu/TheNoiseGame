function export_figures(fig_handle, output_path, formats)
% EXPORT_FIGURES Export figure to multiple formats
%
% Inputs:
%   fig_handle - Figure handle to export
%   output_path - Base path (without extension) for output files
%   formats - Cell array of formats: {'png', 'pdf', 'eps', 'fig'}
%             Default: {'png', 'pdf'}
%
% Example:
%   export_figures(gcf, 'results/figure1', {'png', 'pdf', 'eps'});

    if nargin < 3
        formats = {'png', 'pdf'};
    end
    
    % Create output directory if it doesn't exist
    [output_dir, ~, ~] = fileparts(output_path);
    if ~isempty(output_dir) && ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % Set figure properties for high-quality output
    set(fig_handle, 'PaperPositionMode', 'auto');
    set(fig_handle, 'Color', 'w');
    
    % Export to each requested format
    for i = 1:length(formats)
        format = lower(formats{i});
        output_file = [output_path '.' format];
        
        try
            switch format
                case 'png'
                    print(fig_handle, output_file, '-dpng', '-r300');
                    fprintf('Saved: %s\n', output_file);
                    
                case 'pdf'
                    print(fig_handle, output_file, '-dpdf', '-bestfit');
                    fprintf('Saved: %s\n', output_file);
                    
                case 'eps'
                    print(fig_handle, output_file, '-depsc', '-tiff');
                    fprintf('Saved: %s\n', output_file);
                    
                case 'svg'
                    print(fig_handle, output_file, '-dsvg');
                    fprintf('Saved: %s\n', output_file);
                    
                case 'fig'
                    savefig(fig_handle, output_file);
                    fprintf('Saved: %s\n', output_file);
                    
                case 'jpg'
                    print(fig_handle, output_file, '-djpeg', '-r300');
                    fprintf('Saved: %s\n', output_file);
                    
                otherwise
                    warning('Unknown format: %s', format);
            end
        catch ME
            warning('Failed to export figure to %s: %s', format, ME.message);
        end
    end
end

