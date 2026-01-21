## Context
The breakdex app's AddMove feature suffers from critical state synchronization issues where users get stuck at loading overlay. The logs reveal race conditions between multiple state update mechanisms, inconsistent loading state management, and progress update conflicts. The current architecture has competing state transformation paths that don't properly commute, leading to non-deterministic behavior.

### Constraints
- iOS 18.0 compliance required
- Must maintain backward compatibility with existing Core Data models
- Cannot break existing video loading functionality
- Must preserve existing UI component interfaces

### Stakeholders
- End users experiencing loading overlay freezes
- Development team maintaining state management code
- QA team testing video loading flows

## Goals / Non-Goals
- Goals:
  - Eliminate loading overlay freeze issues
  - Ensure deterministic state transitions
  - Provide atomic state updates
  - Maintain performance characteristics
- Non-Goals:
  - Complete rewrite of state management
  - Changes to video loading algorithms
  - UI component redesign

## Decisions
- Decision: Implement atomic state transition system using Actor-based coordination
  - Why: Prevents race conditions and ensures state consistency
  - Alternatives considered:
    - Serial dispatch queue (performance overhead)
    - Lock-based synchronization (deadlock risk)
    - Reactive programming (complexity increase)

- Decision: Add state transition guards with validation
  - Why: Prevents invalid state transitions and provides early error detection
  - Alternatives considered:
    - Post-state validation (error detection too late)
    - Event sourcing (overhead for this use case)

- Decision: Implement progress update debouncing
  - Why: Reduces UI update frequency and prevents progress update storms
  - Alternatives considered:
    - Throttling (can drop important updates)
    - Batch processing (adds latency)

## Risks / Trade-offs
- Performance overhead from atomic state transitions → Mitigation: Optimize critical paths and use async/await efficiently
- Increased complexity of state management → Mitigation: Comprehensive documentation and testing
- Potential breaking changes for existing components → Mitigation: Maintain backward compatibility through adapters

## Migration Plan
1. Create new AtomicStateCoordinator alongside existing AddMoveUnifiedState
2. Gradually migrate state transitions to atomic coordinator
3. Add compatibility layer for existing components
4. Remove deprecated state management methods
5. Update documentation and examples

## Open Questions
- Should we implement full Actor-based isolation or use MainActor with coordination?
- How to handle state recovery during concurrent operations?
- What level of progress update granularity is optimal for UI responsiveness?