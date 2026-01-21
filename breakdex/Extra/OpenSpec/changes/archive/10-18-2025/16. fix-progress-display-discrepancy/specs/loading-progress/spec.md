## MODIFIED Requirements

### Requirement: Progress Calculation Consistency
The system SHALL ensure that all UI components observe the same calculated progress values throughout the loading pipeline.

#### Scenario: Calculated progress observation
- **WHEN** LoadingState calculates progress using `baseProgress + (progress × weight)` formula
- **THEN** UI components SHALL observe the calculated result, not the raw stage-relative input
- **AND** the displayed progress SHALL accurately reflect the overall loading completion

#### Scenario: Stage transition visibility
- **WHEN** loading transitions between stages (preparingPlayback → finalizing → fullyReady)
- **THEN** users SHALL see smooth progression: 95% → 99% → 100%
- **AND** SHALL NOT observe raw stage-relative values like 0% during final stages

## ADDED Requirements

### Requirement: Progress Source Logging
The system SHALL provide diagnostic logging to identify progress source discrepancies.

#### Scenario: Progress tracking visibility
- **WHEN** SelectClip observes loading state changes
- **THEN** logs SHALL include both raw stage-relative progress and calculated absolute progress
- **AND** any mismatch between progress sources SHALL be immediately identifiable
- **AND** diagnostic information SHALL help resolve future display issues