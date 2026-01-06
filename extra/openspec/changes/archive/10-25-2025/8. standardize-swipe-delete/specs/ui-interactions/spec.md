## ADDED Requirements
### Requirement: Standardized Swipe-to-Delete Interaction
The system SHALL provide consistent swipe-to-delete behavior across all list views (ComboListView and MoveListView).

#### Scenario: Swipe gesture reveals delete action
- **WHEN** user swipes left on any row in ComboListView or MoveListView
- **THEN** a red delete button shall appear from the trailing edge
- **AND** the swipe action shall allow full swipe to trigger immediate delete

#### Scenario: Delete action confirmation
- **WHEN** user taps the delete button in swipe actions
- **THEN** the item shall be deleted from the list
- **AND** haptic feedback shall be provided via MotionCatalog.Accessibility.actionHaptic()
- **AND** the deletion shall be animated smoothly

#### Scenario: Delete action feedback
- **WHEN** deletion is in progress
- **THEN** the UI shall show loading state if needed
- **AND** appropriate error handling shall be in place for failed deletions
- **AND** the list shall refresh to show updated content

## MODIFIED Requirements
### Requirement: Consistent List Component Behavior
Both ComboListView and MoveListView SHALL use consistent UI component patterns for list rendering and interaction.

#### Scenario: List rendering consistency
- **WHEN** displaying lists of items (combos or moves)
- **THEN** both views shall use the same underlying component pattern
- **AND** both shall support the same interaction behaviors
- **AND** visual styling shall be consistent between views

#### Scenario: Navigation behavior consistency
- **WHEN** user taps on list items
- **THEN** both views shall provide identical navigation feedback
- **AND** both shall use the same haptic feedback pattern
- **AND** both shall use SpringButtonStyle for consistent press animations