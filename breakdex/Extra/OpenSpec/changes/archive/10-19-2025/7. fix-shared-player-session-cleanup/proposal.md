## Why
The video loading mechanism fails when users cancel trimming and select a new clip, violating our 99.9% reliability goal. Evidence shows that session #1 loads successfully, but session #3 gets stuck in `creatingAsset` stage and never reaches the UI, causing users to experience a complete failure to load the second video.

## What Changes
- Add proper SharedVideoPlayer cleanup to AddMoveViewModel.reset() method
- Implement session isolation to prevent cross-session state corruption
- Add minimal diagnostic logging to track session boundaries and player state
- Ensure MainActor isolation for all session cleanup operations
- **BREAKING**: Changes reset behavior to include SharedVideoPlayer cleanup

## Impact
- Affected specs: video-loading, add-move-workflow
- Affected code: AddMoveViewModel.swift, SharedVideoPlayer.swift
- Primary benefit: 99.9% reliable video loading across user interactions
- Secondary benefit: Better diagnostic visibility into session boundaries
- Testing: Verify cancel-trim-select-new-clip workflow works reliably