## ADDED Requirements

### Requirement: Combo Detail Video Player
The ComboDetailView SHALL provide a central video player that displays videos for moves selected via timeline nodes.

#### Scenario: Timeline node triggers video playback
- **WHEN** user taps a timeline node in ComboDetailView
- **THEN** the corresponding move's video loads and plays in the central video player

#### Scenario: Video loading state management
- **WHEN** video is loading from Photos library
- **THEN** loading indicator is displayed in video player area

#### Scenario: Video loading error handling
- **WHEN** video fails to load from Photos library
- **THEN** error state is displayed with appropriate error message

#### Scenario: Empty video player state
- **WHEN** ComboDetailView loads with no selected move
- **THEN** appropriate empty state is displayed in video player area

### Requirement: Timeline-Video Integration
The ComboDetailView SHALL synchronize timeline node selection with video player content.

#### Scenario: Timeline node selection updates video
- **WHEN** user selects different timeline node
- **THEN** video player switches to display the newly selected move's video

#### Scenario: Video player lifecycle management
- **WHEN** ComboDetailView appears/disappears
- **THEN** video player plays/pauses appropriately to manage resources

#### Scenario: Reactive video loading
- **WHEN** selected move changes (via photosIdentifier)
- **THEN** new video loads automatically using reactive SwiftUI patterns

### Requirement: Video Player State Management
The ComboDetailView SHALL maintain proper state for video loading, playback, and error conditions.

#### Scenario: Concurrent loading prevention
- **WHEN** video loading is in progress and user selects new move
- **THEN** previous loading is cancelled and new video loading begins

#### Scenario: Player resource cleanup
- **WHEN** switching between different videos
- **THEN** previous AVPlayer instance is properly cleaned up

#### Scenario: Loading progress indication
- **WHEN** video loading takes longer than expected
- **THEN** user sees loading progress with indication of activity