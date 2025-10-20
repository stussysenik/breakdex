## MODIFIED Requirements

### Requirement: Loading State Propagation
UI components SHALL require full state propagation before transitioning.

#### Scenario: Complete state readiness
- **WHEN** video loading completes asset stage
- **AND** player initialization completes
- **THEN** UI transitions only after `.fullyReady` state is achieved

### Requirement: Loading Interface Architecture
The system SHALL provide a single unified loading interface across all loading stages.

#### Scenario: Seamless transition
- **WHEN** SelectClip shows loading progress from 0-100%
- **THEN** MinimalTrimmerView appears directly without additional loading overlays
- **AND** video is immediately ready for trimming operations