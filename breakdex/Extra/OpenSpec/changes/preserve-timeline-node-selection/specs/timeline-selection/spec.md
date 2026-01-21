## MODIFIED Requirements

### Requirement: Timeline View Appearance Logic
ComboTimelineView.handleViewAppear() SHALL preserve existing timeline selections instead of auto-selecting the first move.

#### Scenario: Preserve existing selection on view appear
- **WHEN** ComboTimelineView appears with an existing valid selection
- **THEN** the existing selection is preserved
- **AND** no auto-selection to index 0 occurs
- **AND** detailed logging confirms selection preservation

#### Scenario: Auto-select only when no valid selection exists
- **WHEN** ComboTimelineView appears with no valid selection
- **AND** the moves array is not empty
- **THEN** auto-select the first move (index 0)
- **AND** log the auto-selection action

## ADDED Requirements

### Requirement: Selection Validation
Timeline selection logic SHALL validate indices and handle edge cases gracefully.

#### Scenario: Handle invalid selection index
- **WHEN** the stored selection index is out of bounds
- **THEN** reset the selection to index 0
- **AND** log a warning about the invalid index
- **AND** ensure the combo has moves before selecting

#### Scenario: Handle empty moves array
- **WHEN** the combo contains no moves
- **THEN** no timeline node should be selected
- **AND** selection should remain nil
- **AND** no crashes should occur

### Requirement: Selection State Logging
Comprehensive logging SHALL be added for debugging selection state changes.

#### Scenario: Log selection state changes
- **WHEN** any timeline selection change occurs
- **THEN** detailed logs are written including:
  - Previous selection index (if any)
  - New selection index
  - Reason for change (user tap, auto-selection, restoration)
  - Move name associated with the selection

#### Scenario: Log view lifecycle events
- **WHEN** ComboTimelineView appears or disappears
- **THEN** logs are written indicating:
  - Current selection state
  - Whether auto-selection was triggered
  - Any selection validation results

### Requirement: Fullscreen Video Transition Persistence
Timeline selection SHALL survive fullscreen video player transitions without interruption.

#### Scenario: Fullscreen video entry and exit preservation
- **WHEN** timeline node at index N is selected
- **AND** user enters fullscreen video player
- **AND** user exits fullscreen video player
- **THEN** timeline node at index N remains selected
- **AND** video preview shows the same move's video
- **AND** no selection reset occurs

#### Scenario: Multiple fullscreen cycles persistence
- **WHEN** timeline node at index N is selected
- **AND** user enters and exits fullscreen video multiple times
- **THEN** timeline node at index N remains selected throughout all cycles
- **AND** selection persistence is consistent across all transitions