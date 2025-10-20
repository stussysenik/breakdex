## ADDED Requirements

### Requirement: Default Trim Range Initialization
The video trimmer SHALL default to selecting the entire video duration from start to end when loaded.

#### Scenario: Video loaded with default trim range
- **WHEN** a video is loaded into the trimmer
- **THEN** the start handle SHALL be positioned at 00:00:00
- **AND** the end handle SHALL be positioned at the video's full duration
- **AND** the selected trim range SHALL cover the entire video

### Requirement: Handle Boundary Constraints
Trim handles SHALL remain fully within the visible timeline boundaries during all positioning operations.

#### Scenario: Handle positioning at timeline bounds
- **WHEN** the start handle is at the minimum position (00:00:00)
- **THEN** the handle's left edge SHALL align with the timeline's left edge
- **AND** the handle SHALL not extend beyond the timeline bounds

#### Scenario: Handle positioning at maximum bounds
- **WHEN** the end handle is at the maximum position (video duration)
- **THEN** the handle's right edge SHALL align with the timeline's right edge
- **AND** the handle SHALL not extend beyond the timeline bounds

### Requirement: Accurate Coordinate-to-Time Mapping
The trimmer SHALL maintain mathematically consistent mapping between time positions and visual coordinates.

#### Scenario: Time-to-coordinate conversion
- **WHEN** converting a time position to a visual coordinate
- **THEN** the coordinate SHALL account for handle width to keep handles within bounds
- **AND** the mapping SHALL be linear and proportional across the timeline

#### Scenario: Coordinate-to-time conversion
- **WHEN** converting a visual coordinate to a time position
- **THEN** the time SHALL accurately reflect the position within the video duration
- **AND** the conversion SHALL be the inverse of the time-to-coordinate function

## MODIFIED Requirements

### Requirement: Video Trim Range Selection
Users SHALL be able to select a video trim range by dragging start and end handles along a timeline.

#### Scenario: Initial trim range display
- **WHEN** the trimmer interface loads with a video
- **THEN** the start handle SHALL be positioned at the beginning of the video (00:00:00)
- **AND** the end handle SHALL be positioned at the end of the video (full duration)
- **AND** both handles SHALL be fully visible within the timeline bounds
- **AND** the selected range SHALL highlight the full video duration

#### Scenario: Handle drag interaction
- **WHEN** a user drags either handle along the timeline
- **THEN** the handle SHALL move smoothly along the timeline
- **AND** the handle SHALL remain fully within timeline boundaries at all positions
- **AND** the corresponding time display SHALL update in real-time
- **AND** minimum duration constraints SHALL be enforced during dragging