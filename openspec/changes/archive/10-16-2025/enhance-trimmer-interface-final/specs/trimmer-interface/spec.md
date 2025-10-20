# Enhanced Trimmer Interface Specification

## Requirements

### ADDED: Inline Timecode Annotations

#### Requirement: Display timecode annotations inline with timeline visual elements
Users should see timecode markers positioned directly within the timeline layout rather than below it, matching the Test2.swift design for better visual hierarchy and space efficiency.

##### Scenario: User views trimmer interface
- Given the trimmer view is displayed
- When the timeline renders
- Then timecode annotations (00:00:00, 00:08:12, 00:17:01, 00:25:14, 00:34:03) appear inline with the timeline bar
- And annotations use responsive sizing based on screen width
- And text remains readable with proper contrast

### ADDED: Enhanced Video Rotation with Visual Feedback

#### Requirement: Provide smooth 90-degree video rotation with immediate visual feedback in trimmer view
Users should be able to rotate the video preview in 90-degree increments with smooth animations and immediate visual feedback showing the current rotation state.

##### Scenario: User rotates video during trimming
- Given a video is loaded in the trimmer
- When the user taps the rotate button
- Then the video rotates 90 degrees clockwise with smooth animation
- And the rotation applies to the video player view immediately
- And a visual indicator shows current rotation state
- And the aspect ratio is maintained during rotation

### ADDED: Optimized Video Seeking Performance

#### Requirement: Implement frame-accurate seeking with iOS 18 performance optimizations
Video seeking during handle dragging should be smooth and responsive using iOS 18 best practices for optimal user experience.

##### Scenario: User drags trim handles
- Given the user is dragging a trim handle
- When the handle position changes
- Then video seeks to the corresponding time with debouncing
- And seeking performance remains smooth without stuttering
- And AVMetrics API monitors playback performance
- And seek operations cancel previous pending seeks

### MODIFIED: Reset Button Functionality

#### Requirement: Provide complete reset of trim modifications
The reset button should restore the original trim range and rotation state, allowing users to start over with their trimming selections.

##### Scenario: User resets trim modifications
- Given the user has made trim modifications
- When the user taps the reset button/text
- Then the trim range resets to full video duration
- And rotation returns to 0 degrees
- And all validation errors are cleared
- And the video player seeks to the beginning

### MODIFIED: Submit Button Navigation

#### Requirement: Ensure reliable navigation to NameMoveView with complete trim data
The submit button should validate all trim parameters and navigate to NameMoveView with complete trim modification data including rotation information.

##### Scenario: User submits valid trim range
- Given the user has selected a valid trim range (minimum 3 seconds)
- And rotation may be applied
- When the user taps the submit button
- Then trim range validation passes
- And TrimModification object includes rotation data
- And navigation to NameMoveView occurs smoothly
- And all trim state persists in AddMoveUnifiedState

### ADDED: Enhanced Touch Target Accessibility

#### Requirement: Provide accessible touch targets for all interactive elements
All buttons and trim handles should meet iOS accessibility guidelines for touch target sizes while maintaining the Test2.swift visual design.

##### Scenario: User interacts with trimmer controls
- Given the trimmer interface is displayed
- When the user interacts with any control
- Then touch targets meet minimum 44x44 point requirement
- And visual feedback is provided on touch
- And haptic feedback enhances the interaction experience
- And controls remain accessible to users with motor impairments