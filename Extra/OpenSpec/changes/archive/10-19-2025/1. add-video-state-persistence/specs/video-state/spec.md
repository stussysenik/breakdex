## ADDED Requirements

### Requirement: Video State Persistence
The system SHALL preserve loaded video assets and player state across navigation events and app lifecycle transitions.

#### Scenario: Tab navigation preservation
- **WHEN** user navigates away from trimming view to another tab
- **THEN** the video asset and trim settings SHALL be preserved
- **AND** when returning within 5 seconds, the system SHALL restore the trimming session without reloading

#### Scenario: App backgrounding preservation
- **WHEN** the app enters background while video is loaded
- **THEN** the video asset SHALL be preserved in suspended state
- **AND** when app returns to foreground, the system SHALL restore the video player state

#### Scenario: Large video loading support
- **WHEN** user selects a video file between 5-30 minutes
- **THEN** the system SHALL use progressive loading strategy
- **AND** SHALL provide clear progress indication for downloads
- **AND** SHALL handle iCloud downloads with proper timeout management

#### Scenario: Video duration validation
- **WHEN** user selects a video from PhotosPicker
- **THEN** the system SHALL validate video duration early in loading process
- **AND** videos exceeding 30 minutes SHALL be rejected with user-friendly message
- **AND** the validation SHALL occur before full download for iCloud videos

#### Scenario: Oversized video notification
- **WHEN** selected video exceeds 30-minute limit
- **THEN** the system SHALL display clear error message: "Videos longer than 30 minutes are not supported. Please select a shorter video."
- **AND** SHALL return to video selection state without loading the oversized video
- **AND** SHALL log the rejection for diagnostic purposes

### Requirement: Video State Suspension
The system SHALL provide mechanisms to suspend and restore video state using simple WorkflowState in AddMoveViewModel.

#### Scenario: Manual suspension via WorkflowState
- **WHEN** system detects navigation away from trimming view
- **THEN** AddMoveViewModel SHALL suspend video state while preserving asset reference
- **AND** trim settings SHALL be maintained in WorkflowState.videoLoaded
- **AND** video rotation SHALL be preserved in the suspended state

#### Scenario: State restoration via WorkflowState
- **WHEN** user returns to trimming after suspension
- **THEN** AddMoveViewModel SHALL reinitialize the SharedVideoPlayer with preserved asset
- **AND** SHALL restore previous trim settings and rotation state
- **AND** SHALL transition directly to trimming state without re-loading
- **AND** SHALL handle restoration failures gracefully

### Requirement: Enhanced Cancel Functionality
The cancel button SHALL completely reset the video loading mechanism and return to initial state.

#### Scenario: Cancel from trimming
- **WHEN** user taps cancel button in MinimalTrimmerView
- **THEN** all video assets SHALL be released
- **AND** view model SHALL be reset to initial state
- **AND** navigation SHALL return to "select a clip" interface
- **AND** diagnostic log SHALL record cancel operation

#### Scenario: Cancel during loading
- **WHEN** user taps cancel while video is loading
- **THEN** loading process SHALL be terminated
- **AND** any partial downloads SHALL be cleaned up
- **AND** system SHALL return to ready state

### Requirement: Minimal Diagnostic Logging
The system SHALL provide minimal logging for debugging state transitions and persistence operations.

#### Scenario: State transition logging
- **WHEN** video state changes (suspend/restore/reset)
- **THEN** system SHALL log the transition type and timestamp
- **AND** SHALL include current video duration and file size for large files

#### Scenario: Persistence operation logging
- **WHEN** persistence operations occur
- **THEN** system SHALL log success/failure of suspend/restore operations
- **AND** SHALL log memory usage for large video files