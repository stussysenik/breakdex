## MODIFIED Requirements

### Requirement: TabView Navigation Binding
The system SHALL provide mutable TabView navigation bindings to enable proper workflow navigation between parent and child views.

#### Scenario: Child view triggers parent navigation
- **WHEN** AddMoveView completes move saving successfully
- **THEN** the system SHALL update selectedTab to 0 to return to Arsenal tab
- **AND** the navigation SHALL occur without user interaction

#### Scenario: Navigation state consistency
- **WHEN** MainView selectedTab changes
- **THEN** AddMoveView SHALL receive the updated binding value
- **AND** state SHALL remain synchronized between parent and child views

#### Scenario: Navigation error handling
- **WHEN** navigation binding fails to update
- **THEN** the system SHALL log the error for debugging
- **AND** provide fallback navigation options

### Requirement: Child View Navigation Permission
The system SHALL allow child views to modify parent TabView state when workflow completion requires returning to a different tab.

#### Scenario: Workflow completion navigation
- **WHEN** add move workflow completes successfully
- **THEN** AddMoveView SHALL be able to modify MainView.selectedTab
- **AND** navigation SHALL return user to Arsenal tab automatically
- **AND** Arsenal tab SHALL immediately display the newly created move in the embedded move list

#### Scenario: Type consistency
- **WHEN** passing navigation bindings between views
- **THEN** binding types SHALL match between parent and child
- **AND** no implicit type conversions SHALL occur

#### Scenario: Arsenal view integration navigation
- **WHEN** user taps "ADD MOVE" button in embedded MoveListView
- **THEN** MoveListView SHALL be able to modify MainView.selectedTab
- **AND** navigation SHALL transition to AddMoveView with fresh workflow state
- **AND** selectedTab binding SHALL remain consistent across all navigation transitions

## ADDED Requirements

### Requirement: NameMoveView Color Scheme
The system SHALL display NameMoveView with consistent .light color scheme matching the app design system.

#### Scenario: Light theme consistency
- **WHEN** NameMoveView appears during add move workflow
- **THEN** background SHALL use Color.backgroundPrimary instead of hardcoded black
- **AND** text SHALL use Color.textPrimary for primary text elements
- **AND** text SHALL use Color.textSecondary for secondary text elements

### Requirement: Video Rotation Inheritance
The system SHALL preserve video rotation settings throughout the add move workflow from trimming to naming.

#### Scenario: Rotation state preservation
- **WHEN** user sets video rotation in MinimalTrimmerView
- **THEN** NameMoveView SHALL display the video with the same rotation
- **AND** rotation SHALL be consistent between trimming and naming views

#### Scenario: Rotation data propagation
- **WHEN** transitioning from trimming to naming view
- **THEN** rotation metadata SHALL be passed between views
- **AND** video display SHALL immediately show correct orientation

### Requirement: Navigation Diagnostic Logging
The system SHALL provide minimal diagnostic logging for navigation state changes to aid in debugging.

#### Scenario: Navigation state logging
- **WHEN** navigation binding values change
- **THEN** the system SHALL log the state transition
- **AND** include current and previous binding values

#### Scenario: Navigation failure logging
- **WHEN** navigation updates fail or timeout
- **THEN** the system SHALL log the failure details
- **AND** include binding status and error context