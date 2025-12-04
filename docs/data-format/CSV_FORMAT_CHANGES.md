# CSV Export Format Changes

## Summary

The CSV export format has been simplified from 31 columns to 15 columns, with only 4 event types and a `stimulusOn` flag for easier data analysis.

## New Column Structure

1. **timestamp** - Unix timestamp (seconds since 1970)
2. **sessionTime** - Time since session start (seconds)
3. **trialTime** - Time since current trial start (seconds)
4. **eventType** - Simplified event type (only 4 types - see below)
5. **sessionId** - Session identifier
6. **trialIndex** - Trial number
7. **coherence** - Signal coherence (0.0 to 1.0)
8. **gratingContrast** - Grating contrast (0.0 to 1.0)
9. **quadrant** - Stimulus location (top_left, top_right, bottom_left, bottom_right)
10. **frameNumber** - Sequential frame number (for reconstruction)
11. **seed** - RNG seed for noise pattern reconstruction
12. **stimulusOn** - Whether stimulus is visible (true/false)
13. **response** - Response type or behavioral outcome
14. **reactionTime** - Time from stimulus onset to response (seconds)
15. **withinRTWindow** - Whether event timestamp is within reaction time window (true/false)

## Simplified Event Types (Only 4!)

1. **trial_start** - Beginning of trial (trialTime = 0.000)
2. **frame** - Frame update with seed for reconstruction and stimulusOn flag
3. **response** - User click/tap detected
4. **trial_end** - Trial complete with behavioral outcome in response column

## The stimulusOn Column

The **stimulusOn** column replaces multiple event types with a simple boolean flag:
- `true` = Stimulus is visible on screen (coherent pattern showing)
- `false` = No stimulus (cue period, fixation, inter-trial interval)

This eliminates the need for separate events like:
- ❌ `cue_on` 
- ❌ `awaiting_stim`
- ❌ `stim_on_before_window`
- ❌ `stim_on_in_window`

All stimulus state is now captured in frame events with the stimulusOn flag!

## The withinRTWindow Column

The **withinRTWindow** column indicates whether each event's timestamp falls within the valid reaction time window:
- `true` = Event timestamp is within the RT window (valid response period)
- `false` = Event timestamp is outside the RT window

The RT window is calculated as:
- **Start**: `stimulus_onset + rtWindowDelay`
- **End**: `stimulus_onset + rtWindowDelay + rtWindowLength`

This column helps identify:
- Which responses were within the valid window (hits vs. false alarms)
- Which frames were shown during the response window
- Temporal alignment of events relative to the valid response period

## Removed Event Types

These events are no longer logged to simplify analysis:
- session_start/end (captured in header metadata)
- drawScreensStart (internal timing)
- state_change (replaced by specific events like cue_on, awaiting_stim)
- trialParams (merged into trial_start)
- noiseStimulusOnRequested/gratingStimulusOnRequested (too granular)
- staticStimulusCueOn (replaced by cue_on)
- gratingOn (replaced by stim_on_before_window/stim_on_in_window)
- detection (renamed to response)
- eot (merged into trial_end)
- grid_update (seed now in frame events)
- click (replaced by response)
- sequence_complete (can be inferred from trial data)

## Behavioral Outcomes

In `trial_end` events, the **response** column contains:
- **hit** - Correct detection
- **miss** - No response when stimulus present  
- **false_alarm** - Response when no stimulus present

## Example CSV Output

