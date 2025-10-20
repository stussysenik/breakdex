## MODIFIED Requirements
### Requirement: Atomic Stage-Progress Synchronization
The video loading system SHALL maintain atomic synchronization between stage transitions and progress updates to eliminate race conditions causing incorrect progress display.

#### Scenario: Stage transition without progress mismatch
- **WHEN** video loader progresses from one stage to the next
- **THEN** stage and progress SHALL update atomically as a single operation
- **AND** UI SHALL display correct progress percentage matching the actual loading state

#### Scenario: Cancel-trim-select-new-clip workflow
- **WHEN** user cancels trimming and selects a new video clip
- **THEN** loading progress SHALL display accurate percentages throughout all stages
- **AND** no stage synchronization lag SHALL occur between loader and UI

#### Scenario: MainActor isolation for state updates
- **WHEN** loading state changes occur
- **THEN** all @Published property updates SHALL happen on @MainActor
- **AND** state transitions SHALL be atomic and thread-safe

## ADDED Requirements
### Requirement: Stage Synchronization Diagnostics
The loading system SHALL provide minimal diagnostic logging to track stage transition timing and identify synchronization issues.

#### Scenario: Stage transition timing verification
- **WHEN** stage transitions occur
- **THEN** system SHALL log stage name, progress percentage, and timestamp
- **AND** logs SHALL help identify any remaining synchronization gaps

#### Scenario: Race condition detection
- **WHEN** potential race conditions are detected
- **THEN** system SHALL log diagnostic information about the timing mismatch
- **AND** logs SHALL provide actionable insights for debugging