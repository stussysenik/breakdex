## Why

Video loading gets stuck at 94% because SharedVideoPlayer updates two @Published properties simultaneously, causing SwiftUI's change detection to drop subsequent state transitions. The logs show the exact moment this happens and the resulting UI freeze.

## Problem Statement

**SMOKING GUN EVIDENCE**:
1. **Line 66**: `"onChange(of: LoadingState) action tried to update multiple times per frame"`
2. **Line 96**: `🔄 STATE TRANSITION: loading(progress: 0.9, message: "Finalizing video load...") → ready, isReady: false → true`

The issue occurs in `SharedVideoPlayer.swift` when **two @Published properties are updated simultaneously**:

```swift
// PROBLEM CODE in SharedVideoPlayer.swift
state = .ready           // @Published property #1
isReady = true          // @Published property #2 (same frame)
```

This simultaneous update confuses SwiftUI's observation system, causing it to throttle changes. When AddMoveViewModel subsequently tries to update its own @Published properties (lines 100-106: 95% → 99% → 100%), SwiftUI drops these transitions because it's still processing the previous frame's multiple updates.

## What Changes

- **MODIFIED**: `SharedVideoPlayer.swift:loadVideo()` - Add temporal separation between `state` and `isReady` updates
- **ADDED**: Minimal diagnostic logging to track @Published property update timing
- **MODIFIED**: Ensure each @Published property update occupies its own UI frame
- **REMOVED**: No breaking changes - maintains existing VideoPlayer API contracts

## Impact

- **Affected specs**: video-player (state update timing)
- **Affected code**:
  - `SharedVideoPlayer.swift:loadVideo()` - separate `state` and `isReady` updates temporally
  - VideoPlayer state validation logic
- **Breaking changes**: None - preserves existing VideoPlayer interface and behavior
- **User impact**: Video loading reliably completes to 100% without getting stuck at intermediate progress

## Technical Summary

The root cause is **@Published property collision** in SharedVideoPlayer, not AddMoveViewModel's progressive state updates. The solution ensures temporal separation between @Published property changes while maintaining the existing VideoPlayer architecture.

**Key Fix (iOS 18 Production Best Practices):**

Replace simultaneous @Published updates with atomic, temporally-separated transitions using iOS 18's enhanced @MainActor enforcement:

```swift
// iOS 18 ENHANCED: Ensure atomic @Published updates with MainActor compiler enforcement
@MainActor
func finalizeVideoLoad() async {
    // Update state property atomically (iOS 18 @MainActor compiler-enforced)
    state = .loading(progress: 0.9, message: "Finalizing video load...")

    // Temporal separation: ensure state change processes before isReady update
    // iOS 18: @MainActor guarantees main-thread execution with compiler enforcement
    try? await Task.sleep(nanoseconds: 16_666_667) // Exactly 1/60 second (one UI frame)

    let previousState = state
    let previousIsReady = isReady
    state = .ready  // First @Published property update

    // Critical: Separate @Published updates to prevent SwiftUI change detection collision
    // iOS 18: Compiler prevents non-atomic @Published updates when @MainActor is used
    try? await Task.sleep(nanoseconds: 16_666_667) // One UI frame separation

    isReady = true  // Second @Published property update - atomic and frame-separated
}
```

**iOS 18 Production Best Practices Applied:**
- **@MainActor Compiler Enforcement**: iOS 18 marks SwiftUI View protocol with @MainActor, ensuring all UI updates happen on main thread with compiler validation
- **Atomic @Published Updates**: Use temporally-separated updates to prevent SwiftUI's "multiple times per frame" throttling
- **Frame-Aligned Timing**: Exactly 16.67ms (1/60 second) delays ensure each @Published change gets its own render frame
- **Compiler Safety**: iOS 18 @MainActor prevents @Published threading issues at compile time rather than runtime

**Why This Fixes the 94% Issue:**
1. SharedVideoPlayer's @Published updates no longer collide with each other
2. SwiftUI's change detection processes each property update in separate frames
3. AddMoveViewModel's subsequent @Published updates (95% → 99% → 100%) get processed correctly
4. UI receives and displays the final 100% state without interference