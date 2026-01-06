## ADDED Requirements

### Requirement: Video Preloading for Tab Return
The system SHALL preload video content immediately when a suspended workflow is detected during tab navigation.

#### Scenario: Quick return with preloaded video
- **WHEN** user returns to Add Move tab within 5 seconds with a suspended workflow
- **THEN** video preloading starts immediately before view composition
- **AND** video player is ready when MinimalTrimmerView appears
- **AND** no empty video frames are displayed

#### Scenario: Delayed return with video restoration
- **WHEN** user returns to Add Move tab after 5 seconds with a suspended workflow
- **THEN** video asset is restored from cached data
- **AND** video loading begins during view state synchronization
- **AND** video appears ready without visible loading delays

### Requirement: View Readiness Coordination
The system SHALL ensure video content is ready before displaying the trimming interface.

#### Scenario: Guard against empty video rendering
- **WHEN** MinimalTrimmerView.onAppear() is called
- **THEN** view checks videoPlayer.isReady before rendering content
- **AND** shows loading state if video is not prepared
- **AND** only proceeds with trimmer setup when video is ready

#### Scenario: Smooth transition to ready state
- **WHEN** video player becomes ready during view appearance
- **THEN** trimmer setup proceeds immediately without delay
- **AND** video displays current trim position
- **AND** user can interact with trimmer controls instantly

### Requirement: Video Player State Preservation
The system SHALL preserve video player state across tab navigation to enable instant restoration.

#### Scenario: Player instance preservation
- **WHEN** user navigates away from Add Move tab during active trimming
- **THEN** video player instance is preserved in memory
- **AND** current playback position and trim range are cached
- **AND** player state is immediately available on return

#### Scenario: State synchronization on return
- **WHEN** user returns to Add Move tab with preserved player state
- **THEN** cached player state is applied immediately
- **AND** video resumes from exact previous position
- **AND** trim handles maintain previous positions

## MODIFIED Requirements

### Requirement: Tab Navigation State Restoration
The system SHALL restore workflow state when returning to the Add Move tab and coordinate video loading with view readiness.

#### Scenario: Suspended workflow detection and video coordination
- **WHEN** AddMoveView.setupInitialState() detects a suspended workflow
- **THEN** currentStep is set to trimming immediately
- **AND** video preloading is triggered via preloadVideoForQuickReturn()
- **AND** view composition waits for video readiness
- **AND** diagnostic logging tracks timing coordination

#### Scenario: Complete state restoration with video readiness
- **WHEN** both workflow state and video player are ready
- **THEN** MinimalTrimmerView renders with fully prepared video
- **AND** trim controls are immediately interactive
- **AND** no view recomputation loops occur
- **AND** video playback starts without flashing