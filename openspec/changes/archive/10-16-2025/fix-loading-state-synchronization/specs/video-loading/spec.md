## MODIFIED Requirements

### Requirement: Video Loading State Management
The system SHALL provide atomic state coordination for video loading operations to prevent race conditions and ensure deterministic user experience.

#### Scenario: Successful loading to trimming transition
- **WHEN** user selects a video from PhotosPicker
- **THEN** the system SHALL transition through states: ready → loadingVideo → trimming without race conditions
- **AND** loading progress SHALL be reported consistently (0% → 100% monotonic)
- **AND** state transitions SHALL be atomic with no competing actors

#### Scenario: Loading completion handling
- **WHEN** VideoLoadingService completes successfully
- **THEN** the system SHALL coordinate a single atomic transition to trimming state
- **AND** all loading-related actors SHALL be properly synchronized
- **AND** UI SHALL update to trimming interface without blocking

#### Scenario: State transition error recovery
- **WHEN** a state transition is blocked or fails
- **THEN** the system SHALL implement fallback mechanisms
- **AND** SHALL log detailed diagnostic information
- **AND** SHALL attempt recovery within timeout bounds

## ADDED Requirements

### Requirement: iOS 18.0 Actor-Based State Coordination
The system SHALL implement Swift 6.0 actor-based coordination with async/await patterns for loading→trimming state transitions.

#### Scenario: Actor-based transition coordination
- **WHEN** multiple actors attempt state transitions
- **THEN** the VideoLoadingStateActor SHALL serialize transitions atomically using @MainActor isolation
- **AND** SHALL prevent "Already transitioning" errors through actor serialization
- **AND** SHALL maintain transition ordering guarantees with structured concurrency

#### Scenario: Async/await AVAsset loading
- **WHEN** loading video assets from PhotosPicker
- **THEN** the system SHALL use await asset.load(.duration) instead of deprecated synchronous properties
- **AND** SHALL implement proper async/await error propagation
- **AND** SHALL support Task cancellation for loading timeouts

#### Scenario: Progress reporting with AsyncStream
- **WHEN** loading progresses through phases
- **THEN** progress percentages SHALL be monotonic (never decrease)
- **AND** SHALL use AsyncStream for real-time progress updates
- **AND** SHALL maintain async context throughout the loading pipeline

### Requirement: State Validation and Recovery
The system SHALL validate state consistency and implement recovery mechanisms.

#### Scenario: State consistency validation
- **WHEN** state transitions occur
- **THEN** the system SHALL validate state consistency
- **AND** SHALL detect and report inconsistencies
- **AND** SHALL attempt automatic recovery when possible

#### Scenario: Timeout handling
- **WHEN** transitions exceed timeout bounds
- **THEN** the system SHALL force cleanup and reset
- **AND** SHALL provide user feedback about the failure
- **AND** SHALL return to a known stable state