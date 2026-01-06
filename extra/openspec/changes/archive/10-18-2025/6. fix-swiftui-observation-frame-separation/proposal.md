## Why

Video loading gets stuck at 94% because multiple @Published property updates occur within the same UI frame during atomic lock execution, causing SwiftUI's observation system to coalesce the updates and drop the final state transition to TrimmerView.

## Problem Statement

**ROOT CAUSE**: In `SharedVideoPlayer.finalizeVideoLoad()`, multiple @Published properties (`state` and `isReady`) are updated within the same atomic lock context, causing SwiftUI to treat these as a single update and prevent the proper state propagation to AddMoveViewModel.

**EVIDENCE FROM LOGS**:
- Lines 98-102: Multiple @Published updates occur under atomic lock within 0.129ms
- Line 69: "onChange(of: LoadingState) action tried to update multiple times per frame"
- Lines 115-117: AddMoveViewModel reaches 100% but UI never transitions to TrimmerView

**ARCHITECTURAL ISSUE**: SwiftUI's observation chain requires proper temporal separation between @Published updates to maintain state propagation integrity across the Service → ViewModel → View boundary.

## What Changes

- **MODIFIED**: `SharedVideoPlayer.swift:finalizeVideoLoad()` - Separate @Published updates into different UI frames
- **MODIFIED**: `SharedVideoPlayer.swift:finalizePlayerReadyState()` - Ensure consistent frame separation pattern
- **ADDED**: Minimal diagnostic logging to track @Published update timing
- **REMOVED**: Atomic lock from @Published update timing (keep atomic guard only for state coordination)
- **MAINTAINED**: All existing VideoPlayer API contracts and MVVM architecture

## Impact

- **Affected specs**: video-player (state update timing, @Published property propagation)
- **Affected code**:
  - `breakdex/Features/Shared/Video/VideoPlayer.swift:finalizeVideoLoad()`
  - `breakdex/Features/Shared/Video/VideoPlayer.swift:finalizePlayerReadyState()`
- **Breaking changes**: None - preserves existing VideoPlayer interface
- **User impact**: Video loading reliably completes to 100% and transitions to TrimmerView
- **Performance impact**: Improved - eliminates SwiftUI observation coalescing overhead

## Technical Solution

**Current Problematic Pattern**:
```swift
@MainActor
private func finalizeVideoLoad() async {
    // Atomic lock acquired
    isFinalizingState = true

    // PROBLEM: Multiple @Published updates in same frame under lock
    state = .ready              // @Published #1
    isReady = true              // @Published #2

    // Atomic lock released
    isFinalizingState = false
}
```

**Fixed Solution**:
```swift
@MainActor
private func finalizeVideoLoad() async {
    guard !isFinalizingState, state != .ready else {
        logger.debug("🎯 Atomic lock prevented: finalizeVideoLoad() blocked")
        return
    }

    // Atomic lock only for state coordination
    isFinalizingState = true
    let shouldUpdateState = (state != .ready)
    let lockStartTime = CFAbsoluteTimeGetCurrent()

    defer {
        isFinalizingState = false
        logger.debug("🔓 Lock released: \(String(format: "%.1f", (CFAbsoluteTimeGetCurrent() - lockStartTime) * 1000))ms")
    }

    // Exit atomic context before @Published updates
    await MainActor.run { [self] in
        guard shouldUpdateState else { return }

        // First @Published update
        let stateTimestamp = CFAbsoluteTimeGetCurrent()
        logPublishedUpdate("state", stateTimestamp, "loading -> ready")
        self.state = .ready

        // Natural frame separation for second update
        Task { @MainActor [self] in
            let isReadyTimestamp = CFAbsoluteTimeGetCurrent()
            let frameDelay = isReadyTimestamp - stateTimestamp

            logPublishedUpdate("isReady", isReadyTimestamp, "false -> true")
            logger.debug("🎯 Frame separation: \(String(format: "%.1f", frameDelay * 1000))ms")
            self.isReady = true
        }
    }
}
```

**Key Principles**:
1. **Atomic Guard Scope Reduction**: Lock only protects state coordination, not @Published updates
2. **Natural Frame Separation**: Use MainActor.run and Task for proper UI frame timing
3. **Minimal Diagnostics**: Track @Published timing without verbose logging
4. **MVVM Compliance**: Maintains clean separation between service and view model layers

**Diagnostic Logging**:
- Lock acquisition/release timing (debug level only)
- @Published update timing relative to frame boundaries (debug level only)
- Frame separation verification (info level when significant)

## Apple Documentation Alignment

Following current Apple best practices:
- **@MainActor Usage**: Leverages iOS 18's enhanced main-thread guarantees
- **Swift Concurrency**: Uses async/await patterns with proper actor isolation
- **SwiftUI Observation**: Ensures single @Published update per UI frame for reliable state propagation
- **MVVM Architecture**: Maintains clean separation between service layer and view model