## Why
The current video trimming system loses loaded video assets when users navigate between tabs, background/foreground the app, or tap the cancel button. This creates a poor user experience where videos must be reloaded from scratch, causing unnecessary network usage and delays.

## What Changes
- Add simple workflow state persistence to AddMoveViewModel for tab navigation and app lifecycle events
- Implement proper cancel functionality that completely resets to initial "select a clip" state
- Add lifecycle observers for app backgrounding/foregrounding to preserve video state
- Support large video files (up to 30 minutes) with progressive loading for iCloud and local videos
- Add 30-minute video duration validation with user-friendly error messages
- Add minimal diagnostic logging for debugging state transitions
- Enhance AddMoveView navigation logic for quick return detection (< 5 seconds)
- Update cancelTrimming() method in MinimalTrimmerView for complete workflow reset

## Impact
- **Affected specs**: video-state, add-move-workflow
- **Affected code**: AddMoveView.swift, AddMoveViewModel.swift, MinimalTrimmerView.swift
- **User impact**: Seamless video trimming experience across navigation and app lifecycle events
- **Performance impact**: Reduced video reloading, better memory management for large files
- **Code quality impact**: Minimal changes to preserve existing excellent architecture