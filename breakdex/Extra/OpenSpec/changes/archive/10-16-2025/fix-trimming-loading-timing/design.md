## Context

The current trimming functionality suffers from critical timing issues where the loading indicator gets stuck indefinitely, despite successful video loading. Based on comprehensive analysis of logs and code, the root cause is Swift Task Continuation misuse combined with race conditions between video player initialization and UI state transitions.

**Key Issues Identified:**
- Multiple redundant player initialization cycles
- "SWIFT TASK CONTINUATION MISUSE" warnings in VideoPlayer.swift
- Race conditions between MinimalTrimmerView.onAppear and SharedVideoPlayer readiness
- State synchronization gaps between UnifiedState and actual player status

## Goals / Non-Goals

**Goals:**
- Provide deterministic, reliable access to trimming interface within 2 seconds
- Eliminate Swift Task Continuation leaks and warnings
- Prevent redundant player initialization cycles
- Ensure loading states accurately reflect actual player readiness
- Maintain existing clean architecture and performance optimizations

**Non-Goals:**
- Modify existing UI design (separate from trimming interface redesign)
- Change core video loading service architecture
- Alter trimming functionality or video processing logic
- Modify Core Data or state persistence patterns

## Decisions

### Decision 1: Fix Task Continuation Management
**What:** Implement proper continuation lifecycle management in VideoPlayer.swift
**Why:** Continuation leaks cause tasks to remain suspended, preventing proper state transitions
**Implementation:** Use withCheckedThrowingContinuation with proper cleanup and timeout handling

### Decision 2: Add Timing Guards in MinimalTrimmerView
**What:** Prevent multiple redundant setupTrimmer() calls using @State tracking
**Why:** Current implementation allows multiple initialization cycles when view re-appears
**Implementation:** Add hasSetupTrimmer guard with async player readiness waiting

### Decision 3: Implement State Synchronization Validation
**What:** Add consistency checks between UnifiedState.flowState and videoPlayer.isReady
**Why:** Current system allows inconsistent states that cause loading indicators to persist
**Implementation:** Add recovery mechanisms with diagnostic logging

### Decision 4: Coordinate Loading States
**What:** Sync loading overlay visibility with actual player readiness, not just flowState
**Why:** Loading indicator disappears before player is actually ready for interaction
**Implementation:** Use videoPlayer.isReady as primary loading state indicator

**Alternatives considered:**
- Using Combine publishers for state management (rejected: adds complexity)
- Implementing a loading coordinator service (rejected: over-engineering)
- Removing loading indicators entirely (rejected: poor UX for large videos)

## Risks / Trade-offs

**Risk:** Modifying async/await patterns could introduce new race conditions
**Mitigation:** Comprehensive testing with various video formats and network conditions

**Risk:** Adding timing guards might affect performance
**Mitigation:** Use lightweight @State variables and avoid expensive operations in guards

**Trade-off:** Increased code complexity for improved reliability
**Justification:** Essential for "mechanical watch" precision required by athlete persona

## Migration Plan

**Phase 1: Continuation Fixes**
1. Fix waitForPlayerReady method in VideoPlayer.swift
2. Add proper continuation cleanup
3. Test with various timeout scenarios

**Phase 2: UI Timing Guards**
1. Add setupTrimmer guards to MinimalTrimmerView
2. Implement async player readiness waiting
3. Test with rapid view transitions

**Phase 3: State Synchronization**
1. Add validation to UnifiedState
2. Implement recovery mechanisms
3. Test error scenarios and edge cases

**Rollback:** Changes are isolated to specific files; can revert individually if issues arise

## Open Questions

- Should we implement exponential backoff for player initialization retries?
- Do we need additional loading states for specific player initialization phases?
- Should we add user-facing options for loading timeout preferences?

## Technical Implementation Details

### Task Continuation Pattern
```swift
private func waitForPlayerReady(_ playerItem: AVPlayerItem, timeout: TimeInterval) async throws {
    try await withCheckedThrowingContinuation { continuation in
        // Setup observers with proper cleanup
        let task = Task {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            continuation.resume(throwing: VideoPlayerError.timeout)
        }

        // Ensure continuation is resumed exactly once
        // Proper cleanup on cancellation
    }
}
```

### MinimalTrimmerView Guard Pattern
```swift
@State private var hasSetupTrimmer = false

.onAppear {
    guard !hasSetupTrimmer else { return }
    hasSetupTrimmer = true

    Task { @MainActor in
        // Wait for player readiness
        await videoPlayer.waitForReady()
        setupTrimmer()
    }
}
```

### State Synchronization Pattern
```swift
private func validateStateConsistency() async {
    guard flowState == .trimming else { return }

    if !videoPlayer.isReady {
        Logger.addMove.warning("Inconsistent state detected: flowState=trimming but player not ready")
        await attemptPlayerRecovery()
    }
}
```

## Performance Considerations

- Minimal overhead from @State tracking variables
- No impact on video processing performance
- Improved memory usage from eliminated redundant initializations
- Faster UI responsiveness from proper state synchronization

## Testing Strategy

**Unit Tests:**
- Continuation lifecycle management
- State validation logic
- Timing guard behavior

**Integration Tests:**
- Complete loading to trimming workflow
- Error scenarios and recovery
- Performance under various conditions

**UI Tests:**
- Loading indicator behavior
- Trimming interface accessibility
- User interaction timing

## Success Metrics

- Loading indicator disappears within 2 seconds of video selection
- Zero "SWIFT TASK CONTINUATION MISUSE" warnings
- No redundant player initialization cycles
- 100% successful trimming interface access across test scenarios
- Memory usage reduction from eliminated redundant cycles