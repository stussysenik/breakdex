## ADDED Requirements
### Requirement: Move List Navigation
The system SHALL provide navigation from move list items to move detail view through native NavigationLink interaction.

#### Scenario: Move row tap navigation
- **WHEN** user taps on any move row in the move list
- **THEN** the system SHALL navigate to the MoveDetailView for that specific move
- **AND** haptic feedback SHALL be provided via MotionCatalog.Accessibility.selectionHaptic()
- **AND** the navigation SHALL be logged with move details

#### Scenario: Navigation destination handling
- **WHEN** NavigationLink value matches a Move object
- **THEN** the NavigationStack SHALL process the destination and present MoveDetailView
- **AND** the MoveDetailView SHALL receive the correct Move object
- **AND** appearance SHALL be logged with move ID and name

## MODIFIED Requirements
### Requirement: Move Row Interaction Hierarchy
Move rows SHALL support both navigation and swipe-to-delete interactions without gesture conflicts.

#### Scenario: Navigation without gesture conflict
- **WHEN** user taps on a move row (outside swipe action area)
- **THEN** NavigationLink SHALL receive the tap event and trigger navigation
- **AND** no conflicting gesture modifiers SHALL intercept the tap
- **AND** SpringButtonStyle SHALL provide visual press feedback

#### Scenario: Swipe-to-delete functionality preserved
- **WHEN** user swipes left on any move row
- **THEN** swipe actions SHALL be revealed from the trailing edge
- **AND** delete functionality SHALL work as expected
- **AND** haptic feedback SHALL be provided for delete action
- **AND** row deletion SHALL be animated smoothly