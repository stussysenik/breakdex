## Why

The video trimmer handles display at incorrect positions because MinimalTrimmerView performs coordinate calculations with uninitialized state (startTime=0.0, endTime=0.0, videoDuration=0.0) instead of using the correct trim values from AddMoveViewModel (startTime=24.125s, endTime=34.125s, videoDuration=34.125s). This creates a state propagation failure where the ViewModel's correct trim values are not available during handle positioning calculations, violating iOS 18 coordinate space best practices and async AVFoundation loading patterns.

## What Changes

- Fix state initialization order in MinimalTrimmerView to use ViewModel trim values before handle positioning calculations
- Ensure async video duration loading completes before coordinate calculations (AVFoundation `load(.duration)`)
- Add minimal diagnostic logging to track trim value propagation and handle positioning verification
- Implement proper GeometryReader local coordinate space usage for timeline positioning
- Ensure mathematical consistency between trim time values and visual handle positions
- Maintain all existing functionality (minimum duration constraints, animations, user interactions)

## Impact

- **Affected specs**: video-trimming
- **Affected code**: MinimalTrimmerView.swift:562-568 (trim value inheritance timing), MinimalTrimmerView.swift:353,381 (handle positioning calculations), MinimalTrimmerView.swift:630-653 (async video duration loading)
- **Breaking changes**: None - internal implementation only, no API changes