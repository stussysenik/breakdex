## ADDED Requirements

### Requirement: Visual Video Trimming Interface
The system SHALL provide a spatially-organized video trimming interface with proper visual hierarchy and functional interactive controls.

#### Scenario: Interface layout and spacing
- **WHEN** user views the MinimalTrimmerView
- **THEN** video player and timecode displays are centered in a vertical section with 16pt spacing
- **AND** timeline with handles is positioned in a separate section below with 8pt vertical spacing
- **AND** all components stay within screen bounds with proper safe area insets

#### Scenario: Interactive timeline controls
- **WHEN** user drags left or right handles
- **THEN** trim range updates in real-time with visual feedback
- **AND** video seeks to the new handle position
- **AND** handles cannot exceed timeline boundaries or violate minimum duration

#### Scenario: Playhead visualization
- **WHEN** video plays or user seeks
- **THEN** centered playhead indicator shows current position on timeline
- **AND** playhead moves smoothly with video playback
- **AND** playhead stays within the trim range during looped playback

### Requirement: Trim Range Validation and Feedback
The system SHALL validate trim ranges and provide clear visual feedback for user actions.

#### Scenario: Minimum duration enforcement
- **WHEN** user selects trim range less than 3 seconds
- **THEN** error message displays "Minimum duration is 3 seconds"
- **AND** submit button remains disabled
- **AND** visual indicator shows invalid range

#### Scenario: Successful trim selection
- **WHEN** user selects valid trim range (≥3 seconds)
- **THEN** start/end timecodes display accurately
- **AND** duration shows in accent color
- **AND** submit button becomes enabled

### Requirement: Navigation Flow Integration
The system SHALL provide seamless navigation from trimming to move naming with proper state management.

#### Scenario: Submit to naming workflow
- **WHEN** user taps submit with valid trim range
- **THEN** TrimModification is created with start/end times and rotation
- **AND** UnifiedState updates with trim data
- **AND** navigation transitions to NameMoveView
- **AND** video loading state preserves for naming workflow

#### Scenario: Cancel and reset
- **WHEN** user cancels trimming
- **THEN** state returns to video selection
- **AND** temporary trim data is cleared
- **AND** user can re-select video without app restart

## MODIFIED Requirements

### Requirement: Video Player Integration
The video player SHALL be properly integrated with trim controls for real-time preview and interaction.

#### Scenario: Play/pause synchronization
- **WHEN** user taps play/pause button
- **THEN** SharedVideoPlayer state updates immediately
- **AND** playhead position reflects actual video time
- **AND** trim range boundaries are respected during playback

#### Scenario: Handle seeking behavior
- **WHEN** user drags timeline handles
- **THEN** video seeks smoothly to new position
- **AND** playback pauses if currently playing
- **AND** seek completes before handle drag ends