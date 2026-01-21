## ADDED Requirements

### Requirement: Visually Harmonious Timeline Layout
The system SHALL align the timeline width with the video player preview edges to create visual harmony and spatial relationship between content and controls.

#### Scenario: Timeline alignment with video preview
- **WHEN** user views the trimming interface
- **THEN** timeline width SHALL match video player preview width
- **AND** consistent margins SHALL be maintained on both sides
- **AND** timeline SHALL not extend to screen edges

#### Scenario: Responsive layout across screen sizes
- **WHEN** app runs on different iOS devices
- **THEN** timeline-video alignment SHALL be maintained
- **AND** proportions SHALL remain consistent across screen sizes
- **AND** safe area boundaries SHALL be respected

### Requirement: Edge-Anchored Trim Controls
The system SHALL provide edge-anchored trim controls instead of floating handles for improved precision and spatial grounding.

#### Scenario: Precise trim handle positioning
- **WHEN** user drags trim handles
- **THEN** handles SHALL be visually anchored to timeline edges
- **AND** drag operations SHALL provide haptic feedback
- **AND** handles SHALL stay within defined timeline boundaries
- **AND** trim range SHALL be visually highlighted

#### Scenario: Handle constraint enforcement
- **WHEN** user drags handles beyond valid ranges
- **THEN** handles SHALL stop at minimum duration constraint (3 seconds)
- **AND** handles SHALL not overlap
- **AND** handles SHALL stay within video duration bounds
- **AND** visual feedback SHALL indicate constraint violations

### Requirement: Direct Rotation Manipulation
The system SHALL provide immediate 90-degree video rotation on button tap without requiring modal interaction.

#### Scenario: Immediate rotation on tap
- **WHEN** user taps rotation button
- **THEN** video SHALL rotate 90 degrees clockwise immediately
- **AND** rotation SHALL be reflected in video preview
- **AND** rotation state SHALL persist in trim modification
- **AND** visual feedback SHALL show current rotation angle

#### Scenario: Continuous rotation support
- **WHEN** user taps rotation button multiple times
- **THEN** each tap SHALL rotate additional 90 degrees
- **AND** rotation SHALL cycle through all four angles (0°, 90°, 180°, 270°)
- **AND** video preview SHALL update smoothly for each rotation

### Requirement: Clean Visual Timeline
The system SHALL remove unnecessary visual indicators to create a clean, focused trimming interface.

#### Scenario: Uncluttered timeline display
- **WHEN** user views the timeline
- **THEN** red playhead indicator SHALL not be displayed
- **AND** timeline SHALL show only essential trim controls
- **AND** selected range SHALL be clearly highlighted
- **AND** timecode displays SHALL provide temporal context

#### Scenario: Visual feedback through video preview
- **WHEN** video is playing during trim preview
- **THEN** playback progress SHALL be visible only in video preview
- **AND** users SHALL see current playback position in main video
- **AND** timeline SHALL remain focused on trim range controls

### Requirement: Spatial Constraint Enforcement
The system SHALL enforce spatial boundaries for all timeline interactions to ensure components stay within intended layout areas.

#### Scenario: Timeline boundary enforcement
- **WHEN** timeline is rendered
- **THEN** timeline SHALL respect safe area margins
- **AND** timeline SHALL not touch screen edges
- **AND** all timeline components SHALL stay within defined bounds
- **AND** layout SHALL be consistent with video preview alignment

#### Scenario: Handle drag boundary constraints
- **WHEN** user drags trim handles
- **THEN** handle movement SHALL be constrained to timeline area
- **AND** handles SHALL not extend beyond timeline edges
- **AND** drag gestures SHALL stop at valid boundary positions
- **AND** visual feedback SHALL indicate boundary positions

### Requirement: Optimized Touch Targets
The system SHALL provide appropriately sized touch targets for all interactive elements following iOS 18 design guidelines.

#### Scenario: Comfortable touch interaction
- **WHEN** user interacts with trim controls
- **THEN** touch targets SHALL meet iOS minimum size requirements (44pt)
- **AND** controls SHALL provide visual feedback on touch
- **AND** gesture recognition SHALL be responsive and accurate
- **AND** haptic feedback SHALL confirm successful interactions

#### Scenario: Accessible interaction design
- **WHEN** users with accessibility needs interact with interface
- **THEN** all controls SHALL support VoiceOver navigation
- **AND** touch targets SHALL maintain accessibility requirements
- **AND** interaction patterns SHALL follow iOS accessibility guidelines
- **AND** alternative interaction methods SHALL be supported