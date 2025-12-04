function [metadata, data_start_line] = parse_csv_header(filepath)
% PARSE_CSV_HEADER Parse metadata from Noise Game CSV export file
%
% Inputs:
%   filepath - Path to CSV file with metadata headers
%
% Outputs:
%   metadata - Structure containing parsed metadata fields
%   data_start_line - Line number where actual data begins
%
% The CSV file format includes:
%   - SESSION_INFO section with session metadata
%   - TRIAL_SETTINGS section with experimental parameters
%   - Data rows starting after the header sections

    % Initialize metadata structure
    metadata = struct();
    metadata.session_info = struct();
    metadata.trial_settings = struct();
    
    % Read file line by line
    fid = fopen(filepath, 'r');
    if fid == -1
        error('Could not open file: %s', filepath);
    end
    
    line_num = 0;
    current_section = '';
    
    while ~feof(fid)
        line = fgetl(fid);
        line_num = line_num + 1;
        
        % Skip empty lines
        if isempty(strtrim(line))
            continue;
        end
        
        % Check if it's a header line
        if startsWith(line, '#')
            % Remove leading '# '
            content = strtrim(line(2:end));
            
            % Check for section headers
            if strcmp(content, 'SESSION_INFO')
                current_section = 'session_info';
                continue;
            elseif strcmp(content, 'TRIAL_SETTINGS')
                current_section = 'trial_settings';
                continue;
            elseif isempty(content)
                continue;
            end
            
            % Parse key-value pairs
            if contains(content, ':')
                % Find first colon and split manually for compatibility
                colon_idx = strfind(content, ':');
                if ~isempty(colon_idx)
                    key = strtrim(content(1:colon_idx(1)-1));
                    value = strtrim(content(colon_idx(1)+1:end));
                else
                    continue;
                end
                
                % Convert to valid field name
                field_name = matlab.lang.makeValidName(key);
                
                % Try to parse as number, otherwise keep as string
                num_value = str2double(value);
                if ~isnan(num_value)
                    parsed_value = num_value;
                elseif strcmpi(value, 'true')
                    parsed_value = true;
                elseif strcmpi(value, 'false')
                    parsed_value = false;
                else
                    parsed_value = value;
                end
                
                % Store in appropriate section
                if ~isempty(current_section)
                    metadata.(current_section).(field_name) = parsed_value;
                end
            end
        else
            % Non-header line - data begins here
            data_start_line = line_num;
            fclose(fid);
            return;
        end
    end
    
    fclose(fid);
    error('No data section found in file');
end