```csv
timestamp,sessionTime,trialTime,eventType,sessionId,trialIndex,coherence,gratingContrast,quadrant,frameNumber,seed,stimulusOn,response,reactionTime,withinRTWindow
1762709660.187,0.318,0.000,trial_start,d_user_fu,0,1.0,0.0,bottom_right,,,false,,,false
1762709660.366,0.497,0.179,frame,d_user_fu,0,1.0,0.0,bottom_right,1,11869166363206867677,false,,,false
1762709660.516,0.647,0.329,frame,d_user_fu,0,1.0,0.0,bottom_right,2,10464189351720987098,false,,,false
1762709660.731,0.862,0.544,frame,d_user_fu,0,1.0,0.0,bottom_right,3,10287774259817670278,false,,,false
1762709660.799,0.930,0.612,frame,d_user_fu,0,1.0,0.0,bottom_right,4,829849739702490798,false,,,false
1762709661.301,1.432,1.114,frame,d_user_fu,0,1.0,0.0,bottom_right,8,9919505164113378147,false,,,false
1762709661.458,1.589,1.271,frame,d_user_fu,0,1.0,0.0,bottom_right,9,15632122565370968639,false,,,false
1762709662.657,2.788,2.470,frame,d_user_fu,0,1.0,0.0,bottom_right,18,14589345927856789234,true,,,true
1762709662.788,2.919,2.601,frame,d_user_fu,0,1.0,0.0,bottom_right,19,3456789012345678901,true,,,true
1762709663.124,3.255,2.937,response,d_user_fu,,,,,,,,,true
1762709665.234,5.365,5.047,trial_end,d_user_fu,0,1.0,0.0,bottom_right,,,false,hit,0.583,false
```

### Key Points in This Example:
- All frames have `stimulusOn` flag (false during cue/fixation, true when stimulus showing)
- Only 4 event types: trial_start, frame, response, trial_end
- Frame 18-19 have `stimulusOn=true` indicating stimulus is visible
- Frames 18-19 also have `withinRTWindow=true` showing they're in the valid response period
- The response has `withinRTWindow=true` indicating it was a valid hit
- Much easier to filter: `eventType=='frame' & stimulusOn==true` gets all stimulus frames

## Header Metadata

The CSV file includes header comments with trial settings:
```
# TRIAL_SETTINGS
# cueDuration: 0.5
# minGratingOnset: 1.0
# maxGratingOnset: 8.0
# ...
```

## Benefits

1. **Minimal columns** (15 vs 31) - easier to work with in R/Python/Excel
2. **Only 4 event types** - dramatically simplified from 15+ event types
3. **stimulusOn flag** - clear boolean indicator of stimulus state (no ambiguity)
4. **withinRTWindow flag** - easy identification of valid response periods and timing
5. **Trial time** - easy to align events within a trial
6. **Full reconstruction** - all frames include seeds for MATLAB stimulus reconstruction
7. **Analysis-ready** - behavioral outcomes clearly labeled (hit/miss/false_alarm)

## Analysis Examples

### Get all frames when stimulus was visible:
```python
stimulus_frames = df[(df['eventType'] == 'frame') & (df['stimulusOn'] == 'true')]
```

### Get all frames within the reaction time window:
```python
rt_window_frames = df[(df['eventType'] == 'frame') & (df['withinRTWindow'] == 'true')]
```

### Filter responses that were within the valid RT window:
```python
valid_responses = df[(df['eventType'] == 'response') & (df['withinRTWindow'] == 'true')]
invalid_responses = df[(df['eventType'] == 'response') & (df['withinRTWindow'] == 'false')]
```

### Count responses during stimulus presentation:
```python
stim_times = df[df['stimulusOn'] == 'true']
responses = df[df['eventType'] == 'response']
# Match responses to stimulus windows...
```

### Calculate RT distribution for hits:
```python
hits = df[(df['eventType'] == 'trial_end') & (df['response'] == 'hit')]
rt_distribution = hits['reactionTime'].hist()
```

### Analyze response timing relative to RT window:
```python
# Compare responses inside vs outside RT window
responses_in_window = df[(df['eventType'] == 'response') & (df['withinRTWindow'] == 'true')].shape[0]
responses_out_window = df[(df['eventType'] == 'response') & (df['withinRTWindow'] == 'false')].shape[0]
print(f"Valid responses: {responses_in_window}, Invalid: {responses_out_window}")
```

## Migration Notes

- All existing logging methods preserved for backward compatibility
- Methods that are no longer needed are kept but do nothing (to avoid breaking existing calls)
- The LogEntry structure is still available but most logging now writes directly to CSV

