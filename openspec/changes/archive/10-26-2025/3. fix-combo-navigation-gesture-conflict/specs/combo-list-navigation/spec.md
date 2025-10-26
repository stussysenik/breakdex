## ADDED Requirements
### Requirement: Combo List Navigation
The system SHALL provide navigation from combo list items to combo detail view through native NavigationLink interaction.

#### Scenario: Combo row tap navigation
- **WHEN** user taps on any combo row in the combo list
- **THEN** the system SHALL navigate to the ComboDetailView for that specific combo
- **AND** haptic feedback SHALL be provided via MotionCatalog.Accessibility.selectionHaptic()
- **AND** the navigation SHALL be logged with combo details

#### Scenario: Navigation destination handling
- **WHEN** NavigationLink value matches a Combo object
- **THEN** the NavigationStack SHALL process the destination and present ComboDetailView
- **AND** the ComboDetailView SHALL receive the correct Combo object
- **AND** appearance SHALL be logged with combo ID and name

## MODIFIED Requirements
### Requirement: Combo Row Interaction Hierarchy
Combo rows SHALL support both navigation and swipe-to-delete interactions without gesture conflicts.

#### Scenario: Navigation without gesture conflict
- **WHEN** user taps on a combo row (outside swipe action area)
- **THEN** NavigationLink SHALL receive the tap event and trigger navigation
- **AND** no conflicting gesture modifiers SHALL intercept the tap
- **AND** SpringButtonStyle SHALL provide visual press feedback

#### Scenario: Swipe-to-delete functionality preserved
- **WHEN** user swipes left on any combo row
- **THEN** swipe actions SHALL be revealed from the trailing edge
- **AND** delete functionality SHALL work as expected
- **AND** haptic feedback SHALL be provided for delete action
- **AND** row deletion SHALL be animated smoothly

#### Scenario: Search filtering navigation compatibility
- **WHEN** combo list is filtered by search text
- **AND** user taps on any visible combo row
- **THEN** navigation SHALL work correctly for the filtered combo
- **AND** correct Combo object SHALL be passed to ComboDetailView
- **AND** navigation SHALL maintain search context