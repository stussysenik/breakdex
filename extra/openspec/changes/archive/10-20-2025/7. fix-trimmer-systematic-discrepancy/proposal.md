## Why
The video trimmer exhibits a systematic discrepancy where handles appear positioned incorrectly: the start handle defaults to 24.125s (last 10 seconds) instead of 00:00:00, and the end handle extends beyond the timeline bounds. This creates a broken user experience where trim handles don't align with their intended time positions.

## What Changes
- Fix AddMoveViewModel logic to default trim start to 0.0s instead of last 10 seconds
- Fix MinimalTrimmerView coordinate math to account for handle width (20px) when positioning handles
- Update timeToCoordinate and coordinateToTime functions to keep handles within timeline bounds
- Maintain all existing functionality (minimum duration, animations, haptic feedback)

## Impact
- Affected specs: video-trimming (new capability)
- Affected code:
  - Features/AddMove/ViewModels/AddMoveViewModel.swift:493-494 (trim initialization logic)
  - Features/Shared/Video/MinimalTrimmerView.swift:780-813 (coordinate conversion functions)
- **BREAKING**: Changes default trim behavior to start at video beginning instead of last 10 seconds