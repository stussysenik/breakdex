## MODIFIED Requirements

### Requirement: Video Selection and Loading
The system SHALL provide robust video loading from PhotosPicker with progressive state management and large file support.

#### Scenario: Initial video selection
- **WHEN** user selects a video from PhotosPicker
- **THEN** the system SHALL load the video using RobustVideoLoader
- **AND** SHALL initialize SharedVideoPlayer with the loaded asset
- **AND** SHALL transition to trimming state upon successful loading
- **AND** SHALL preserve the loaded state for subsequent navigation

#### Scenario: Video loading progress
- **WHEN** video loading is in progress
- **THEN** the system SHALL display accurate progress indicators
- **AND** SHALL handle iCloud downloads with proper progress tracking
- **AND** SHALL provide timeout handling for large files (> 10 minutes)
- **AND** SHALL use progressive loading for videos larger than 5 minutes

#### Scenario: Video duration validation during loading
- **WHEN** video loading begins
- **THEN** the system SHALL validate video duration does not exceed 30 minutes
- **AND** SHALL reject oversized videos with clear error message before full processing
- **AND** SHALL prevent unnecessary downloads of oversized iCloud videos

#### Scenario: Loading failure recovery
- **WHEN** video loading fails
- **THEN** the system SHALL display user-friendly error message
- **AND** SHALL provide option to retry or select different video
- **AND** SHALL clean up any partial downloads

### Requirement: Trimming State Management
The system SHALL maintain consistent trimming state across view lifecycle events using simple WorkflowState.

#### Scenario: Trimming state persistence via WorkflowState
- **WHEN** user has selected trim range and navigates away
- **THEN** AddMoveViewModel SHALL preserve trim start/end times in WorkflowState
- **AND** rotation settings SHALL be preserved in the suspended state
- **AND** video asset SHALL be preserved for restoration

#### Scenario: Quick return detection
- **WHEN** user navigates between tabs
- **THEN** AddMoveView SHALL detect quick returns (< 5 seconds)
- **AND** SHALL coordinate with AddMoveViewModel for state restoration
- **AND** SHALL use fresh loading for returns after 5 seconds

#### Scenario: Error state handling
- **WHEN** error occurs during trimming
- **THEN** the system SHALL preserve user's trim selections
- **AND** SHALL provide clear error message
- **AND** SHALL allow user to retry or cancel

### Requirement: View State Transitions
The system SHALL handle view state transitions with proper resource management and state preservation.

#### Scenario: Ready to trimming transition
- **WHEN** video loading completes successfully
- **THEN** the system SHALL immediately transition to trimming state
- **AND** SHALL initialize trim controls with video metadata
- **AND** SHALL set default trim range (last 10 seconds or full duration)

#### Scenario: Trimming to ready transition
- **WHEN** user cancels trimming or navigation requires reset
- **THEN** the system SHALL clean up video resources
- **AND** SHALL reset to initial ready state
- **AND** SHALL preserve diagnostic logs for debugging

#### Scenario: App lifecycle transitions
- **WHEN** app backgrounds with loaded video
- **THEN** the system SHALL suspend video playback
- **AND** SHALL preserve video asset reference
- **AND** SHALL restore state when app returns to foreground

### Requirement: Video Asset Management
The system SHALL manage video assets efficiently with proper memory management and lifecycle handling.

#### Scenario: Asset loading optimization
- **WHEN** loading video assets
- **THEN** the system SHALL use appropriate memory management
- **AND** SHALL implement progressive loading for large files
- **AND** SHALL monitor memory usage and clean up when necessary

#### Scenario: Asset cleanup
- **WHEN** video is no longer needed
- **THEN** the system SHALL release AVAsset resources
- **AND** SHALL cancel any ongoing iCloud downloads
- **AND** SHALL clean up temporary files