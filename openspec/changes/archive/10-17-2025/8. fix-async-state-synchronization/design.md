## Context

The video loading system consists of three architectural layers with distinct responsibilities:
- **Service Layer (RobustVideoLoader)**: Asset loading and validation from external sources
- **Player Layer (SharedVideoPlayer)**: AVPlayer initialization and playback setup
- **ViewModel Layer (AddMoveViewModel)**: State coordination and UI updates

The current implementation violates async boundary principles by assuming synchronous completion across these layers, causing UI hangs at 76% progress.

## Goals / Non-Goals

**Goals:**
- Fix the 76% hang by ensuring proper async state synchronization
- Maintain architectural layer integrity and separation of concerns
- Provide clear diagnostic logging for async boundary issues
- Ensure no regression in existing video loading functionality

**Non-Goals:**
- Complete architectural redesign of the video loading system
- Changes to the Service layer (RobustVideoLoader) which works correctly
- Modifying the overall video loading flow - only fixing the async boundary issue

## Decisions

**Decision: Use withCheckedContinuation-based async coordination (iOS 18 Best Practice)**
- AddMoveViewModel will use `withCheckedContinuation` to bridge SharedVideoPlayer callbacks to async/await
- Final state transition occurs only after continuation is resumed by player ready callback
- This follows Apple's recommended pattern for bridging callback-based APIs to modern Swift concurrency
- Ensures proper async boundary handling with built-in error detection and timeout management

**Alternatives considered:**
- **Simple callback approach**: Less robust, no timeout or error detection
- **Observation-based approach**: Complex to implement and debug
- **Timeout-based approach**: Would mask the underlying issue rather than fix it

**Decision: iOS 18 Swift Concurrency Compliance**
- Use `withCheckedContinuation` as recommended by Apple's latest documentation
- Maintain MainActor isolation for all UI state updates
- Add timing measurements to detect async boundary performance issues
- Follow modern Swift concurrency patterns for AVPlayer loading

**Decision: Enhanced diagnostic logging**
- Add boundary crossing detection with timing measurements
- Log state synchronization validation results with performance metrics
- Use `CFAbsoluteTimeGetCurrent()` for precise async boundary timing
- This will help identify similar issues and performance bottlenecks

## Risks / Trade-offs

**Risk: Callback invocation reliability**
- **Mitigation**: Validate that SharedVideoPlayer invokes callbacks in all success/failure scenarios
- **Mitigation**: Add unit tests for callback behavior

**Trade-off: Slight complexity increase**
- The callback approach adds minimal complexity while fixing the core issue
- Alternative approaches would require more extensive changes

**Risk: Regression in other video loading scenarios**
- **Mitigation**: Comprehensive testing with various video sources and formats
- **Mitigation**: Ensure existing functionality remains unchanged

## Migration Plan

**Steps:**
1. Modify AddMoveViewModel.handleVideoLoaded() to use `withCheckedContinuation` pattern
2. Ensure SharedVideoPlayer properly invokes ready callback for continuation resumption
3. Add timing-based diagnostic logging for async boundary detection
4. Test with the problematic video file that hangs at 76%
5. Validate no regression with other video loading scenarios
6. Verify MainActor compliance and proper async boundary handling

**Implementation Pattern:**
```swift
// iOS 18 best practice implementation
await withCheckedContinuation { continuation in
    loadingState = .loading(progress: 0.8, stage: .initializingPlayer, message: "Initializing video player...")

    await videoPlayer.loadVideo(asset) {
        continuation.resume()
    }
}
loadingState = .fullyReady(asset)
```

**Rollback:**
- Changes are isolated to AddMoveViewModel.handleVideoLoaded() method
- Can be reverted by restoring the original synchronous approach
- No breaking changes to APIs or data structures

## Open Questions

- Should we add timeout handling for the callback invocation?
- Do we need additional validation for edge cases where callback might be invoked multiple times?
- Should we add similar async boundary fixes to other parts of the system?