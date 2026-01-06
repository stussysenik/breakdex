## Why

After 4 failed attempts to fix the 88% progress issue, the root cause has been identified through architectural analysis: the state propagation chain from AddMoveViewModel to UI is broken due to an async TaskGroup that creates a separate execution context, preventing the final state transition from reaching the UI layer.

## Problem Statement

The video loading flow gets stuck at 88% because the `coordinatePlayerInitialization` function in AddMoveViewModel creates a TaskGroup that breaks the state propagation chain. This creates an architectural boundary violation where:

1. **Service Layer** (RobustVideoLoader) → **ViewModel Layer** (AddMoveViewModel): ✅ Works (assetReady: 60%)
2. **ViewModel Layer** (coordinatePlayerInitialization): ❌ Broken - creates async context that doesn't propagate state
3. **UI Layer** (SelectClip): ❌ Stuck at 88% - never receives final transition

**Root Cause:**
The `coordinatePlayerInitialization` function uses `TaskGroup` which creates a separate async context. **SMOKING GUN EVIDENCE**: Line 96 in logs shows `"✅ Monotonic transition: 88.00000000000001% → 100.0%"` - the system reaches 100% internally but UI gets stuck at 88%. This happens because:

1. SharedVideoPlayer sets `loading(progress: 0.9, ...)` (90%)
2. TaskGroup completes and sets `fullyReady` (100%)
3. UI receives calculated progress of 88% (`0.8 + (0.8 * 0.1) = 0.88`) instead of final state
4. The 100% transition happens in TaskGroup context and doesn't propagate to UI's `@Published` observation chain

```swift
// BROKEN: AddMoveViewModel.swift:365-395
await withTaskGroup(of: Void.self) { group in
    group.addTask { @MainActor in
        let playerReady = await self.videoPlayer.loadVideo(asset)
        if playerReady {
            self.loadingState = .fullyReady(asset)  // State change in TaskGroup context
        }
    }
}
// State change doesn't propagate to UI properly
```

## What Changes

- **BREAKING**: Remove TaskGroup-based `coordinatePlayerInitialization` function
- **MODIFIED**: Implement direct async player coordination with proper state propagation
- **ADDED**: Progressive state updates during player initialization (90% → 95% → 100%)
- **ADDED**: Minimal diagnostic logging for state propagation verification
- **MODIFIED**: Ensure `@Published` property changes propagate to UI layer correctly
- **REMOVED**: Async context isolation that breaks state observation chain

## Impact

- **Affected specs**: video-loading (state propagation)
- **Affected code**:
  - `AddMoveViewModel.swift:coordinatePlayerInitialization()` - replace TaskGroup with direct async
  - `AddMoveViewModel.swift:handleVideoLoaderStateChange()` - add progressive state updates
  - `LoadingState.swift` - ensure 100% state propagates correctly
- **Breaking changes**: Remove TaskGroup-based coordination pattern
- **User impact**: Users can successfully complete video import workflow without getting stuck at 88%

## Technical Summary

The issue is fundamentally about **state propagation across architectural boundaries**. The current TaskGroup implementation creates an async context that isolates state changes from the UI's observation chain. The solution ensures that state transitions properly propagate from Service → ViewModel → UI by maintaining a single execution context that respects `@Published` property observation.

**Key Fix (iOS 18 Best Practices):**
Replace the TaskGroup pattern with direct async coordination that maintains the state observation chain, following iOS 18 recommendations:

```swift
// FIXED: Direct async coordination with proper @MainActor state propagation
@MainActor
func coordinatePlayerInitialization(asset: AVAsset) async {
    // Progressive state updates that propagate to UI
    loadingState = .loading(progress: 0.9, stage: .initializingPlayer, message: "Preparing video player...")

    let playerReady = await videoPlayer.loadVideo(asset)

    if playerReady {
        loadingState = .loading(progress: 0.95, stage: .preparingPlayback, message: "Preparing for playback...")
        loadingState = .fullyReady(asset)  // Properly propagates to UI
    }
}
```

**iOS 18 Best Practices Applied:**
- **@MainActor Class Isolation**: Ensure entire ViewModel class uses `@MainActor` rather than individual properties for automatic main-thread execution
- **Direct Async Patterns**: Avoid TaskGroup for single async operations that need UI state propagation
- **Progressive State Updates**: Use incremental progress reporting (90% → 95% → 100%) for smooth UX
- **Structured Simplicity**: Use straightforward async/await instead of complex TaskGroup coordination for UI state management

**Minimal Diagnostic Logging:**
Add precise logging at each state transition to verify the propagation chain works:

- Service → ViewModel transition logging
- Player initialization progress logging
- Final state transition verification
- UI observation confirmation

This approach maintains the MVVM pattern while ensuring the state propagation functor works correctly across all architectural boundaries, following iOS 18 production best practices for AVPlayer loading and SwiftUI concurrency patterns.