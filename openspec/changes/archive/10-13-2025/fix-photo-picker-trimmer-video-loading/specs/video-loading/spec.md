## ADDED Requirements

### Requirement: Resource Leak Prevention in Video Loading
The system SHALL prevent resource leaks during video loading operations to avoid "Too many open files" errors and maintain app stability.

#### Scenario: File handle cleanup after video loading
- **WHEN** video loading completes successfully or fails
- **THEN** the system SHALL release all file handles and temporary resources
- **AND** SHALL clean up any temporary files created during loading

#### Scenario: Memory management during video processing
- **WHEN** processing video assets in VideoLoadingService
- **THEN** the system SHALL use autoreleasepool for memory-intensive operations
- **AND** SHALL release AVAsset references when no longer needed

### Requirement: Minimalistic Diagnostic Logging
The system SHALL implement focused, essential logging only for critical state transitions and errors to provide actionable debugging information without noise.

#### Scenario: Critical state transition logging
- **WHEN** the app transitions between major states (app launch, video loading start/end, Core Data events)
- **THEN** the system SHALL log the transition with clear, concise messages
- **AND** SHALL use structured logging with emojis for visual identification

#### Scenario: Error logging with context
- **WHEN** an error occurs during video loading or Core Data operations
- **THEN** the system SHALL log the error with relevant context and correlation ID
- **AND** SHALL NOT log verbose progress information that obscures the actual error

## MODIFIED Requirements

### Requirement: Video Loading from Photos Picker
The system SHALL provide reliable video loading from the Photos picker to the TrimmerView interface with proper resource management and error handling.

#### Scenario: Successful video loading with resource cleanup
- **WHEN** user selects a video from Photos picker
- **THEN** the system SHALL load the video with progress indication
- **AND** SHALL automatically clean up all intermediate resources and file handles
- **AND** SHALL transition smoothly to TrimmerView with the loaded video

#### Scenario: Video loading error recovery
- **WHEN** video loading fails due to resource constraints or other errors
- **THEN** the system SHALL provide clear error messaging with recovery options
- **AND** SHALL ensure all resources are properly released before showing error state
- **AND** SHALL offer "Try Again" and "Select Different Video" options

### Requirement: Video Loading State Management
The system SHALL maintain clean, predictable state transitions during video loading without resource accumulation.

#### Scenario: State transition management
- **WHEN** video loading operation begins
- **THEN** the system SHALL transition to loading state and disable user interactions
- **AND** SHALL maintain the loading state until operation completes or fails
- **AND** SHALL ensure proper cleanup before transitioning to next state

#### Scenario: Loading operation cancellation
- **WHEN** video loading is cancelled or times out
- **THEN** the system SHALL cancel all async operations and release resources
- **AND** SHALL return to ready state with clean resource state
- **AND** SHALL allow user to select a different video