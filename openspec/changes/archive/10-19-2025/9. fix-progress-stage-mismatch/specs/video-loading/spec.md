## MODIFIED Requirements
### Requirement: Stage-Aware Progress Synchronization
The video loading system SHALL maintain synchronized stage and progress information throughout the loading pipeline to prevent stuck progress states.

#### Scenario: Progress update with matching stage information
- **WHEN** RobustVideoLoader updates progress during video loading
- **THEN** progress updates SHALL include the current loading stage
- **AND** AddMoveViewModel SHALL receive matching (progress, stage) pairs
- **AND** progress validation SHALL accept synchronized stage-progress updates

#### Scenario: Final state transition completion
- **WHEN** video loading reaches creatingAsset stage at 88% progress
- **THEN** system SHALL transition to fullyReady state at 100% progress
- **AND** progress validation SHALL accept this final transition
- **AND** UI SHALL display 100% completion

#### Scenario: Cancel-trim-select-new-clip workflow
- **WHEN** user cancels trimming and selects a new video clip
- **THEN** loading progress SHALL advance from 0% to 100% through all stages
- **AND** no stage-progress mismatches SHALL occur
- **AND** loading SHALL complete successfully at 100%

## ADDED Requirements
### Requirement: Stage Synchronization Diagnostics
The loading system SHALL provide minimal diagnostic logging to track stage-progress synchronization and identify mismatches.

#### Scenario: Stage-progress mismatch detection
- **WHEN** a progress update arrives with mismatched stage information
- **THEN** system SHALL log diagnostic information about the mismatch
- **AND** logs SHALL include expected vs actual (progress, stage) pairs
- **AND** logs SHALL help identify synchronization issues

#### Scenario: Final transition verification
- **WHEN** the final creatingAsset → fullyReady transition occurs
- **THEN** system SHALL log successful completion at 100% progress
- **AND** logs SHALL confirm stage synchronization is maintained
- **AND** logs SHALL provide verification of reliable loading completion