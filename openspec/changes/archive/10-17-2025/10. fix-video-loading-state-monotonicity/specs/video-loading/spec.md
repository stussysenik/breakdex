## MODIFIED Requirements

### Requirement: Video Loading State Management
The system SHALL maintain monotonic loading state transitions that only progress forward and never retrograde from completion states back to loading states.

#### Scenario: State progression maintains monotonicity
- **WHEN** video loading progresses through stages
- **THEN** each state transition SHALL only increase progress percentage
- **AND** states SHALL NOT retrograde from `fullyReady` back to `loading`

#### Scenario: Player initialization respects terminal states
- **WHEN** SharedVideoPlayer initializes after video loading reaches 100%
- **THEN** the system SHALL NOT revert loading state to intermediate progress
- **AND** UI SHALL display completion state without regression

## ADDED Requirements

### Requirement: State Monotonicity Validation
The system SHALL validate state transitions using a state machine pattern to prevent backward progress and maintain architectural integrity with modern Swift concurrency.

#### Scenario: State transition validation
- **WHEN** a state transition is attempted
- **THEN** the system SHALL validate that progress only moves forward using deterministic state machine logic
- **AND** SHALL reject any transition that would decrease progress percentage
- **AND** SHALL enforce @MainActor isolation for all UI-related state updates

#### Scenario: Diagnostic state logging
- **WHEN** state transitions occur
- **THEN** the system SHALL log transition details with timestamp, progress, and source component
- **AND** SHALL log warnings for any attempted state retrogression
- **AND** SHALL use structured logging for easier debugging and analysis

#### Scenario: Async coordination with structured concurrency
- **WHEN** multiple async operations need coordination
- **THEN** the system SHALL use TaskGroup to coordinate service and player initialization
- **AND** SHALL avoid competing continuation patterns that cause race conditions
- **AND** SHALL ensure all async operations complete before reaching terminal states

### Requirement: Coordinated State Architecture
The system SHALL implement single source of truth coordination between video loading service, player, and view model.

#### Scenario: Service layer responsibility
- **WHEN** video asset loading occurs
- **THEN** RobustVideoLoader SHALL manage only asset loading states using iOS 18 async AVAsset APIs
- **AND** SHALL NOT interfere with player or UI state management
- **AND** SHALL use structured concurrency patterns for coordination

#### Scenario: Player layer responsibility
- **WHEN** video player initialization occurs
- **THEN** SharedVideoPlayer SHALL manage only playback state with @MainActor isolation
- **AND** SHALL coordinate with ViewModel without causing state retrogression
- **AND** SHALL use modern async AVPlayer loading instead of callback patterns

#### Scenario: ViewModel coordination
- **WHEN** observing state changes from service and player
- **THEN** AddMoveViewModel SHALL maintain monotonic UI state with @MainActor enforcement
- **AND** SHALL prevent backward progress transitions
- **AND** SHALL use proper async/await patterns for state observation

#### Scenario: iOS 18 compliance
- **WHEN** implementing video loading
- **THEN** the system SHALL use iOS 18's async AVAsset loading APIs
- **AND** SHALL ensure proper MainActor isolation for UI updates
- **AND** SHALL follow current Swift concurrency best practices for 2025