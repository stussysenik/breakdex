## ADDED Requirements

### Requirement: Automatic Video Aspect Ratio Detection
The video trimmer SHALL automatically detect and display videos in their native aspect ratio without forcing a fixed container ratio.

#### Scenario: Vertical video displays correctly
- **WHEN** a vertical video (9:16) is loaded from Photos app
- **THEN** the video container adopts vertical orientation and displays the full video without horizontal black bars
- **AND** the video appears in its natural aspect ratio from the first load

#### Scenario: Horizontal video displays correctly
- **WHEN** a horizontal video (16:9) is loaded from Photos app
- **THEN** the video container adopts horizontal orientation and displays the full video

#### Scenario: Square video displays correctly
- **WHEN** a square video (1:1) is loaded from Photos app
- **THEN** the video container adopts square orientation and displays the full video

#### Scenario: Custom aspect ratio video displays correctly
- **WHEN** a video with any aspect ratio (4:3, 21:9, etc.) is loaded
- **THEN** the video container adopts the video's exact aspect ratio automatically

### Requirement: Synchronized Video Component Rotation
The video trimmer SHALL rotate the entire video component (content + container) as a single synchronized unit when user applies rotation.

#### Scenario: 90-degree rotation affects entire component
- **WHEN** user taps rotate button while viewing video
- **THEN** the entire video component (player + container) rotates 90 degrees clockwise
- **AND** the aspect ratio container adjusts to match the rotated video dimensions

#### Scenario: Continuous rotation maintains synchronization
- **WHEN** user applies multiple rotations (90°, 180°, 270°, 0°)
- **THEN** the video component and container remain perfectly synchronized throughout all rotations
- **AND** no visual glitches or layout inconsistencies occur

#### Scenario: Rotation state persists during video loading
- **WHEN** video is loading or processing
- **THEN** rotation state remains consistent
- **AND** component maintains proper aspect ratio throughout loading process

### Requirement: Video Loading State Diagnostics
The video trimmer SHALL provide diagnostic logging for video loading, aspect ratio detection, and rotation state changes.

#### Scenario: Video loading diagnostics
- **WHEN** video asset is loaded from Photos app
- **THEN** system logs video dimensions, aspect ratio, and loading completion status
- **AND** logs include timestamp and video identifier for debugging

#### Scenario: Aspect ratio detection diagnostics
- **WHEN** aspect ratio is calculated from video track
- **THEN** system logs natural dimensions, detected aspect ratio, and container sizing decisions
- **AND** logs indicate successful or failed aspect ratio detection

#### Scenario: Rotation state diagnostics
- **WHEN** user applies rotation or rotation state changes
- **THEN** system logs rotation angle, component state, and animation completion
- **AND** logs track rotation synchronization status

## MODIFIED Requirements

### Requirement: Video Preview Display
The video trimmer SHALL display video preview with correct aspect ratio and synchronized rotation capability.

#### Scenario: Video preview loads with correct dimensions
- **WHEN** user transitions from video selection to trimming interface
- **THEN** video preview appears immediately with correct aspect ratio
- **AND** no horizontal black bars or container dimension mismatches occur
- **AND** loading states maintain proper video proportions

#### Scenario: Video preview supports interactive rotation
- **WHEN** user interacts with rotation controls in trimmer interface
- **THEN** video preview rotates smoothly with visual feedback
- **AND** rotation affects entire preview component as unified entity
- **AND** timeline and controls maintain proper spatial relationship

#### Scenario: Video preview maintains performance
- **WHEN** videos of any resolution or aspect ratio are loaded
- **THEN** preview performance remains responsive and smooth
- **AND** rotation operations complete within 300ms with fluid animation
- **AND** memory usage remains within acceptable limits

### Requirement: Trim Range Validation
The video trimmer SHALL validate trim ranges against video duration and aspect ratio constraints.

#### Scenario: Trim validation respects video dimensions
- **WHEN** user sets trim start and end points
- **THEN** validation uses actual video duration regardless of aspect ratio
- **AND** trim handles position correctly within video timeline bounds
- **AND** minimum duration requirements apply correctly to all video formats

#### Scenario: Trim preview shows correct video portion
- **WHEN** user adjusts trim handles on timeline
- **THEN** video preview displays the selected trim range accurately
- **AND** preview maintains correct aspect ratio during trim adjustments
- **AND** no distortion or cropping occurs in trim preview