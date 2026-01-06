# Component Integration Spec

## ADDED Requirements

### Requirement: SimpleLoadingView Integration
The SelectClip view SHALL integrate with the existing SimpleLoadingView component to provide consistent loading UI across the application.

#### Scenario: Video loading operation begins
When user initiates video loading from Photos picker, then SelectClip view SHALL display SimpleLoadingView instead of custom loading UI, and SimpleLoadingView SHALL receive VideoLoadingState and VideoLoadingProgress, and loading animations MUST start automatically when view appears.

### Requirement: VideoLoadingState Utilization
The video loading process SHALL utilize the VideoLoadingState enum to track different phases of loading and provide appropriate UI feedback.

#### Scenario: Video loading progresses through different phases
When VideoLoadingService updates loading progress, then VideoLoadingState enum SHALL be used to track current phase, and state MUST map correctly to UI representations in SimpleLoadingView, and error states MUST be handled with appropriate retry options.

### Requirement: SharedVideoPlayer Integration
The SharedVideoPlayer component SHALL be integrated consistently across video playback features to provide uniform user experience.

#### Scenario: Video is loaded and ready for playback
When video loading completes successfully, then SharedVideoPlayer SHALL be instantiated with the loaded asset, and VideoPlayerView SHALL be used for consistent playback interface, and player MUST support trimming interface integration.

## MODIFIED Requirements

### Requirement: SelectClip Loading State Management
The SelectClip view MUST properly manage loading states using the unified state system while integrating with loading components.

#### Scenario: User interaction with SelectClip view
When SelectClip view determines loading state, then it SHALL use unifiedState.flowState.isLoading from AddMoveFlowState, and it SHALL integrate SimpleLoadingView for loading operations, and it MUST maintain backward compatibility with existing error handling.

### Requirement: Video Loading Progress Tracking
Video loading progress MUST be consistently tracked and displayed across different components to provide unified user experience.

#### Scenario: Video loading progress updates
When VideoLoadingService provides progress updates, then progress SHALL be reflected in both VideoLoadingState and AddMoveUnifiedState, and UI SHALL show consistent progress indicators, and state transitions MUST be logged for debugging.

## ADDED Cross-Component Relationships

### VideoLoadingState → AddMoveFlowState Mapping
- `VideoLoadingState.idle` → `AddMoveFlowState.ready`
- `VideoLoadingState.initializing` → `AddMoveFlowState.loading`
- `VideoLoadingState.downloadingFromCloud` → `AddMoveFlowState.loadingVideo`
- `VideoLoadingState.ready` → `AddMoveFlowState.trimming`
- `VideoLoadingState.error` → `AddMoveFlowState.error`

### SimpleLoadingView Integration Points
- SelectClip loading state display
- Error state presentation with retry options
- Progress indication during video transfer
- Network status display for iCloud downloads

### SharedVideoPlayer Integration Points
- TrimmerView video playback
- Move detail video preview
- Review session video playback
- Consistent control interface across features