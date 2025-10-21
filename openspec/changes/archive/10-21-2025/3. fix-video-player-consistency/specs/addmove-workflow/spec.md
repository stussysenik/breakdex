# AddMove Workflow Specification

## ADDED Requirements

### Post-Save Navigation
**Requirement**: AddMoveView must properly navigate back to Arsenal tab after successfully saving a move.

#### Scenario: User completes move creation workflow
- **GIVEN** User has selected video, trimmed it, and named it
- **WHEN** User taps save and move is successfully saved
- **THEN** AddMoveView should navigate to Arsenal tab (selectedTab = 0)
- **AND** Navigation should be logged as successful
- **AND** Arsenal tab should display the newly created move immediately

#### Scenario: Workflow state management after save
- **GIVEN** Move save operation completes successfully
- **WHEN** Navigation to Arsenal tab occurs
- **THEN** AddMoveView should reset to ready state for next use
- **AND** Should not disappear or become inaccessible
- **AND** Enhanced logging should confirm "WORKFLOW_PROOF: AddMoveView reset successfully"

## MODIFIED Requirements

### Navigation State Consistency
**Requirement**: Ensure AddMoveView maintains consistent state through navigation transitions.

#### Scenario: Tab navigation during add move workflow
- **GIVEN** User is in the middle of add move workflow
- **WHEN** User switches tabs and returns
- **THEN** AddMoveView should maintain or properly restore workflow state
- **AND** Should not lose video selection or trim data
- **AND** Enhanced logging should track state preservation

#### Scenario: Error recovery and navigation
- **GIVEN** Move save operation fails
- **WHEN** Error occurs during save process
- **THEN** User should remain in AddMoveView with error message
- **AND** Should be able to retry save operation
- **AND** Navigation should not be triggered on save failure

