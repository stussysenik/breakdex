## Why
The video loading mechanism fails to achieve 99.9% reliability due to a stage synchronization race condition between the video loader's progress updates and the UI's stage state, causing users to experience stuck or incorrect progress percentages when canceling trimming and selecting new clips.

## What Changes
- Fix atomic state-progress synchronization in RobustVideoLoader to eliminate stage transition lag
- Ensure stage transitions and progress updates happen atomically via @MainActor isolation
- Add minimal diagnostic logging to track stage synchronization timing
- **BREAKING**: Changes internal state update patterns to use atomic transitions

## Impact
- Affected specs: video-loading, add-move-workflow
- Affected code: RobustVideoLoader.swift, AddMoveViewModel.swift, LoadingState.swift
- Primary benefit: 99.9% reliable video loading across user interactions
- Secondary benefit: Better diagnostic visibility into stage synchronization timing
- Testing: Verify cancel-trim-select-new-clip workflow shows correct progress at every step