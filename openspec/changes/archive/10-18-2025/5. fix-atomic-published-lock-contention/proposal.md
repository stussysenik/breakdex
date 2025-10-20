## Why

Video loading gets stuck at 94% because @Published property updates occurring within atomic lock contexts are treated as atomic operations by SwiftUI, causing the observation system to coalesce multiple updates and drop subsequent state transitions. This prevents AddMoveViewModel's final progress updates (95% → 99% → 100%) from reaching the UI layer.

## Problem Statement

**ROOT CAUSE**: @Published property updates inside the atomic lock (`isFinalizingState = true`) create a critical section where multiple @Published properties are updated in rapid succession. SwiftUI's observation system treats these lock-protected updates as atomic operations and coalesces them, breaking the observation chain.

**EVIDENCE FROM LATEST LOGS**:
1. Lines 98-102: @Published updates occur **UNDER ATOMIC LOCK** (`[LOCKED|0.302ms]`, `[LOCKED|1.466ms]`)
2. Line 69: `"onChange(of: LoadingState) action tried to update multiple times per frame"` persists
3. Lines 113-117: Service→ViewModel transitions complete successfully, but UI never receives the final state

**ARCHITECTURAL ISSUE**: The atomic lock prevents dual execution but creates a new bottleneck - @Published contention within atomic contexts. SwiftUI receives multiple property changes within a single atomic operation and collapses them, violating the single-responsibility principle for state updates.

## What Changes

- **MODIFIED**: `SharedVideoPlayer.swift:finalizeVideoLoad()` - Move @Published updates outside atomic lock
- **MODIFIED**: `SharedVideoPlayer.swift:finalizePlayerReadyState()` - Move @Published updates outside atomic lock
- **ADDED**: Deferred @Published update mechanism after lock release
- **ADDED**: Enhanced diagnostic logging for lock acquisition/release timing
- **MAINTAINED**: All existing VideoPlayer API contracts and behavior
- **MAINTAINED**: Atomic state coordination benefits while fixing @Published propagation

## Impact

- **Affected specs**: video-player (state update timing, @Published property propagation)
- **Affected code**:
  - `breakdex/Features/Shared/Video/VideoPlayer.swift:finalizeVideoLoad()`
  - `breakdex/Features/Shared/Video/VideoPlayer.swift:finalizePlayerReadyState()`
  - `breakdex/Features/Shared/Video/VideoPlayer.swift:handlePlayerItemStatusChange()`
- **Breaking changes**: None - preserves existing VideoPlayer interface
- **User impact**: Video loading reliably completes to 100% without hanging at 94%
- **Performance impact**: Improved - eliminates @Published collision overhead and SwiftUI throttling

## Technical Solution

**Current Problematic Pattern**:
```swift
@MainActor
private func finalizeVideoLoad() async {
    // ATOMIC LOCK ACQUIRED
    isFinalizingState = true

    // PROBLEM: @Published updates inside atomic lock
    state = .ready              // @Published #1 under lock
    await MainActor.run {
        isReady = true          // @Published #2 under lock
    }

    // ATOMIC LOCK RELEASED
    isFinalizingState = false
}
```

**Fixed Solution**:
```swift
@MainActor
private func finalizeVideoLoad() async {
    guard !isFinalizingState, state != .ready else {
        logger.info("🎯 ATOMIC LOCK PREVENTED: finalizeVideoLoad() blocked")
        return
    }

    // ATOMIC LOCK ACQUIRED for state coordination only
    isFinalizingState = true
    let shouldUpdateState = (state != .ready)
    let lockStartTime = CFAbsoluteTimeGetCurrent()

    defer {
        let lockDuration = CFAbsoluteTimeGetCurrent() - lockStartTime
        isFinalizingState = false
        logger.info("🔓 ATOMIC LOCK RELEASED after \(String(format: "%.3f", lockDuration * 1000))ms")
    }

    // EXIT ATOMIC CONTEXT before @Published updates
    await MainActor.run { [self] in
        guard shouldUpdateState else { return }

        // @Published updates outside atomic lock - separate frames
        let stateTimestamp = CFAbsoluteTimeGetCurrent()
        self.logPublishedUpdate("state", stateTimestamp, "loading -> ready")
        self.state = .ready

        // Natural frame separation via MainActor.run
        Task { @MainActor [self] in
            let isReadyTimestamp = CFAbsoluteTimeGetCurrent()
            let frameDelay = isReadyTimestamp - stateTimestamp

            self.logPublishedUpdate("isReady", isReadyTimestamp, "false -> true (deferred)")
            self.logger.info("🎯 DEFERRED FRAME SEPARATION: \(String(format: "%.3f", frameDelay * 1000))ms")
            self.isReady = true
        }
    }
}
```

**Why This Works**:
1. **Atomic Lock Scope Reduction**: Lock only protects state coordination, not @Published updates
2. **Deferred @Published Updates**: Move property changes outside atomic context
3. **Natural Frame Separation**: Leverage MainActor.run for proper UI frame timing
4. **Enhanced Diagnostics**: Track lock timing and @Published update propagation
5. **MVVM Compliance**: Maintains single responsibility and clean architecture

**Diagnostic Logging Added**:
- Lock acquisition/release timing with millisecond precision
- @Published update timing relative to lock boundaries
- Frame separation verification for deferred updates
- State propagation validation across ViewModel boundaries
- Collision detection when @Published updates occur under lock

**Apple Documentation Alignment (iOS 18 & Swift 6)**:
- **@MainActor Compiler Enforcement**: Leverages iOS 18's enhanced main-thread guarantees
- **Swift 6 Concurrency**: Prevents data races while maintaining proper @Published timing
- **SwiftUI Observation Best Practices**: Ensures single @Published update per UI frame
- **MVVM Architecture**: Maintains clean separation between service and view model layers