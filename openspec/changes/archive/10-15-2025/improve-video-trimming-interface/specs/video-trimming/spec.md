## ADDED Requirements

### Requirement: Interactive Timeline with Visual Feedback
The system SHALL provide an interactive timeline component with clear visual feedback for trim range selection and playback position.

#### Scenario: Visual timeline interaction
- **WHEN** user views the trimming interface
- **THEN** timeline displays video thumbnails with proper aspect ratio
- **WHEN** user drags trim handles
- **THEN** trim range highlights with clear visual indication and smooth animations
- **WHEN** video plays
- **THEN** playhead moves smoothly across timeline with frame-accurate position
- **WHEN** user taps timeline
- **THEN** playhead jumps to tapped position with video preview update

#### Scenario: Zoom and precision control
- **WHEN** user pinches to zoom timeline
- **THEN** timeline smoothly zooms with maintained center point
- **WHEN** timeline is zoomed
- **THEN** trim handles provide millisecond-level precision control
- **WHEN** user makes precise adjustments
- **THEN** time display updates in real-time with millisecond accuracy

### Requirement: Mechanical Watch Precision Trimming
The system SHALL provide frame-accurate trimming with mechanical watch precision for movement analysis.

#### Scenario: Frame-accurate trimming
- **WHEN** user adjusts trim handles
- **THEN** trim points align with exact video frame boundaries
- **WHEN** video has variable frame rate
- **THEN** system calculates accurate timecode from presentation timestamps
- **WHEN** user requires precise timing
- **THEN** interface supports frame-level adjustments with visual feedback
- **WHEN** trimming complete
- **THEN** resulting clip maintains original frame accuracy without re-encoding

#### Scenario: Timecode display and calculation
- **WHEN** user interacts with timeline
- **THEN** time display shows both timecode (HH:MM:SS:FF) and milliseconds
- **WHEN** video has non-standard frame rate
- **THEN** system calculates drop-frame timecode when appropriate
- **WHEN** user selects trim range
- **THEN** duration display updates accurately with frame precision

### Requirement: Haptic and Audio Feedback
The system SHALL provide comprehensive haptic and audio feedback for enhanced user experience.

#### Scenario: Haptic feedback during trimming
- **WHEN** user drags trim handles
- **THEN** subtle haptic feedback provides tactile response
- **WHEN** trim handles snap to frame boundaries
- **THEN** gentle haptic confirmation indicates precise alignment
- **WHEN** user reaches trim limits
- **THEN** distinct haptic feedback indicates boundary reached
- **WHEN** trim operation completes
- **THEN** success haptic confirms operation completion

#### Scenario: Audio feedback for accessibility
- **WHEN** VoiceOver is enabled
- **THEN** audio cues indicate trim handle positions and adjustments
- **WHEN** trim range changes
- **THEN** spoken feedback announces new start/end times
- **WHEN** errors occur
- **THEN** clear audio messages explain validation issues

### Requirement: Comprehensive Accessibility Support
The system SHALL provide full accessibility support for inclusive user experience.

#### Scenario: VoiceOver navigation
- **WHEN** VoiceOver user navigates trimming interface
- **THEN** all controls have descriptive labels and hints
- **WHEN** user adjusts trim handles
- **THEN** VoiceOver announces precise position changes
- **WHEN** user interacts with timeline
- **THEN** semantic elements provide meaningful navigation structure
- **WHEN** playback controls are used
- **THEN** audio feedback indicates current playback state and position

#### Scenario: Switch Control and Keyboard Navigation
- **WHEN** switch control user operates trimming interface
- **THEN** all functions accessible via switch scanning
- **WHEN** keyboard navigation is used
- **THEN** tab order follows logical interaction flow
- **WHEN** external keyboard is connected
- **THEN** arrow keys provide precise trim adjustments
- **WHEN** spacebar is pressed
- **THEN** play/pause toggle functions correctly

### Requirement: Advanced Trim Validation
The system SHALL provide intelligent trim validation with helpful user guidance.

#### Scenario: Smart trim range validation
- **WHEN** user selects trim range less than 0.5 seconds
- **THEN** system suggests minimum viable range with visual guidance
- **WHEN** user selects very short range
- **THEN** system provides frame count and duration feedback
- **WHEN** trim range approaches video limits
- **THEN** visual indicators indicate available remaining duration
- **WHEN** invalid trim is attempted
- **THEN** clear, contextual error messages guide correction

#### Scenario: Content-aware validation
- **WHEN** video contains motion between trim points
- **THEN** system highlights active motion regions in timeline
- **WHEN** user trims during static periods
- **THEN** gentle suggestions highlight more meaningful segments
- **WHEN** trim range captures complete movement
- **THEN** positive reinforcement confirms good selection

### Requirement: Performance-Optimized Rendering
The system SHALL maintain 60fps performance across all device types and video formats.

#### Scenario: Smooth timeline rendering
- **WHEN** user interacts with timeline
- **THEN** interface maintains 60fps regardless of video length
- **WHEN** zooming timeline
- **THEN** rendering performance remains smooth with efficient redraws
- **WHEN** dragging handles
- **THEN** visual feedback updates instantly without lag
- **WHEN** multiple operations occur simultaneously
- **THEN** system prioritizes critical visual feedback

