## MODIFIED Requirements
### Requirement: Asset Loading State Transitions
The system SHALL maintain monotonic progress during video loading state transitions and SHALL NOT attempt regressive transitions that would decrease displayed progress percentage.

#### Scenario: High progress asset creation
- **WHEN** video loading reaches creatingAsset stage with progress ≥ 60%
- **THEN** the system SHALL skip the regressive assetReady (60%) state transition
- **AND** SHALL proceed directly to player initialization maintaining current progress

#### Scenario: Low progress asset creation
- **WHEN** video loading reaches creatingAsset stage with progress < 60%
- **THEN** the system SHALL transition through assetReady state normally
- **AND** SHALL maintain standard progression sequence

#### Scenario: Transition decision logging
- **WHEN** the system evaluates assetReady transition
- **THEN** the system SHALL log current progress percentage
- **AND** SHALL log whether assetReady transition was taken or skipped
- **AND** SHALL log the chosen transition path for diagnostic purposes

## ADDED Requirements
### Requirement: Monotonic Progress Validation
The system SHALL validate that all state transitions maintain or increase progress percentage to ensure user-perceived loading always moves forward.

#### Scenario: Progress validation
- **WHEN** any state transition is attempted
- **THEN** the system SHALL verify target progress ≥ source progress
- **AND** SHALL reject transitions that would decrease progress
- **AND** SHALL log rejected transitions with progress values for debugging