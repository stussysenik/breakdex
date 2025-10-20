## MODIFIED Requirements

### Requirement: Video Loading State Progression
The video loading system SHALL maintain monotonic progress from 0% to 100% without regressive state transitions during async operations.

#### Scenario: Video selection completes loading
- **WHEN** user selects a video from PhotosPicker
- **AND** async loading completes successfully
- **THEN** loading progress SHALL reach 100%
- **AND** UI SHALL advance to trimming interface
- **AND** SharedVideoPlayer SHALL be initialized

#### Scenario: State synchronization during async loading
- **WHEN** loading progress updates occur during async operations
- **THEN** state references SHALL use live current state
- **NOT** stale captured state from before async operation
- **AND** progress SHALL always be monotonic (never decrease)

## ADDED Requirements

### Requirement: Stale State Prevention
The system SHALL prevent stale state references across async boundaries by using live state references at decision points.

#### Scenario: State decision after async operation
- **WHEN** async loading operation completes
- **AND** system needs to make state-based decisions
- **THEN** system SHALL use current state values
- **NOT** state values captured before async operation began

### Requirement: Minimal State Diagnostics
The system SHALL provide minimal logging to verify state timing and prevent future stale state issues.

#### Scenario: State timing verification
- **WHEN** debugging loading state issues
- **THEN** logs SHALL show state capture vs usage timing
- **AND** logs SHALL clearly indicate stale vs live state values
- **AND** logs SHALL show decision outcomes based on state values

## REMOVED Requirements

### Requirement: Regressive AssetReady Transition
**Reason**: The assetReady transition from 88% to 60% causes state regression and loading hang
**Migration**: Remove assetReady transition when progress ≥ 60%, proceed directly to completion