#### Scenario: Memory-efficient thumbnail generation
- **WHEN** timeline loads video thumbnails
- **THEN** system generates thumbnails efficiently with memory constraints
- **WHEN** large video files are loaded
- **THEN** thumbnail generation uses progressive loading approach
- **WHEN** scrolling through timeline
- **THEN** thumbnails load on-demand with smooth transitions
- **WHEN** memory pressure occurs
- **THEN** system gracefully manages thumbnail cache

## MODIFIED Requirements

### Requirement: Simple Video Timeline Interface
The system SHALL provide a clean, minimal video trimming interface with drag handles for setting start and end points, enhanced with mechanical watch precision and comprehensive visual feedback.

#### Scenario: Enhanced user adjusts trim range
- **WHEN** user drags left handle
- **THEN** start time updates visually with smooth animations and millisecond precision
- **WHEN** user drags right handle
- **THEN** end time updates visually with clear visual feedback and haptic response
- **WHEN** user taps play button
- **THEN** video plays from trim start to trim end with synchronized playhead movement
- **WHEN** user makes fine adjustments
- **THEN** system provides frame-level precision with visual indicators

#### Scenario: Advanced visual timeline interaction
- **WHEN** user views timeline
- **THEN** video thumbnail strip shows full video content with motion indicators
- **WHEN** user drags handles
- **THEN** trim range highlights with multi-layered visual indication
- **WHEN** user drags handles precisely
- **THEN** trim updates with frame-level precision and haptic confirmation
- **WHEN** user scrubs timeline
- **THEN** video preview updates in real-time with frame-accurate seeking

### Requirement: Essential Trimming Controls
The system SHALL provide minimal controls for the trimming workflow, enhanced with modern iOS design and comprehensive accessibility.

#### Scenario: Enhanced user completes trim
- **WHEN** user has set valid trim range
- **THEN** "Next" button becomes enabled with smooth animation
- **WHEN** user taps "Next"
- **THEN** proceed to rotation workflow with trim data preserved
- **WHEN** user taps "Cancel"
- **THEN** return to video selection with confirmation dialog
- **WHEN** user needs to reset trim
- **THEN** clear reset button returns to full video selection

#### Scenario: Enhanced user previews trim
- **WHEN** user taps play button
- **THEN** video plays only the selected trim range with synchronized timeline
- **WHEN** video reaches trim end
- **THEN** playback stops and returns to trim start position smoothly
- **WHEN** user wants to adjust during playback
- **THEN** timeline remains interactive for real-time adjustments

### Requirement: Rotation Workflow Integration
The system SHALL integrate video rotation into the trimming workflow with instant visual feedback and state preservation.

#### Scenario: Enhanced rotation workflow
- **WHEN** user taps rotation button
- **THEN** show rotation options with smooth presentation animation
- **WHEN** user selects rotation option
- **THEN** video preview updates instantly with smooth animation
- **WHEN** user changes rotation
- **THEN** trim preview maintains current selection with new orientation
- **WHEN** user confirms rotation
- **THEN** proceed to naming workflow with both trim and rotation data preserved

### Requirement: Trim Validation
The system SHALL validate trim selections before allowing progression, with intelligent guidance and helpful feedback.

#### Scenario: Enhanced trim validation
- **WHEN** user selects trim duration less than 0.5 seconds
- **THEN** show contextual guidance with suggestions for meaningful range
- **WHEN** user selects trim range exceeding video bounds
- **THEN** automatically constrain to valid range with visual feedback
- **WHEN** trim range is optimal
- **THEN** positive visual feedback confirms good selection
- **WHEN** validation errors occur
- **THEN** clear, actionable guidance helps user correct issues

### Requirement: Universal Frame Rate Handling
The system SHALL provide frame-accurate trimming regardless of video frame rate or variable frame rate content, with enhanced precision and visual feedback.

#### Scenario: Enhanced frame-accurate timeline interaction
- **WHEN** video loads with any frame rate (24fps, 30fps, 60fps, 120fps, VFR)
- **THEN** system detects and adapts to actual video frame rate with visual indicators
- **WHEN** user drags trim handles
- **THEN** interface responds with smooth updates and frame-snapping behavior
- **WHEN** user performs precise trim adjustments
- **THEN** time display shows both timecode and frame numbers with context
- **WHEN** user scrubs timeline
- **THEN** video seeks to exact frame boundaries with proper timecode calculation
- **WHEN** video has variable frame rate
- **THEN** system calculates accurate timecode and provides frame consistency indicators

#### Scenario: Advanced timecode calculation accuracy
- **WHEN** video has non-standard frame rate (23.976fps, 29.97fps, etc.)
- **THEN** system calculates drop-frame timecode with visual indicators
- **WHEN** user trims frame boundaries
- **THEN** trim points align with actual video frames with visual confirmation
- **WHEN** user zooms timeline
- **THEN** frame accuracy is maintained with enhanced visual feedback at all zoom levels
- **WHEN** precision adjustments are needed
- **THEN** system provides frame-by-frame navigation with visual indicators