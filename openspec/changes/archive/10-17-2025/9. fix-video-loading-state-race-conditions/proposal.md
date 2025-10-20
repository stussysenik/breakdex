## Why
Video loading fails on subsequent attempts with UI stuck at 10% due to competing state management paradigms between direct state setting and reactive observation in AddMoveViewModel.

## What Changes
- **BREAKING**: Remove manual state setting in AddMoveViewModel.handleVideoLoaded()
- Unify state management under single reactive paradigm using RobustVideoLoader observation
- Add state coordination guard to prevent race conditions during video loading
- Ensure proper async boundary handling for SharedVideoPlayer initialization
- Add comprehensive logging for state transition debugging

## Impact
- Affected specs: video-loading (new capability)
- Affected code: AddMoveViewModel.swift:163-218 (handleVideoLoaded method), state observation logic
- Fixes: Second video load stuck at 10%, race condition between state management approaches