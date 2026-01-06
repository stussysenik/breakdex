## ADDED Requirements
### Requirement: Move List Swipe-to-Delete
The system SHALL provide swipe-to-delete functionality for moves in MoveListView matching the UX pattern established in ComboListView.

#### Scenario: Swipe to delete move
- **WHEN** user swipes left on a move row in MoveListView
- **THEN** the system SHALL reveal a delete action button
- **AND** the delete button SHALL be styled consistently with ComboListView
- **AND** the button SHALL support full-swipe gesture for immediate deletion

#### Scenario: Confirm move deletion
- **WHEN** user taps the delete action or completes a full swipe
- **THEN** the system SHALL prompt for deletion confirmation
- **AND** SHALL provide haptic feedback matching ComboListView
- **AND** SHALL delete the move from Core Data after confirmation
- **AND** SHALL refresh the move list to remove the deleted item

#### Scenario: Delete move with error handling
- **WHEN** move deletion encounters an error
- **THEN** the system SHALL display an appropriate error message
- **AND** SHALL log the error with sufficient context
- **AND** SHALL not remove the move from the UI if Core Data deletion failed

## MODIFIED Requirements
### Requirement: Move List Touch Targets
The MoveListView SHALL provide responsive touch targets for navigation and ensure entire rows are properly tappable.

#### Scenario: Tap move row for navigation
- **WHEN** user taps anywhere on a move row in MoveListView
- **THEN** the system SHALL navigate to MoveDetailView for the selected move
- **AND** the entire row SHALL respond as a single touch target
- **AND** SHALL provide visual feedback during tap interaction

### Requirement: Move List Visual Consistency
The MoveListView SHALL maintain visual consistency with ComboListView design patterns.

#### Scenario: Display move information
- **WHEN** MoveListView displays move rows
- **THEN** the system SHALL use consistent styling with ComboListView
- **AND** SHALL display move name, creation date, and learning state pills
- **AND** SHALL maintain the same font, colors, and spacing patterns

#### Scenario: Show move learning state
- **WHEN** displaying a move with a learning state
- **THEN** the system SHALL show a StatePillView component
- **AND** the pill SHALL use the same styling as in ComboListView
- **AND** SHALL display appropriate colors for NEW, LEARNING, and MASTERY states

## REMOVED Requirements
### Requirement: Basic Move List Interaction
The system SHALL remove any redundant gesture handling or touch target limitations in the move list interface.

**Reason**: This capability is being replaced with enhanced touch target implementation that provides better UX and consistency with other list views.

**Migration**: All move list interactions will now be handled through improved NavigationLink implementation and swipe-to-delete functionality.