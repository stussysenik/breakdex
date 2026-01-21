# Add Move Architecture Specification

## ADDED Requirements

### Requirement: Single AddMoveViewModel Architecture
The system SHALL use a single AddMoveViewModel to manage the entire add move workflow without unnecessary protocol abstractions.

#### Scenario: Complete add move flow with single ViewModel
- **WHEN** user initiates add move workflow
- **THEN** AddMoveViewModel manages all states (ready, selecting, trimming, naming, saving)
- **AND** SharedVideoPlayer instance is created once in AddMoveViewModel
- **AND** All views observe AddMoveViewModel directly without protocols

### Requirement: Direct SharedVideoPlayer Sharing
The system SHALL eliminate asset transfer bottlenecks by using a single SharedVideoPlayer instance.

#### Scenario: Video loads directly into AddMoveViewModel player
- **WHEN** user selects video asset
- **THEN** AddMoveViewModel loads asset directly into self.videoPlayer
- **AND** MinimalTrimmerView uses viewModel.videoPlayer directly
- **AND** No asset transfer or synchronization is needed

### Requirement: Clean View Architecture
The system SHALL implement "dumb" views that only handle UI presentation and forward actions to AddMoveViewModel.

#### Scenario: MinimalTrimmerView uses AddMoveViewModel directly
- **WHEN** user transitions to trimming step
- **THEN** MinimalTrimmerView observes AddMoveViewModel directly (no protocol)
- **AND** VideoPlayerView uses viewModel.videoPlayer
- **AND** Timeline binds to viewModel.trimStartTime/trimEndTime
- **AND** User actions call viewModel methods directly

## MODIFIED Requirements

### Requirement: AddMoveViewModel State Management
AddMoveViewModel SHALL manage complete add move workflow state including video playback and trimming parameters.

#### Scenario: Comprehensive state management in single ViewModel
- **WHEN** AddMoveViewModel initializes
- **THEN** It contains videoPlayer: SharedVideoPlayer instance
- **AND** Manages loadingState, trimStartTime, trimEndTime, moveName, moveDescription
- **AND** Handles state transitions for entire workflow
- **AND** Provides direct access to loaded video for all views

## REMOVED Requirements

### Requirement: TrimmerViewModelProtocol
**Reason**: Protocol creates unnecessary abstraction and violates MVVM principles
**Migration**: Remove protocol completely, use direct AddMoveViewModel observation

- **REMOVED**: TrimmerViewModelProtocol with asset transfer methods
- **REMOVED**: Protocol conformance requirements for AddMoveViewModel
- **REMOVED**: Complex asset validation and transfer logic in protocol

### Requirement: Asset Transfer Between ViewModels
**Reason**: Asset transfer creates synchronization bottleneck and performance issues
**Migration**: Use single SharedVideoPlayer instance, eliminate transfer completely

- **REMOVED**: Asset transfer methods between ViewModels
- **REMOVED**: setupTrimmerWithGuard() asset loading logic
- **REMOVED**: waitForPlayerReadiness() timeout handling
- **REMOVED**: Asset transfer progress tracking and error handling

### Requirement: Separate Player Instances
**Reason**: Multiple SharedVideoPlayer instances create synchronization problems
**Migration**: Single player instance in AddMoveViewModel shared by all views

- **REMOVED**: Separate SharedVideoPlayer in MinimalTrimmerView
- **REMOVED**: Player instance synchronization logic
- **REMOVED**: Asset transfer between different player instances

## Success Criteria

### Functional Requirements
- ✅ Video displays immediately when transitioning to trimming view (no 10% freeze)
- ✅ Single SharedVideoPlayer instance eliminates asset transfer bottleneck
- ✅ AddMoveViewModel manages entire add move flow state
- ✅ Views are "dumb" with no business logic
- ✅ No TrimmerViewModelProtocol complexity

### Architectural Requirements
- ✅ Follows MVVM principles (direct View → ViewModel observation)
- ✅ Follows SRP (each component has single responsibility)
- ✅ Validated by 2025 SwiftUI best practices
- ✅ Clean, maintainable code structure

### Performance Requirements
- ✅ Video displays within 1 second of loading completion
- ✅ No asset transfer overhead
- ✅ Memory efficient (single player instance)
- ✅ Smooth UI transitions between workflow steps