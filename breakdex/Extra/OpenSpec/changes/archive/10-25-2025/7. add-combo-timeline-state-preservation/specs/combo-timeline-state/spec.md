## ADDED Requirements
### Requirement: Timeline Node State Persistence
The system SHALL preserve the user's selected timeline node when saving a combo and restore it when viewing the saved combo.

#### Scenario: Save combo with selected timeline node
- **WHEN** user creates a combo and selects a timeline node
- **AND** user saves the combo
- **THEN** the system SHALL store the selected move's NSManagedObjectID in the combo's `activeMoveVideoReference` attribute
- **AND** the state SHALL be persisted to Core Data

#### Scenario: Restore timeline node state on combo view
- **WHEN** user opens a saved combo in ComboDetailView
- **AND** the combo has a saved timeline node state
- **THEN** the system SHALL restore the selected timeline node to the previously saved move
- **AND** the timeline SHALL auto-scroll to the restored node
- **AND** the restored node SHALL be visually highlighted as active

#### Scenario: Handle missing timeline node state
- **WHEN** user opens a saved combo without timeline node state
- **THEN** the system SHALL default to selecting the first timeline node (index 0)
- **AND** SHALL continue normal operation

#### Scenario: Timeline node state with deleted move
- **WHEN** user opens a saved combo where the saved timeline node state references a move no longer in the combo
- **THEN** the system SHALL default to selecting the first timeline node (index 0)
- **AND** SHALL log a warning about the missing move reference
- **AND** SHALL clear the invalid state reference

### Requirement: Timeline Node Video Navigation
The system SHALL provide video playback when users interact with timeline nodes in ComboDetailView.

#### Scenario: Navigate to video from timeline node
- **WHEN** user taps a timeline node in ComboDetailView
- **THEN** the system SHALL navigate to MoveDetailView for the selected move
- **AND** MoveDetailView SHALL load with full SharedVideoPlayer integration
- **AND** the video SHALL display with trim boundaries applied
- **AND** playback SHALL start automatically

#### Scenario: Navigate back from timeline node video
- **WHEN** user navigates back from MoveDetailView to ComboDetailView
- **THEN** the system SHALL return to the combo detail view
- **AND** the timeline SHALL maintain the previously selected node state
- **AND** the view SHALL scroll to show the selected node

## MODIFIED Requirements
### Requirement: Combo Creation State Management
The ComboViewModel SHALL manage the active timeline node state during combo creation and save it with the combo.

#### Scenario: Save combo with active timeline node
- **WHEN** user saves a combo with an active timeline node selection
- **THEN** the system SHALL convert the selected move's NSManagedObjectID to URI representation
- **AND** SHALL store the URI as Data in `combo.activeMoveVideoReference`
- **AND** SHALL include the state in the Core Data save operation
- **AND** SHALL log the successful state preservation