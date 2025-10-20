## Why
The complete-migration-cleanup spec has introduced 70+ compilation errors across multiple files, breaking the build and preventing the app from running. These errors stem from missing type definitions, incorrect references, and broken dependencies that need systematic resolution.

## What Changes
- Define missing VideoLoadingError enum with comprehensive error cases
- Fix incorrect pattern assignments and variable references
- Resolve protocol conformance issues in video components
- Update state management references in AddMove flow
- Fix async/await isolation issues
- Resolve Result type usage errors

## Impact
- Affected specs: video-loading, add-move-flow, trimmer-interface
- Affected code: VideoPlayer.swift, SimpleLoading.swift, VideoLoadingState.swift, MinimalTrimmerView.swift, NameMoveView.swift, RobustVideoLoader.swift, MainView.swift, AddMoveViewModel.swift
- **BREAKING**: None - these are bug fixes restoring intended functionality