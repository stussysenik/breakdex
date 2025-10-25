## MODIFIED Requirements
### Requirement: Combo Swipe-to-Delete Actions
The application SHALL provide enhanced swipe-to-delete functionality for combos with immediate deletion, undo capability, and haptic feedback.

#### Scenario: Enhanced Combo Deletion via Swipe Action
- **WHEN** user swipes left on any combo in ComboListView
- **THEN** a red "Delete" button SHALL appear with selection haptic feedback
- **AND** tapping delete SHALL immediately remove the combo from Core Data
- **AND** action haptic feedback SHALL be provided on successful deletion
- **AND** the UI SHALL update immediately with smooth animation
- **AND** detailed logging SHALL be generated for debugging

#### Scenario: Combo Navigation with Enhanced Swipe Actions
- **WHEN** user taps on a combo row (not swipe action)
- **THEN** direct navigation to ComboDetailView SHALL be triggered
- **AND** swipe actions SHALL remain available and functional
- **AND** navigation and swipe gestures SHALL not interfere with each other
- **AND** `🎯 COMBO_DETAIL_VIEW: 🚀 View appeared` log SHALL be generated

## ADDED Requirements
### Requirement: Combo Deletion Undo System
The application SHALL provide a comprehensive undo system for accidental combo deletions with timed recovery.

#### Scenario: Immediate Undo Notification
- **WHEN** a combo is successfully deleted
- **THEN** an undo notification SHALL appear at the bottom of the screen
- **AND** the notification SHALL display "Combo deleted" with undo button
- **AND** a countdown timer SHALL show remaining time to undo (5 seconds)
- **AND** the notification SHALL automatically dismiss after countdown expires

#### Scenario: Combo Restoration via Undo
- **WHEN** user taps the undo button within the time window
- **THEN** the deleted combo SHALL be fully restored with all its relationships
- **AND** combo moves SHALL be restored in correct sequence
- **AND** the combo SHALL reappear in the list with smooth animation
- **AND** success feedback SHALL be provided to the user

#### Scenario: Undo Buffer Management
- **WHEN** multiple items are deleted in sequence
- **THEN** each deletion SHALL have its own undo window
- **AND** undo notifications SHALL stack appropriately
- **AND** undo buffer SHALL be cleared when app backgrounds
- **AND** memory management SHALL prevent buffer from growing indefinitely

### Requirement: Combo Swipe Action Enhancements
The application SHALL provide production-grade swipe action features for combos.

#### Scenario: Haptic Feedback Integration
- **WHEN** user initiates swipe gesture on combo row
- **THEN** light selection haptic feedback SHALL be provided
- **AND** when delete action is executed, action haptic feedback SHALL be provided
- **AND** when undo is successful, success haptic feedback SHALL be provided
- **AND** haptic intensity SHALL be appropriate for each interaction type

#### Scenario: Visual Feedback and Animation
- **WHEN** combo is deleted via swipe action
- **THEN** smooth removal animation SHALL be played
- **AND** surrounding items SHALL animate to fill the space
- **AND** list scrolling SHALL remain smooth during deletion
- **AND** visual feedback SHALL clearly indicate the action result

#### Scenario: Error Handling and Recovery
- **WHEN** combo deletion fails due to Core Data errors
- **THEN** the combo SHALL remain visible in the list
- **AND** an error message SHALL be displayed to the user
- **AND** detailed error information SHALL be logged for debugging
- **AND** the app SHALL remain stable and responsive

### Requirement: Shared Swipe Actions Component
The application SHALL implement a reusable swipe actions component for consistency across move and combo management.

#### Scenario: Component Reusability
- **WHEN** SwipeActionsComponent is used in different views
- **THEN** it SHALL support configurable action types (delete, edit, etc.)
- **AND** it SHALL maintain consistent visual styling across all uses
- **AND** it SHALL support customizable colors and icons
- **AND** it SHALL handle both haptic feedback and accessibility automatically

#### Scenario: Performance Optimization
- **WHEN** SwipeActionsComponent is used in large lists
- **THEN** it SHALL maintain smooth scrolling performance
- **AND** it SHALL efficiently manage gesture recognition
- **AND** it SHALL minimize memory usage per row
- **AND** it SHALL handle rapid swipe gestures without lag