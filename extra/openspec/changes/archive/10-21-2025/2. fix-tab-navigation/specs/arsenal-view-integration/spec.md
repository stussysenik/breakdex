## ADDED Requirements

### Requirement: Arsenal View Move List Integration
The system SHALL display the complete move list directly in the Arsenal tab for immediate visibility of all moves.

#### Scenario: New move visibility
- **WHEN** user completes add move workflow and returns to Arsenal tab
- **THEN** the newly created move SHALL appear immediately in the move list
- **AND** the move SHALL be displayed with correct name, learning state, and creation timestamp
- **AND** the move SHALL be tappable to view details with video playback

#### Scenario: Arsenal tab navigation
- **WHEN** user navigates to Arsenal tab
- **THEN** the system SHALL display MoveListView embedded in BreakingArsenalView
- **AND** the system SHALL provide search functionality for filtering moves
- **AND** the system SHALL provide "ADD MOVE" button for quick navigation to add workflow

#### Scenario: Move list functionality
- **WHEN** user views move list in Arsenal tab
- **THEN** each move SHALL display with name, learning state pill, and creation date
- **AND** tapping any move SHALL navigate to MoveDetailView with video playback
- **AND** swiping left on any move SHALL show delete option
- **AND** search functionality SHALL filter moves by name in real-time

### Requirement: Arsenal Navigation Architecture
The system SHALL provide seamless navigation between Arsenal components using the selectedTab binding.

#### Scenario: Cross-tab navigation
- **WHEN** user taps "ADD MOVE" in Arsenal tab
- **THEN** the system SHALL set selectedTab to 1 (Add Move tab index)
- **AND** the system SHALL navigate to AddMoveView with fresh workflow state
- **AND** the system SHALL maintain navigation consistency across all tabs

#### Scenario: Return navigation
- **WHEN** user completes add move workflow
- **THEN** the system SHALL automatically return to Arsenal tab (selectedTab = 0)
- **AND** the system SHALL refresh move list to show newly added move
- **AND** the system SHALL maintain proper state synchronization

### Requirement: Arsenal State Management
The system SHALL maintain proper state synchronization between Arsenal components and tab navigation.

#### Scenario: State consistency
- **WHEN** navigating between tabs or completing workflows
- **THEN** ArsenalViewModel SHALL maintain accurate move list state
- **AND** Core Data changes SHALL be immediately reflected in UI
- **AND** search state SHALL be preserved when returning to Arsenal tab

#### Scenario: Error handling
- **WHEN** video loading fails in MoveDetailView from Arsenal tab
- **THEN** the system SHALL display appropriate error messaging
- **AND** the system SHALL provide options to retry or navigate away
- **AND** the system SHALL maintain overall app stability

## MODIFIED Requirements

### Requirement: BreakingArsenalView Architecture
The system SHALL integrate MoveListView directly into BreakingArsenalView for comprehensive Arsenal functionality.

#### Scenario: Complete Arsenal view
- **WHEN** BreakingArsenalView appears
- **THEN** the system SHALL display embedded MoveListView as primary content
- **AND** the system SHALL provide prominent "ADD MOVE" button above move list
- **AND** the system SHALL maintain proper navigation hierarchy with NavigationStack

#### Scenario: Move list integration
- **WHEN** MoveListView is embedded in BreakingArsenalView
- **THEN** MoveListView SHALL retain all existing functionality (search, delete, navigation)
- **AND** MoveListView SHALL use selectedTab binding for navigation to AddMoveView
- **AND** MoveListView SHALL share viewContext with BreakingArsenalView