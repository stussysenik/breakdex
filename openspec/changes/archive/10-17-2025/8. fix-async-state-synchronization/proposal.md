## Why

Fix critical async state synchronization breakdown causing video loading to get stuck at 76% progress, preventing users from completing video import workflow due to architectural layer boundary violations.

## Problem Statement

The video loading flow gets stuck at 76% progress due to **async boundary crossing violations** between three architectural layers:

1. **Service Layer** (RobustVideoLoader) - completes successfully ✅
2. **Player Layer** (SharedVideoPlayer) - completes successfully ✅
3. **ViewModel Layer** (AddMoveViewModel) - stuck at 76% ❌

**Root Cause:**
The AddMoveViewModel's `handleVideoLoaded()` method assumes the SharedVideoPlayer's `loadVideo()` method completes synchronously, but it actually has its own asynchronous observer-based lifecycle. This creates an **architectural boundary violation** where:

```swift
await videoPlayer.loadVideo(asset)  // Async Player layer morphism
loadingState = .fullyReady(asset)  // Immediate ViewModel state transition
```

The ViewModel sets `loadingState = .fullyReady(asset)` **before** the Player layer has actually completed its initialization, causing the UI to hang at the last ViewModel loading stage (76%).

## What Changes

- **MODIFIED**: AddMoveViewModel's `handleVideoLoaded()` method to use `withCheckedContinuation` for iOS 18 best practices
- **ADDED**: Continuation-based async coordination using Apple's recommended bridging pattern
- **MODIFIED**: State progression from `validatingFile` (76%) to `fullyReady` (100%) using proper async/await
- **ADDED**: Timing-based diagnostic logging with `CFAbsoluteTimeGetCurrent()` for performance analysis
- **REMOVED**: Premature state transition that assumes synchronous Player completion
- **ENHANCED**: MainActor compliance for all UI state updates across async boundaries

## Impact

- **Affected specs**: video-loading (async state coordination)
- **Affected code**:
  - `AddMoveViewModel.swift:handleVideoLoaded()` - fix async boundary crossing
  - `SharedVideoPlayer.swift:loadVideo()` - ensure proper callback invocation
- **Breaking changes**: None (restores intended async behavior)
- **User impact**: Users can successfully complete video import workflow without getting stuck at 76%

## Technical Summary

The issue stems from **layer boundary violation** where the ViewModel layer doesn't properly observe the Player layer's async completion. The fix uses Apple's recommended **`withCheckedContinuation` pattern** to bridge callback-based AVPlayer APIs to modern Swift async/await, ensuring proper state flow: Service → Player → ViewModel while maintaining architectural integrity and preventing the 76% hang.

**iOS 18 Compliance**: The solution follows current Apple documentation recommendations for async AVPlayer loading patterns, ensuring MainActor isolation and providing precise timing diagnostics for performance analysis.