## MODIFIED Requirements

### Requirement: Accurate Progress Display During Video Loading
The system SHALL display consistent and accurate progress throughout the video loading process, ensuring users see the correct percentage at each stage and immediate transition to the trimming interface upon completion.

#### Scenario: Progress calculation consistency
- **WHEN** AddMoveViewModel sets loading state with calculated progress (95% → 99% → 100%)
- **THEN** SelectClip UI SHALL display the same calculated progress values to the user
- **AND** the raw stage-relative progress SHALL not be used for UI display

#### Scenario: Immediate transition to trimming
- **WHEN** video loading reaches 100% completion and state transitions to `fullyReady`
- **THEN** the system SHALL immediately transition to MinimalTrimmerView without delay
- **AND** users SHALL not see any "stuck" progress display

#### Scenario: Diagnostic logging visibility
- **WHEN** progress values are observed in SelectClip
- **THEN** both raw progress and calculated progress SHALL be logged for debugging
- **AND** any discrepancies between progress sources SHALL be immediately visible in logs

#### Scenario: State observation consistency
- **WHEN** loading state changes occur in AddMoveViewModel
- **THEN** SelectClip SHALL observe the same state values that were set by the ViewModel
- **AND** UI display SHALL match the ViewModel's intended progress values

## ADDED Requirements

### Requirement: Progress Source Validation
The system SHALL validate that UI components observe the correct progress source to prevent display discrepancies.

#### Scenario: Progress source verification
- **WHEN** SelectClip observes loading progress
- **THEN** it SHALL use the calculated progress from LoadingState (newState.progress)
- **AND** SHALL NOT use the raw stage-relative progress parameter
- **AND** diagnostic logs SHALL show both values for verification