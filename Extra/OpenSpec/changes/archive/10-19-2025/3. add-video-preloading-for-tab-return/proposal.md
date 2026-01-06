## Why

The current tab navigation implementation correctly restores workflow state but suffers from a temporal mismatch: the video trimming view appears before the video player is ready, causing excessive view recomputations (200+ iterations) and visible video flashing. This creates a poor user experience where users see empty video frames for 2-3 seconds after returning to the Add Move tab.

## What Changes

- **ADDED**: Video preloading mechanism in AddMoveViewModel that starts video loading immediately when a suspended workflow is detected
- **MODIFIED**: AddMoveView.setupInitialState() to trigger video preloading before view composition
- **MODIFIED**: MinimalTrimmerView.onAppear() to guard against rendering until video player is ready
- **ADDED**: Minimal diagnostic logging to track preloading timing and view readiness
- **MODIFIED**: Workflow suspension logic to cache video player state for faster restoration

## Impact

- **Affected specs**: add-move-workflow, video-state
- **Affected code**:
  - `breakdex/Features/AddMove/ViewModels/AddMoveViewModel.swift` (add preloadVideoForQuickReturn method)
  - `breakdex/Features/AddMove/Views/AddMoveView.swift:118-142` (setupInitialState method)
  - `breakdex/Features/Shared/Video/MinimalTrimmerView.swift:174-188` (onAppear method)
- **User impact**: Instantaneous video display when returning to Add Move tab with no flashing or loading delays
- **Technical impact**: Proper temporal coordination between workflow state restoration and video player readiness
- **Breaking changes**: None - maintains existing interface while improving performance
- **iOS 18 Compatibility**: Uses async/await patterns compatible with iOS 18 performance requirements