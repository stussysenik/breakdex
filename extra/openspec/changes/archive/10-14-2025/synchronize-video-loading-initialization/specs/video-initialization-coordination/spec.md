# Video Initialization Coordination Specification

## ADDED Requirements

### Video Loading Deduplication

#### Requirement: Single Loading Operation per Video Selection
The system SHALL ensure only one video loading operation occurs per user video selection.

#### Scenario: User selects a video from PhotosPicker
- When user selects a video, the system SHALL create a unique correlation ID for the loading operation
- When multiple loading triggers are detected for the same correlation ID, the system SHALL deduplicate the requests
- When loading is in progress, additional loading attempts SHALL be ignored and await the existing operation completion
- When loading completes or fails, the correlation ID SHALL be cleared to allow new loading operations

#### Requirement: Coordinated Loading State Management
The VideoInitializationCoordinator SHALL manage all loading state transitions.

#### Scenario: Video loading state changes during initialization
- When loading starts, the coordinator SHALL set initial loading state and prevent duplicate operations
- When loading progresses, the coordinator SHALL update all dependent components (UnifiedState, OperationManager, etc.)
- When loading completes, the coordinator SHALL trigger coordinated state transition to trimming
- When loading fails, the coordinator SHALL handle error cleanup and reset state for retry

### Task Continuation Management

#### Requirement: Proper Continuation Handling
The system SHALL ensure all async continuations are properly resumed or cancelled.

#### Scenario: Player ready wait operation with timeout
- When `waitForPlayerReady` is called, the system SHALL create a continuation with proper cancellation handling
- When player becomes ready, the continuation SHALL be resumed immediately and timeout task cancelled
- When timeout occurs, the continuation SHALL be resumed with timeout error and observers cleaned up
- When operation is cancelled, the continuation SHALL be resumed with cancellation error and all resources cleaned up

#### Requirement: Cancellation Propagation
The system SHALL properly propagate cancellation through the loading chain.

#### Scenario: User cancels video loading or selects different video
- When loading is cancelled, all active tasks SHALL receive cancellation signal
- When timeout tasks are cancelled, they SHALL clean up observers and continuations
- When observer tasks are cancelled, they SHALL remove KVO and notification observers
- When coordination is cancelled, all component states SHALL be reset to initial values

### Observer Lifecycle Management

#### Requirement: Centralized Observer Management
The system SHALL manage all video player observers through a centralized lifecycle manager.

#### Scenario: Video player observer registration and cleanup
- When observers are registered, the system SHALL track them with unique identifiers
- When duplicate observer registration is attempted, the system SHALL remove existing observer first
- When observers are removed, the system SHALL guarantee successful removal with verification
- When player is deallocated, the system SHALL remove all registered observers synchronously

#### Requirement: Observer State Validation
The system SHALL validate observer state during loading operations.

#### Scenario: Observer state validation during video loading
- When observers are active, the system SHALL track their registration status
- When observer cleanup fails, the system SHALL log detailed diagnostic information
- When observer leaks are detected, the system SHALL force cleanup and prevent further leaks
- When observer operations complete, the system SHALL verify all observers are properly cleaned up

### Streamlined State Flow

#### Requirement: Direct State Transitions
The system SHALL implement direct state transitions without intermediate delays.

#### Scenario: Video loading completion to trimming state transition
- When video loading completes successfully, the system SHALL immediately transition to trimming state
- When player is ready for playback, the system SHALL update UI state without waiting periods
- When state transition occurs, all dependent components SHALL be updated synchronously
- When trimming state is active, the video SHALL be immediately ready for user interaction

#### Requirement: Eliminated Redundant Recovery
The system SHALL remove redundant recovery mechanisms that cause performance overhead.

#### Scenario: Video loading error handling and recovery
- When loading fails, the system SHALL attempt a single recovery with enhanced error handling
- When recovery fails, the system SHALL present clear error state to user
- When aggressive recovery mechanisms are triggered, they SHALL be ignored in favor of coordinated flow
- When multiple recovery attempts would occur, the system SHALL consolidate to single comprehensive attempt

### Performance Optimization

#### Requirement: Loading Time Optimization
The system SHALL achieve video loading completion within 2 seconds.

#### Scenario: Video loading performance measurement
- When video loading starts, the system SHALL track timing metrics for each phase
- When loading exceeds 2 seconds, the system SHALL log performance warnings with detailed phase analysis
- When loading completes successfully within 2 seconds, the system SHALL log performance success metrics
- When loading performance degrades, the system SHALL identify bottleneck phases for optimization

#### Requirement: Memory Management
The system SHALL prevent memory leaks during video loading operations.

#### Scenario: Memory usage during video loading
- When loading operations complete, the system SHALL release all temporary resources immediately
- When observers are cleaned up, the system SHALL verify no retain cycles exist
- When cancellation occurs, the system SHALL deallocate all associated memory resources
- When memory leaks are detected, the system SHALL log diagnostic information and force cleanup

## MODIFIED Requirements

### Video Loading Service Coordination

#### Requirement: Enhanced Coordination with UnifiedState
The VideoLoadingService SHALL coordinate with UnifiedState through a single coordinator.

#### Scenario: Video loading completion coordination
- MODIFIED: Instead of multiple coordination attempts, use single coordinator to manage UnifiedState updates
- When video asset is loaded, the coordinator SHALL update UnifiedState with proper timing
- When UnifiedState is updated, the coordinator SHALL verify state consistency
- When coordination fails, the coordinator SHALL attempt single recovery before reporting error

### Video Player Ready State Detection

#### Requirement: Immediate Ready State Detection
The SharedVideoPlayer SHALL detect and report ready state immediately.

#### Scenario: Player ready state detection and reporting
- MODIFIED: Remove multiple fallback checks and implement immediate detection
- When player becomes ready, the system SHALL immediately update state and notify observers
- When ready state is detected, the system SHALL validate player functionality before reporting
- When ready state detection fails, the system SHALL attempt single recovery with enhanced error handling