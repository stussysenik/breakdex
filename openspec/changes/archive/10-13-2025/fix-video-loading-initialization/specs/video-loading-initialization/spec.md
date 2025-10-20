# Video Loading Initialization Spec

## ADDED Requirements

### Requirement: Correct Initial State Display
The AddMove feature SHALL initialize in a ready state showing the "Select a Clip" button by default, allowing users to immediately begin video selection without unnecessary loading indicators.

#### Scenario: User launches app to AddMove tab
When the app launches and navigates to AddMove tab, then the user SHALL see the "Select a Clip" button (not a loading spinner), and the AddMoveUnifiedState.flowState SHALL be `.ready`, and SelectClip view SHALL show the selection interface.

### Requirement: Enhanced Diagnostic Logging
State transitions in the video loading flow MUST be comprehensively logged with context and visual indicators to aid in debugging and monitoring.

#### Scenario: State transition occurs during video loading
When AddMoveUnifiedState state changes, then a diagnostic log MUST be generated with the new state, and the log SHALL include context about the transition, and the log MUST use consistent emoji formatting for easy identification.

### Requirement: SimpleLoading Component Integration
The SelectClip view SHALL utilize the existing SimpleLoadingView component for consistent loading UI across the application.

#### Scenario: Video loading is in progress
When user selects a video from Photos picker, then the SelectClip view SHALL use SimpleLoadingView for consistent loading UI, and the loading view SHALL display appropriate progress information, and the loading view MUST handle error states gracefully.

### Requirement: VideoLoadingState Mapping
VideoLoadingState MUST properly map to AddMoveFlowState to ensure consistent state management across components.

#### Scenario: Video loading progresses through phases
When VideoLoadingProgress updates occur, then VideoLoadingState MUST properly map to corresponding AddMoveFlowState, and state transitions SHALL be consistent across components, and error states MUST propagate correctly to the UI.

### Requirement: VideoPlayer Component Utilization
The SharedVideoPlayer component SHALL be used consistently for video playback across the application.

#### Scenario: Video is successfully loaded and ready for trimming
When video loading completes successfully, then the VideoPlayer component SHALL be used for playback, and the player SHALL provide consistent controls across the app, and the player MUST support seeking and trimming operations.

## MODIFIED Requirements

### Requirement: AddMoveUnifiedState Initialization
The initialization logic for AddMoveUnifiedState MUST set the correct initial state to prevent UI confusion.

#### Scenario: AddMoveUnifiedState is created
When the unified state is initialized, then flowState SHALL default to `.ready` instead of `.loading`, and diagnostic logging MUST capture the initial state, and the state SHALL be immediately ready for user interaction.

### Requirement: SelectClip View Loading State
The SelectClip view MUST properly determine and display the appropriate loading state based on the unified state.

#### Scenario: SelectClip view renders content
When the SelectClip view determines what to display, then it SHALL check unifiedState.flowState.isLoading, and it SHALL show SimpleLoadingView when loading is true, and it SHALL show "Select a Clip" button when loading is false.

## REMOVED Requirements

### Requirement: Default Loading State
#### Scenario: App initializes AddMove feature
- **REMOVED:** Previous requirement that initialized flowState as `.loading`
- **REASON:** This caused incorrect UI display and poor user experience