## MODIFIED Requirements
### Requirement: Navigation Stack Hierarchy
The application SHALL maintain a single NavigationStack instance per navigation context to prevent navigation conflicts while supporting interactive list row actions.

#### Scenario: Combo Detail Navigation with Swipe Actions
- **WHEN** user taps on a combo in ComboListView
- **THEN** the app SHALL navigate to ComboDetailView using direct NavigationLink
- **AND** swipe actions SHALL remain functional on the combo row
- **AND** `🎯 COMBO_DETAIL_VIEW: 🚀 View appeared` log SHALL be generated
- **AND** navigation SHALL complete without returning to the previous view

#### Scenario: Navigation Stack Consistency with Interactive Elements
- **WHEN** both MoveListView and ComboListView are children of BreakingArsenalView
- **THEN** both SHALL use the same parent NavigationStack from BreakingArsenalView
- **AND** both SHALL follow identical direct NavigationLink navigation patterns
- **AND** both SHALL support swipe actions without navigation conflicts
- **AND** no nested NavigationStack conflicts SHALL exist

## ADDED Requirements
### Requirement: Navigation and Swipe Action Integration
The application SHALL support both navigation and swipe actions on the same list row without conflicts.

#### Scenario: NavigationLink with SwipeActions
- **WHEN** a NavigationLink row has swipeActions modifier applied
- **THEN** tap gestures SHALL trigger navigation to detail view
- **AND** swipe gestures SHALL trigger configured swipe actions
- **AND** both gesture types SHALL work independently without interference
- **AND** haptic feedback SHALL be appropriate for each interaction type

#### Scenario: Accessibility Navigation with Swipe Actions
- **WHEN** VoiceOver is enabled on list rows with swipe actions
- **THEN** standard VoiceOver swipe gestures SHALL be preserved
- **AND** custom swipe actions SHALL be discoverable via VoiceOver
- **AND** accessibility labels SHALL clearly indicate available actions
- **AND** alternative interaction methods SHALL be available for users who can't swipe