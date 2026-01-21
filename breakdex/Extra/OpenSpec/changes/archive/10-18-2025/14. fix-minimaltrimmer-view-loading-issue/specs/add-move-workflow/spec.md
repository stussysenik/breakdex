## MODIFIED Requirements
### Requirement: Add Move Workflow State Transitions
The system SHALL provide reliable state transitions from video selection through trimming with comprehensive diagnostic logging to identify bottlenecks.

#### Scenario: Video selection to trimming transition
- **WHEN** SelectClip component reaches .fullyReady state
- **AND** user confirms video selection
- **THEN** AddMoveViewModel updates currentStep to trimming
- **AND** AddMoveView body recomposes with trimming case
- **AND** MinimalTrimmerView rendering attempt is logged
- **AND** MinimalTrimmerView.onAppear confirmation is logged

#### Scenario: Diagnostic logging throughout workflow
- **WHEN** AddMoveView prepares to render MinimalTrimmerView
- **THEN** preparation logging includes video player state and selected video metadata
- **AND** any delays in view rendering are logged with timing information
- **AND** successful view appearance is confirmed with lifecycle logging