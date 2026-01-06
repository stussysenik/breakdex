## ADDED Requirements

### Requirement: Simple Video Timeline Interface
The system SHALL provide a clean, minimal video trimming interface with drag handles for setting start and end points.

#### Scenario: User adjusts trim range
- **WHEN** user drags left handle
- **THEN** start time updates visually and numerically
- **WHEN** user drags right handle
- **THEN** end time updates visually and numerically
- **WHEN** user taps play button
- **THEN** video plays from trim start to trim end

#### Scenario: Visual timeline interaction
- **WHEN** user views timeline
- **THEN** video thumbnail strip shows full video content
- **WHEN** user drags handles
- **THEN** trim range is highlighted with clear visual indication
- **WHEN** user drags handles precisely
- **THEN** trim updates with millisecond-level precision
- **WHEN** user scrubs timeline
- **THEN** video preview updates in real-time with precise frame accuracy

### Requirement: Essential Trimming Controls
The system SHALL provide minimal controls for the trimming workflow.

#### Scenario: User completes trim
- **WHEN** user has set valid trim range
- **THEN** "Next" button becomes enabled
- **WHEN** user taps "Next"
- **THEN** proceed to rotation workflow
- **WHEN** user taps "Cancel"
- **THEN** return to video selection

#### Scenario: User previews trim
- **WHEN** user taps play button
- **THEN** video plays only the selected trim range
- **WHEN** video reaches trim end
- **THEN** playback stops and returns to trim start position

### Requirement: Rotation Workflow Integration
The system SHALL integrate video rotation into the trimming workflow with instant visual feedback.

#### Scenario: User rotates video
- **WHEN** user taps rotation button
- **THEN** show rotation options (90°, 180°, 270°, 360°)
- **WHEN** user selects rotation option
- **THEN** video preview updates instantly with smooth animation
- **WHEN** user changes rotation
- **THEN** trim preview maintains current selection with new orientation
- **WHEN** user confirms rotation
- **THEN** proceed to naming workflow

### Requirement: Trim Validation
The system SHALL validate trim selections before allowing progression.

#### Scenario: Invalid trim range
- **WHEN** user selects trim duration less than 3 seconds
- **THEN** show "Minimum 3 seconds required" message
- **WHEN** user selects trim range exceeding video bounds
- **THEN** automatically constrain to valid range
- **WHEN** trim range is valid
- **THEN** enable progression to next step

### Requirement: Universal Frame Rate Handling
The system SHALL provide frame-accurate trimming regardless of video frame rate or variable frame rate content.

#### Scenario: Frame-accurate timeline interaction
- **WHEN** video loads with any frame rate (24fps, 30fps, 60fps, 120fps, VFR)
- **THEN** system detects and adapts to actual video frame rate
- **WHEN** user drags trim handles
- **THEN** interface responds with smooth updates regardless of frame rate
- **WHEN** user performs precise trim adjustments
- **THEN** time display shows both timecode (HH:MM:SS:FF) and milliseconds
- **WHEN** user scrubs timeline
- **THEN** video seeks to exact frame boundaries with proper timecode calculation
- **WHEN** video has variable frame rate
- **THEN** system calculates accurate timecode from presentation timestamps

#### Scenario: Timecode calculation accuracy
- **WHEN** video has non-standard frame rate (23.976fps, 29.97fps, etc.)
- **THEN** system calculates drop-frame timecode when appropriate
- **WHEN** user trims frame boundaries
- **THEN** trim points align with actual video frames, not arbitrary milliseconds
- **WHEN** user zooms timeline
- **THEN** frame accuracy is maintained at all zoom levels

## REMOVED Requirements

### Requirement: Complex Category Theory State Management
**Reason**: Over-engineered abstractions that added unnecessary complexity without user value.
**Migration**: Replace with simple @State properties for trim range and interaction state.

### Requirement: Precision Trimming Controls
**Reason**: Advanced precision features (magnetic snapping, frame-level precision) made interface unusable.
**Migration**: Use simple 1-second snap points with visual feedback.

### Requirement: Comprehensive Diagnostic Logging
**Reason**: Excessive logging created noise and performance overhead.
**Migration**: Keep essential error logging only for debugging critical issues.