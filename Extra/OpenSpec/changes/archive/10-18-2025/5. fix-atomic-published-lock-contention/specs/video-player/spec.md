# Video Player State Management Specification

## MODIFIED Requirements

### Requirement: Deferred @Published Updates Outside Atomic Lock

Video player state finalization methods SHALL defer @Published property updates until after atomic lock release to prevent SwiftUI observation coalescing.

#### Scenario: Successful Video Loading with Proper State Propagation
**Given** a video asset is loaded and the player is ready for finalization
**When** `finalizeVideoLoad()` is called
**Then** it SHALL:
1. Acquire atomic lock for state coordination only
2. Determine if state updates are needed while under lock
3. Release atomic lock before any @Published property updates
4. Update `state = .ready` outside atomic lock context
5. Update `isReady = true` in a separate MainActor execution context
6. Log timing diagnostics for lock and @Published update boundaries

#### Scenario: Dual Execution Prevention with Proper @Published Timing
**Given** atomic lock is already held by another execution path
**When** `finalizeVideoLoad()` or `finalizePlayerReadyState()` is called
**Then** it SHALL:
1. Detect atomic lock state and exit early
2. Log the prevention of dual execution
3. NOT modify any @Published properties
4. Preserve existing state consistency

### Requirement: Enhanced Diagnostic Logging for @Published Timing

Video player SHALL provide detailed timing diagnostics for atomic lock boundaries and @Published property updates to aid future debugging.

#### Scenario: Lock Timing Diagnostics
**Given** any state finalization method is executed
**When** atomic lock operations occur
**Then** it SHALL:
1. Log atomic lock acquisition with high-precision timestamp
2. Log atomic lock release with duration measurement
3. Log @Published property updates with timestamps relative to lock boundaries
4. Log frame separation verification between consecutive @Published updates
5. Use consistent log format for timing analysis

#### Scenario: State Propagation Validation
**Given** @Published properties are updated
**When** state transitions occur
**Then** it SHALL:
1. Log state transition details (from → to)
2. Log @Published property update timing
3. Validate that @Published updates occur outside atomic lock contexts
4. Detect and log any @Published collision scenarios

## REMOVED Requirements

### Requirement: @Published Updates Within Atomic Lock Context
**Description**: Removed the pattern of updating @Published properties while holding atomic lock, as this causes SwiftUI observation coalescing.

## Technical Constraints

### Constraint: iOS 18 @MainActor Compliance
All @Published property updates must occur within @MainActor contexts but outside atomic lock sections to leverage iOS 18's enhanced main-thread guarantees.

### Constraint: SwiftUI Observation Compatibility
@Published property updates must be timed to avoid SwiftUI's "multiple updates per frame" throttling mechanism.

### Constraint: MVVM Architecture Compliance
State management must maintain clean separation between service layer (SharedVideoPlayer) and view model layer (AddMoveViewModel).

### Constraint: Single Responsibility Principle
Each method must have a single clear responsibility - either atomic state coordination OR @Published property updates, not both.

## Validation Criteria

### Success Criteria
1. Video loading consistently completes to 100% without hanging at 94%
2. No "onChange action tried to update multiple times per frame" warnings
3. Diagnostic logs show clear separation between atomic lock operations and @Published updates
4. State propagation from SharedVideoPlayer to AddMoveViewModel to UI functions correctly
5. Atomic lock successfully prevents dual execution without breaking observation chain

### Failure Criteria
1. Video loading hangs at any intermediate percentage
2. @Published collision warnings persist in logs
3. UI does not update to final ready state
4. Dual execution paths still occur
5. Diagnostic logs show @Published updates occurring under atomic lock