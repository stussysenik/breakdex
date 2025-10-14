## MODIFIED Requirements

### Requirement: Coordinated Video Loading State Management
The video loading system SHALL maintain coordinated state across VideoLoadingService, VideoLoadingOperationManager, UnifiedState, and TrimmerView with a single source of truth for loading progress and completion status.

#### Scenario: Video loading completion coordination
- **WHEN** VideoLoadingService completes loading a video successfully
- **THEN** it SHALL report completion to UnifiedState through the existing updateProgress method
- **AND** UnifiedState SHALL update flowState to .trimming automatically
- **AND** TrimmerView SHALL receive the state change through its onChange(of: unifiedState.flowState) handler
- **AND** TrimmerView SHALL hide the loading spinner and show the video trimming interface

#### Scenario: Progress tracking unification
- **WHEN** video loading progress is reported by any service
- **THEN** UnifiedState SHALL be the single source of truth for progress state
- **AND** VideoLoadingOperationManager SHALL update UnifiedState.progress instead of direct UI updates
- **AND** TrimmerView SHALL observe UnifiedState.loadingProgress instead of maintaining separate progress state
- **AND** all progress phases SHALL be consistent across all components

#### Scenario: Correlation ID tracking
- **WHEN** a video loading operation begins
- **THEN** a correlation ID SHALL be generated and passed to all services
- **AND** VideoLoadingService, VideoLoadingOperationManager, and UnifiedState SHALL use the same correlation ID
- **AND** all log messages SHALL include the correlation ID for debugging
- **AND** correlation ID SHALL be cleared upon completion or error

#### Scenario: State synchronization during initialization
- **WHEN** TrimmerView appears
- **THEN** it SHALL check UnifiedState.flowState to determine current loading status
- **AND** if flowState is .trimming, TrimmerView SHALL immediately hide loading spinner
- **AND** if flowState is .loadingVideo, TrimmerView SHALL show loading spinner
- **AND** if UnifiedState.selectedVideo exists, TrimmerView SHALL initialize video player immediately

#### Scenario: Error state coordination
- **WHEN** video loading fails in any service
- **THEN** the error SHALL be reported to UnifiedState.setError()
- **AND** UnifiedState SHALL update flowState to .error
- **AND** TrimmerView SHALL display error view based on unifiedState.hasError
- **AND** retry functionality SHALL be coordinated through UnifiedState methods

### Requirement: VideoLoadingService Integration
VideoLoadingService SHALL properly integrate with UnifiedState for coordinated video loading operations.

#### Scenario: Service completion reporting
- **WHEN** VideoLoadingService.loadVideo() completes successfully
- **THEN** it SHALL call unifiedState.setSelectedVideo() with the loaded asset
- **AND** it SHALL call unifiedState.updateProgress() with .completed phase
- **AND** it SHALL ensure unifiedState.flowState transitions to .trimming
- **AND** correlation ID SHALL be cleared from the service

#### Scenario: Progress reporting chain
- **WHEN** VideoLoadingService reports progress through its progressPublisher
- **THEN** UnifiedState SHALL receive updates through its updateProgress method
- **AND** progress phases SHALL be mapped correctly to AddMoveFlowState values
- **AND** TrimmerView SHALL reflect progress changes immediately

### Requirement: VideoLoadingOperationManager Coordination
VideoLoadingOperationManager SHALL coordinate with UnifiedState rather than direct UI manipulation.

#### Scenario: Manager state updates
- **WHEN** VideoLoadingOperationManager updates progress
- **THEN** it SHALL report progress to UnifiedState instead of direct UI updates
- **AND** UnifiedState SHALL handle the state transition and UI updates
- **AND** TrimmerView SHALL observe UnifiedState changes for UI updates

#### Scenario: Operation lifecycle management
- **WHEN** VideoLoadingOperationManager starts an operation
- **THEN** it SHALL coordinate with UnifiedState for the operation lifecycle
- **AND** completion SHALL be reported through UnifiedState methods
- **AND** errors SHALL be handled through UnifiedState error management

### Requirement: TrimmerView State Observation
TrimmerView SHALL observe UnifiedState for all loading state changes and eliminate duplicate state management.

#### Scenario: Loading state observation
- **WHEN** UnifiedState.loadingProgress changes
- **THEN** TrimmerView SHALL update its loading UI accordingly
- **AND** it SHALL NOT maintain separate loading state variables
- **AND** loading message SHALL be derived from UnifiedState.progress.phase

#### Scenario: Video asset observation
- **WHEN** UnifiedState.selectedVideo changes
- **THEN** TrimmerView SHALL immediately load the video in the player
- **AND** it SHALL hide loading spinner
- **AND** it SHALL initialize trim values based on video duration

#### Scenario: Error state observation
- **WHEN** UnifiedState.hasError changes to true
- **THEN** TrimmerView SHALL display error view
- **AND** error message SHALL be taken from UnifiedState.errorMessage
- **AND** retry functionality SHALL use UnifiedState methods

### Requirement: Initialization Sequence Coordination
The video loading system SHALL initialize components in the correct sequence to prevent race conditions.

#### Scenario: Component initialization order
- **WHEN** AddMove feature initializes
- **THEN** UnifiedState SHALL initialize first
- **AND** VideoLoadingService SHALL initialize second
- **AND** VideoLoadingOperationManager SHALL initialize third
- **AND** TrimmerView SHALL initialize last and observe the others

#### Scenario: State restoration on view appear
- **WHEN** TrimmerView appears
- **THEN** it SHALL check UnifiedState for existing video data
- **AND** if video exists, it SHALL skip loading state and show trimming interface
- **AND** if loading is in progress, it SHALL show appropriate loading state
- **AND** it SHALL not trigger redundant loading operations

### Requirement: Diagnostic Logging Enhancement
The video loading system SHALL provide comprehensive diagnostic logging for coordination debugging.

#### Scenario: Coordination logging
- **WHEN** state transitions occur between components
- **THEN** each transition SHALL be logged with component names and correlation ID
- **AND** state values SHALL be logged before and after transitions
- **AND** timing information SHALL be included for performance analysis

#### Scenario: Error logging with context
- **WHEN** coordination errors occur
- **THEN** the error SHALL be logged with full component state context
- **AND** correlation ID SHALL be included for traceability
- **AND** recovery attempts SHALL be logged with detailed information