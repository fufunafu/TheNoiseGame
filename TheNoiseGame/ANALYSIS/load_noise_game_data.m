function session_data = load_noise_game_data(filepath)
% LOAD_NOISE_GAME_DATA Parse Noise Game CSV export file
%
% Input:
%   filepath - Path to CSV export file
%
% Output:
%   session_data - Structure containing:
%     .metadata - Session info and trial settings
%     .trials - Array of trial structures with:
%         .trial_index
%         .coherence
%         .contrast
%         .quadrant
%         .outcome ('hit', 'miss', 'false_alarm', 'correct_reject')
%         .reaction_time
%         .within_rt_window
%         .frames - Array of frame structures with seeds
%         .responses - Response events during trial
%     .all_events - Complete event table
%     .summary - Quick summary statistics

    fprintf('Loading data from: %s\n', filepath);
    
    % Parse metadata from header
    addpath(fullfile(fileparts(mfilename('fullpath')), 'utils'));
    [metadata, data_start_line] = parse_csv_header(filepath);
    
    % Parse grid size
    if isfield(metadata.trial_settings, 'gridSize')
        grid_str = metadata.trial_settings.gridSize;
        grid_parts = strsplit(grid_str, 'x');
        metadata.grid_cols = str2double(grid_parts{1});
        metadata.grid_rows = str2double(grid_parts{2});
    else
        warning('Grid size not found in metadata, using default 64x48');
        metadata.grid_cols = 64;
        metadata.grid_rows = 48;
    end
    
    % Parse contrast levels
    if isfield(metadata.trial_settings, 'gratingContrasts')
        contrast_str = metadata.trial_settings.gratingContrasts;
        metadata.contrast_levels = str2num(contrast_str); %#ok<ST2NM>
    else
        metadata.contrast_levels = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 1.0];
    end
    
    % Read data section
    opts = detectImportOptions(filepath, 'NumHeaderLines', data_start_line - 1);
    data_table = readtable(filepath, opts);
    
    fprintf('Loaded %d events from file\n', height(data_table));
    
    % Separate event types
    trial_start_events = data_table(strcmp(data_table.eventType, 'trial_start'), :);
    trial_end_events = data_table(strcmp(data_table.eventType, 'trial_end'), :);
    frame_events = data_table(strcmp(data_table.eventType, 'frame'), :);
    response_events = data_table(strcmp(data_table.eventType, 'response'), :);
    
    % Get unique trial indices
    trial_indices = unique(trial_start_events.trialIndex);
    num_trials = length(trial_indices);
    
    fprintf('Found %d trials\n', num_trials);
    
    % Initialize trials array
    trials = struct();
    
    % Process each trial
    for i = 1:num_trials
        trial_idx = trial_indices(i);
        
        % Get trial start event
        trial_start = trial_start_events(trial_start_events.trialIndex == trial_idx, :);
        if isempty(trial_start)
            warning('No trial_start event for trial %d', trial_idx);
            continue;
        end
        trial_start = trial_start(1, :); % Take first if multiple
        
        % Get trial end event
        trial_end = trial_end_events(trial_end_events.trialIndex == trial_idx, :);
        if isempty(trial_end)
            warning('No trial_end event for trial %d', trial_idx);
            outcome = 'incomplete';
            reaction_time = NaN;
            within_rt_window = false;
        else
            trial_end = trial_end(1, :);
            outcome = char(trial_end.response);
            if strcmp(outcome, 'false')
                outcome = 'no_response';
            end
            reaction_time = trial_end.reactionTime;
            within_rt_window = trial_end.withinRTWindow;
        end
        
        % Get frames for this trial
        trial_frames = frame_events(frame_events.trialIndex == trial_idx, :);
        
        % Get responses during trial (between trial_start and trial_end time)
        trial_start_time = trial_start.timestamp;
        if ~isempty(trial_end)
            trial_end_time = trial_end.timestamp;
            trial_responses = response_events(...
                response_events.timestamp >= trial_start_time & ...
                response_events.timestamp <= trial_end_time, :);
        else
            trial_responses = [];
        end
        
        % Build trial structure
        trials(i).trial_index = trial_idx;
        trials(i).coherence = trial_start.coherence;
        trials(i).contrast = trial_start.gratingContrast;
        trials(i).quadrant = char(trial_start.quadrant);
        trials(i).outcome = outcome;
        trials(i).reaction_time = reaction_time;
        trials(i).within_rt_window = within_rt_window;
        trials(i).start_time = trial_start_time;
        if ~isempty(trial_end)
            trials(i).end_time = trial_end_time;
            trials(i).duration = trial_end.trialTime;
        else
            trials(i).end_time = NaN;
            trials(i).duration = NaN;
        end
        trials(i).num_frames = height(trial_frames);
        
        % Store frame information
        trials(i).frames = struct();
        for f = 1:height(trial_frames)
            trials(i).frames(f).frame_number = trial_frames.frameNumber(f);
            trials(i).frames(f).seed = trial_frames.seed(f);
            trials(i).frames(f).timestamp = trial_frames.timestamp(f);
            trials(i).frames(f).trial_time = trial_frames.trialTime(f);
            trials(i).frames(f).stimulus_on = trial_frames.stimulusOn(f);
        end
        
        % Store response information
        trials(i).responses = trial_responses;
    end
    
    % Calculate summary statistics
    summary = struct();
    summary.num_trials = num_trials;
    summary.total_frames = height(frame_events);
    
    % Count outcomes
    outcomes = {trials.outcome};
    summary.num_hits = sum(strcmp(outcomes, 'hit'));
    summary.num_misses = sum(strcmp(outcomes, 'miss'));
    summary.num_false_alarms = sum(strcmp(outcomes, 'false_alarm'));
    summary.num_correct_rejects = sum(strcmp(outcomes, 'correct_reject'));
    summary.num_incomplete = sum(strcmp(outcomes, 'incomplete'));
    summary.num_no_response = sum(strcmp(outcomes, 'no_response'));
    
    % Calculate overall performance
    if summary.num_hits + summary.num_misses > 0
        summary.hit_rate = summary.num_hits / (summary.num_hits + summary.num_misses);
    else
        summary.hit_rate = NaN;
    end
    
    % Mean reaction time (only for valid responses)
    valid_rts = [];
    for i = 1:length(trials)
        rt = trials(i).reaction_time;
        if ~isempty(rt) && isnumeric(rt) && ~isnan(rt) && rt > 0
            valid_rts = [valid_rts, rt]; %#ok<AGROW>
        end
    end
    if ~isempty(valid_rts)
        summary.mean_rt = mean(valid_rts);
        summary.median_rt = median(valid_rts);
        summary.std_rt = std(valid_rts);
    else
        summary.mean_rt = NaN;
        summary.median_rt = NaN;
        summary.std_rt = NaN;
    end
    
    % Extract session ID from data if not in metadata
    if ~isfield(metadata, 'session_info') || ~isfield(metadata.session_info, 'sessionId')
        % Extract sessionId from the data table
        if ~isempty(data_table) && ismember('sessionId', data_table.Properties.VariableNames)
            unique_session_ids = unique(data_table.sessionId);
            if ~isempty(unique_session_ids)
                if ~isfield(metadata, 'session_info')
                    metadata.session_info = struct();
                end
                metadata.session_info.sessionId = char(unique_session_ids{1});
            end
        end
    end
    
    % Extract subject name if available
    if ~isfield(metadata, 'session_info') || ~isfield(metadata.session_info, 'subjectName')
        if isfield(metadata, 'session_info') && isfield(metadata.session_info, 'sessionId')
            % Try to extract subject from session ID (format: d_user_fu)
            session_parts = strsplit(metadata.session_info.sessionId, '_');
            if length(session_parts) >= 2
                metadata.session_info.subjectName = strjoin(session_parts(2:end), '_');
            else
                metadata.session_info.subjectName = 'Unknown';
            end
        else
            if ~isfield(metadata, 'session_info')
                metadata.session_info = struct();
            end
            metadata.session_info.subjectName = 'Unknown';
        end
    end
    
    % Build output structure
    session_data = struct();
    session_data.metadata = metadata;
    session_data.trials = trials;
    session_data.all_events = data_table;
    session_data.summary = summary;
    session_data.filepath = filepath;
    
    % Extract session info from data if not in metadata
    if ~isfield(metadata, 'session_info') || isempty(fieldnames(metadata.session_info))
        % Get session info from first data row
        if height(data_table) > 0
            metadata.session_info.sessionId = char(data_table.sessionId(1));
            % Try to parse subject name from sessionId (format: experiment_user_subject)
            parts = strsplit(metadata.session_info.sessionId, '_');
            if length(parts) >= 3
                metadata.session_info.subjectName = parts{end};
            else
                metadata.session_info.subjectName = 'unknown';
            end
            metadata.session_info.sessionStartTime = 'unknown';
        else
            metadata.session_info.sessionId = 'unknown';
            metadata.session_info.subjectName = 'unknown';
            metadata.session_info.sessionStartTime = 'unknown';
        end
    end
    
    % Print summary
    fprintf('\n=== Session Summary ===\n');
    fprintf('Session ID: %s\n', metadata.session_info.sessionId);
    fprintf('Subject: %s\n', metadata.session_info.subjectName);
    fprintf('Trials: %d\n', summary.num_trials);
    fprintf('Hits: %d, Misses: %d\n', summary.num_hits, summary.num_misses);
    fprintf('Hit Rate: %.2f%%\n', summary.hit_rate * 100);
    if ~isnan(summary.mean_rt)
        fprintf('Mean RT: %.3f s (SD = %.3f s)\n', summary.mean_rt, summary.std_rt);
    end
    fprintf('Grid Size: %d x %d\n', metadata.grid_cols, metadata.grid_rows);
    fprintf('Contrast Levels: %s\n', mat2str(metadata.contrast_levels));
    fprintf('======================\n\n');
end

