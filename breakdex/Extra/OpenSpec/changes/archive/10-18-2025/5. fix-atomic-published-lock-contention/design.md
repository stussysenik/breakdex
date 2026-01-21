## Context

The 94% video loading hang persists despite implementing atomic state coordination. Analysis of the latest logs reveals that while dual execution paths were eliminated, @Published property updates occurring within atomic lock contexts are being coalesced by SwiftUI's observation system, preventing proper state propagation to the UI layer.

## Goals / Non-Goals

- **Goals**:
  - Move @Published property updates outside atomic lock contexts
  - Maintain atomic state coordination benefits while fixing observation chain
  - Ensure reliable 100% loading completion without UI hangs
  - Provide enhanced diagnostic logging for future debugging

- **Non-Goals**:
  - Removing the atomic lock mechanism (it successfully prevents dual execution)
  - Changing the overall video loading architecture
  - Adding artificial delays or complex timing mechanisms

## Decisions

- **Decision**: Use deferred @Published updates after atomic lock release
  - **Rationale**: Preserves state coordination while eliminating SwiftUI observation coalescing
  - **Alternatives considered**: Removing atomic lock entirely (loses dual execution prevention), using artificial delays (anti-pattern)

- **Decision**: Leverage MainActor.run for natural frame separation
  - **Rationale**: iOS 18 @MainActor provides compiler-enforced main thread execution with proper frame timing
  - **Alternatives considered**: Manual Task.sleep (artificial), complex timing mechanisms (over-engineering)

- **Decision**: Maintain MVVM single responsibility principle
  - **Rationale**: Each component handles its specific responsibility without cross-contamination
  - **Alternatives considered**: Breaking MVVM separation for simpler fix (violates project architecture)

## Implementation Strategy

**Atomic Lock Scope Reduction**:
The atomic lock now only protects state coordination logic, not @Published property updates. This eliminates SwiftUI's tendency to coalesce lock-protected updates while preserving race condition prevention.

**Deferred @Published Update Pattern**:
```swift
// 1. Acquire lock for state coordination only
isFinalizingState = true
let shouldUpdate = (state != .ready)

// 2. Release lock before @Published updates
defer { isFinalizingState = false }

// 3. Perform @Published updates outside atomic context
await MainActor.run {
    if shouldUpdate {
        state = .ready  // First @Published update
    }
}

// 4. Natural frame separation for second update
Task { @MainActor in
    isReady = true  // Second @Published update, guaranteed separate frame
}
```

**Enhanced Diagnostic Logging**:
- Lock acquisition/release timing with high precision timestamps
- @Published update timing relative to atomic boundaries
- Frame separation verification between consecutive @Published updates
- State propagation validation across ViewModel boundaries

## Risks / Trade-offs

- **Risk**: Deferred @Published updates might introduce timing edge cases
  - **Mitigation**: MainActor.run guarantees proper execution order and frame timing
- **Risk**: Moving @Published updates outside lock might race with other operations
  - **Mitigation**: State guard logic still prevents dual execution; only @Published timing changes
- **Trade-off**: Slightly more complex control flow in finalize methods
  - **Benefit**: Eliminates UI freeze while maintaining race condition prevention

## Migration Plan

1. Refactor finalizeVideoLoad() to defer @Published updates
2. Refactor finalizePlayerReadyState() to defer @Published updates
3. Add enhanced diagnostic logging for timing verification
4. Test video loading flow to ensure 100% completion
5. Verify no regression in other VideoPlayer functionality
6. Monitor diagnostic logs in production for timing issues

## Open Questions

- None identified - the solution directly addresses the root cause with minimal architectural impact