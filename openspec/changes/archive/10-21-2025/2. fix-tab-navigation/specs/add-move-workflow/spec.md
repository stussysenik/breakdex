## MODIFIED Requirements

### Requirement: Add Move Workflow Completion
The system SHALL complete the add move workflow by returning users to the Arsenal tab after successfully saving a move.

#### Scenario: Workflow completion navigation
- **WHEN** user completes move naming and saves successfully
- **THEN** the system SHALL automatically navigate back to Arsenal tab
- **AND** display the newly created move immediately in the embedded move list
- **AND** highlight or scroll to the newly created move for immediate visibility
- **AND** maintain consistent navigation state

#### Scenario: Save completion handling
- **WHEN** AddMoveViewModel.saveMove completes successfully
- **THEN** AddMoveView SHALL trigger navigation to Arsenal tab (selectedTab = 0)
- **AND** ArsenalViewModel SHALL refresh move list to include new move
- **AND** transition display to show complete workflow with immediate results

#### Scenario: Workflow state cleanup
- **WHEN** navigation back to Arsenal tab occurs
- **THEN** AddMoveView SHALL clean up temporary state
- **AND** release video player resources appropriately
- **AND** reset workflow state for next usage
- **AND** Arsenal tab SHALL display updated move list without requiring manual refresh

#### Scenario: Move creation feedback loop
- **WHEN** user completes add move workflow
- **THEN** the system SHALL provide immediate visual confirmation of move creation
- **AND** the new move SHALL appear in Arsenal tab with correct metadata
- **AND** the move SHALL be immediately tappable for video playback verification
- **AND** learning state SHALL be set to "NEW" as expected

### Requirement: Video Workflow State Synchronization
The system SHALL maintain synchronization between video player state and workflow navigation throughout the add move process.

#### Scenario: Player state coordination
- **WHEN** transitioning between workflow steps (ready → trimming → naming)
- **THEN** video player state SHALL remain consistent
- **AND** rotation settings SHALL be preserved
- **AND** video SHALL remain loaded without interruption

#### Scenario: State persistence during navigation
- **WHEN** workflow is suspended and resumed
- **THEN** video player state SHALL be preserved
- **AND** trim settings SHALL be maintained
- **AND** rotation SHALL be restored correctly