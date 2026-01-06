## Context

The current video loading system uses a complex state coordination mechanism with multiple actors trying to transition from loadingVideo to trimming state. Race conditions between VideoLoadingService completion, AtomicStateCoordinator, and UI navigation cause the system to get stuck despite successful asset loading.

## Goals / Non-Goals

- Goals: Eliminate race conditions, ensure deterministic state transitions, maintain loading performance
- Non-Goals: Complete rewrite of loading system, changes to Core Data models

## Decisions

- Decision: Use Swift 6.0 actors for atomic state coordination with async/await patterns
- Rationale: Actor isolation prevents race conditions, structured concurrency ensures deterministic flow
- Alternative considered: Event-based coordination - rejected due to complexity in ordering guarantees
- iOS 18.0 pattern: Adopt async/await with load(_:) method for AVAsset operations instead of deprecated synchronous properties

## State Flow Architecture (iOS 18.0 Concurrency)

```swift
// Swift 6.0 Actor-based coordination
@MainActor
stateCoordinator: VideoLoadingStateActor

PhotosPicker Selection → async AVAsset.load() → Actor-coordinated transition → Trimming UI
     (Task detached)        (awaitable)         (atomic @MainActor)      (UI update)
```

## iOS 18.0 Concurrency Integration

Based on iOS 18.0 best practices:
- **AVAsset Loading**: Replace deprecated `duration` property with `await asset.load(.duration)`
- **Structured Concurrency**: Use Task groups for parallel loading operations
- **Actor Isolation**: MainActor for UI state coordination, background actors for heavy operations
- **Cancellation Support**: Implement proper Task cancellation for loading timeouts
- **Error Propagation**: Use async throwing functions for proper error handling

## Key Implementation Patterns

```swift
// iOS 18.0 async asset loading
func loadVideoAsset(from item: PhotosPickerItem) async throws -> AVAsset {
    let asset = try await item.loadTransferable(type: AVAsset.self)
    let duration = try await asset.load(.duration)
    // ... coordinate state transition atomically
}

// Actor-based state coordination
@MainActor
actor VideoLoadingStateActor {
    private var state: LoadingState = .ready

    func transitionToLoading() async throws {
        guard state == .ready else { throw StateTransitionError.invalidState }
        state = .loadingVideo
        // Atomic transition guaranteed by actor isolation
    }
}
```

## Risks / Trade-offs

- Risk: Single coordinator becomes bottleneck → Mitigation: Use async/await with timeout
- Risk: Increased complexity in coordination logic → Mitigation: Comprehensive unit tests
- Trade-off: Slightly more complex code for significantly improved reliability

## Migration Plan (iOS 18.0 Compatibility)

1. **Phase 1**: Replace deprecated AVAsset synchronous properties with async/await patterns
2. **Phase 2**: Implement VideoLoadingStateActor with MainActor isolation for UI coordination
3. **Phase 3**: Add structured concurrency with proper Task cancellation and timeout handling
4. **Phase 4**: Migrate existing loading flows to use actor-based coordination
5. **Phase 5**: Remove old coordination paths after validation and performance testing

## Open Questions

- Should loading progress reporting use AsyncStream for real-time updates vs. discrete state transitions?
- Optimal timeout duration for Task cancellation in loading scenarios?
- Migration strategy for existing PhotosPicker integration to async/await patterns?