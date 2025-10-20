## MODIFIED Requirements

### Requirement: State Propagation Chain Integrity
The system SHALL maintain a complete state propagation chain from Service layer through ViewModel to UI layer without async context isolation that breaks @Published property observation.

#### Scenario: Progressive player initialization with proper state propagation
- **WHEN** SharedVideoPlayer initializes after asset loading completes
- **THEN** AddMoveViewModel SHALL provide progressive state updates (90% → 95% → 100%)
- **AND** each state change SHALL properly propagate to UI layer through @Published properties
- **AND** the system SHALL NOT use TaskGroup contexts that isolate state changes from UI observation
- **AND** the system SHALL follow iOS 18 @MainActor class isolation patterns for automatic main-thread execution

#### Scenario: Direct async coordination maintaining observation chain
- **WHEN** coordinating player initialization
- **THEN** the system SHALL use direct async coordination instead of TaskGroup
- **AND** state changes SHALL occur in the same execution context as UI observation
- **AND** fullyReady state SHALL immediately propagate to UI layer
- **AND** the system SHALL NOT get stuck at 88% due to TaskGroup context isolation
- **AND** the system SHALL follow iOS 18 structured simplicity patterns for UI state management

#### Scenario: Prevent 88% progress calculation error
- **WHEN** SharedVideoPlayer reports 90% progress and TaskGroup transitions to fullyReady (100%)
- **THEN** the UI SHALL receive 100% state directly
- **AND** SHALL NOT receive calculated progress of 88% (`0.8 + (0.8 * 0.1) = 0.88`)
- **AND** the system SHALL ensure final state transition bypasses intermediate calculations
- **AND** the system SHALL use iOS 18 @MainActor isolation for automatic main-thread @Published updates

## ADDED Requirements

### Requirement: iOS 18 Concurrency Best Practices
The system SHALL follow iOS 18 concurrency best practices for AVPlayer loading and SwiftUI state management.

#### Scenario: @MainActor class isolation for automatic main-thread execution
- **WHEN** implementing ViewModel with async operations that update UI state
- **THEN** the system SHALL use @MainActor class-level isolation rather than individual properties
- **AND** SHALL ensure all @Published property updates automatically occur on main thread
- **AND** SHALL avoid MainActor.run wrapper calls for individual property updates

#### Scenario: Direct async patterns for single UI-state operations
- **WHEN** coordinating single async operations that need UI state propagation
- **THEN** the system SHALL use direct async/await patterns instead of TaskGroup
- **AND** SHALL maintain single execution context for @Published property observation
- **AND** SHALL follow iOS 18 structured simplicity principles for UI state management

### Requirement: Minimal Diagnostic State Logging
The system SHALL provide minimal diagnostic logging to verify state propagation chain integrity without overwhelming logs.

#### Scenario: State transition verification logging
- **WHEN** state transitions occur between layers
- **THEN** the system SHALL log transition with timestamp, source, and progress percentage
- **AND** SHALL log successful Service → ViewModel state propagation
- **AND** SHALL log successful ViewModel → UI state propagation
- **AND** SHALL log warnings for any broken state observation chain

#### Scenario: Player initialization progress tracking
- **WHEN** SharedVideoPlayer initializes
- **THEN** the system SHALL log each initialization milestone
- **AND** SHALL log progressive state updates (90%, 95%, 100%)
- **AND** SHALL verify final state reaches UI layer

#### Scenario: Architectural boundary verification
- **WHEN** state crosses architectural boundaries
- **THEN** the system SHALL verify boundary integrity
- **AND** SHALL log any context isolation that breaks state propagation
- **AND** SHALL ensure @Published property changes reach UI observers

## REMOVED Requirements

### Requirement: TaskGroup-based Async Coordination
**Reason**: TaskGroup creates async context isolation that breaks state propagation chain to UI layer.
**Migration**: Replace with direct async coordination that maintains @Published property observation chain.