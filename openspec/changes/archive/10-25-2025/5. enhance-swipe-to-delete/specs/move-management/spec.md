## ADDED Requirements
### Requirement: Move Swipe-to-Delete Actions
The application SHALL provide swipe-to-delete functionality for individual moves in the move list with proper data integrity safeguards.

#### Scenario: Move Deletion via Swipe Action
- **WHEN** user swipes left on any move in MoveListView
- **THEN** a red "Delete" button SHALL appear with appropriate haptic feedback
- **AND** tapping delete SHALL remove the move from Core Data
- **AND** the move SHALL be removed from all combos that reference it
- **AND** the UI SHALL update immediately to reflect the deletion
- **AND** appropriate logging SHALL be generated for debugging

#### Scenario: Move Deletion Confirmation
- **WHEN** user taps the delete button on a move
- **THEN** a confirmation alert SHALL appear warning about combo impact
- **AND** the alert SHALL display which combos will be affected
- **AND** user SHALL confirm deletion before it's executed
- **AND** deletion SHALL be cancelled if user dismisses the alert

#### Scenario: Move Deletion Error Handling
- **WHEN** move deletion fails due to Core Data errors
- **THEN** an error message SHALL be displayed to the user
- **AND** the move SHALL remain in the list
- **AND** detailed error information SHALL be logged
- **AND** the app SHALL remain stable and functional

#### Scenario: Undo Move Deletion
- **WHEN** a move is successfully deleted
- **THEN** an undo notification SHALL appear for 5 seconds
- **AND** tapping undo SHALL restore the move and all its relationships
- **AND** the undo notification SHALL include countdown timer
- **AND** undo SHALL be unavailable after the notification expires

### Requirement: Move Swipe Action Accessibility
The application SHALL provide accessible swipe-to-delete functionality for users with accessibility needs.

#### Scenario: VoiceOver Swipe Actions
- **WHEN** VoiceOver is enabled and user focuses on a move row
- **THEN** VoiceOver SHALL announce "Swipe left for actions"
- **AND** standard VoiceOver swipe gestures SHALL trigger swipe actions
- **AND** alternative buttons SHALL be available for users who can't swipe
- **AND** all actions SHALL have appropriate accessibility labels

#### Scenario: Switch Control and Motor Accessibility
- **WHEN** Switch Control or other motor accessibility features are enabled
- **THEN** swipe actions SHALL be available via alternative input methods
- **AND** all swipe actions SHALL be assignable to switches
- **AND** deletion confirmation SHALL work with alternative input methods