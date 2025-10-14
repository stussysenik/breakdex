## MODIFIED Requirements

### Requirement: Unified State Observation
TrimmerView SHALL observe UnifiedState as the single source of truth for all video loading state.

#### Scenario: Loading state observation
- **WHEN** TrimmerView needs to determine loading state
- **THEN** it SHALL use unifiedState.flowState instead of local isLoadingVideo
- **AND** it SHALL eliminate the isLoadingVideo state variable entirely
- **AND** loading UI SHALL be derived from flowState.isLoading property

#### Scenario: Progress observation
- **WHEN** TrimmerView displays loading progress
- **THEN** it SHALL use unifiedState.loadingProgress
- **AND** it SHALL NOT use loadingOperationManager.currentProgress directly
- **AND** progress message SHALL be derived from loadingProgress.phase.displayName

#### Scenario: Video asset observation
- **WHEN** TrimmerView needs to display video content
- **THEN** it SHALL observe unifiedState.selectedVideo
- **AND** it SHALL immediately load the video in videoPlayer when asset changes
- **AND** it SHALL hide loading spinner when asset is available

#### Scenario: Error state observation
- **WHEN** TrimmerView needs to display errors
- **THEN** it SHALL use unifiedState.hasError and unifiedState.errorMessage
- **AND** it SHALL NOT maintain separate lastError state
- **AND** error view SHALL be displayed based on UnifiedState error state

### Requirement: State Change Response
TrimmerView SHALL respond correctly to state changes from UnifiedState.

#### Scenario: Flow state transition response
- **WHEN** unifiedState.flowState changes to .trimming
- **THEN** TrimmerView SHALL immediately hide loading spinner
- **AND** it SHALL initialize video player with selectedVideo
- **AND** it SHALL set trim values based on video duration
- **AND** loadingMessage SHALL be reset to default

#### Scenario: Loading progress response
- **WHEN** unifiedState.loadingProgress changes
- **THEN** TrimmerView SHALL update loading message based on progress.phase
- **AND** loadingProgress variable SHALL be updated from progress.progress
- **AND** detailed loading information SHALL be displayed when available

#### Scenario: Error state response
- **WHEN** unifiedState.hasError becomes true
- **THEN** TrimmerView SHALL display error view
- **AND** it SHALL show retry option based on error type
- **AND** loading spinner SHALL be hidden
- **AND** error details SHALL be displayed in debug mode

### Requirement: Initialization State Restoration
TrimmerView SHALL properly restore state when appearing based on UnifiedState.

#### Scenario: Video already loaded restoration
- **WHEN** TrimmerView appears and unifiedState.selectedVideo exists
- **THEN** it SHALL immediately hide loading spinner
- **AND** it SHALL load video in player without showing loading state
- **AND** it SHALL log "Video already present on appear, hiding loading spinner"
- **AND** it SHALL initialize trim values immediately

#### Scenario: Loading in progress restoration
- **WHEN** TrimmerView appears and unifiedState.flowState is .loadingVideo
- **THEN** it SHALL show loading spinner with current progress
- **AND** it SHALL display current loading message from UnifiedState
- **AND** it SHALL continue observing progress updates
- **AND** it SHALL not trigger redundant loading operations

#### Scenario: Error state restoration
- **WHEN** TrimmerView appears and unifiedState.hasError is true
- **THEN** it SHALL display error view immediately
- **AND** it SHALL show error message from unifiedState.errorMessage
- **AND** it SHALL provide retry options based on error type
- **AND** it SHALL not attempt automatic recovery

### Requirement: Component Integration Cleanup
TrimmerView SHALL eliminate redundant component integrations and simplify state management.

#### Scenario: VideoLoadingService integration removal
- **WHEN** TrimmerView needs video loading information
- **THEN** it SHALL obtain information from UnifiedState
- **AND** it SHALL NOT directly observe VideoLoadingService
- **AND** it SHALL remove videoLoadingService @StateObject
- **AND** VideoLoadingService SHALL be managed by UnifiedState

#### Scenario: VideoLoadingOperationManager integration removal
- **WHEN** TrimmerView needs loading operation information
- **THEN** it SHALL obtain information from UnifiedState
- **AND** it SHALL NOT directly observe VideoLoadingOperationManager
- **AND** it SHALL remove loadingOperationManager @StateObject
- **AND** loading operation details SHALL come from UnifiedState.progress

#### Scenario: Progress publisher cleanup
- **WHEN** TrimmerView observes loading progress
- **THEN** it SHALL use UnifiedState.loadingProgress
- **AND** it SHALL remove videoLoadingService.progressPublisher subscription
- **AND** it SHALL remove redundant progress reporting code
- **AND** all progress information SHALL flow through UnifiedState

### Requirement: UI State Synchronization
TrimmerView UI state SHALL be synchronized with UnifiedState at all times.

#### Scenario: Loading UI synchronization
- **WHEN** UnifiedState indicates loading is complete
- **THEN** loadingView SHALL be hidden immediately
- **AND** videoTrimmerView SHALL be shown
- **AND** all loading-related UI elements SHALL be hidden
- **AND** retry options SHALL be hidden

#### Scenario: Progress UI synchronization
- **WHEN** UnifiedState loadingProgress changes
- **THEN** progress bar SHALL update to progress.progress value
- **AND** loading message SHALL update to progress.phase.displayName
- **AND** detailed progress information SHALL update accordingly
- **AND** progress phases indicator SHALL update

#### Scenario: Error UI synchronization
- **WHEN** UnifiedState error state changes
- **THEN** error view SHALL be shown or hidden based on hasError
- **AND** error message SHALL display unifiedState.errorMessage
- **AND** retry button SHALL be enabled for recoverable errors
- **AND** error details SHALL be shown in debug builds

### Requirement: State Change Handlers
TrimmerView SHALL implement proper state change handlers for UnifiedState observation.

#### Scenario: Flow state change handler
- **WHEN** unifiedState.flowState changes
- **THEN** onChange handler SHALL update UI immediately
- **AND** it SHALL log state transitions for debugging
- **AND** it SHALL handle state-specific UI updates
- **AND** it SHALL prevent redundant UI updates

#### Scenario: Selected video change handler
- **WHEN** unifiedState.selectedVideo changes
- **THEN** onChange handler SHALL load video in player
- **AND** it SHALL initialize trim values based on video duration
- **AND** it SHALL hide loading spinner
- **AND** it SHALL log successful video loading

#### Scenario: Error state change handler
- **WHEN** unifiedState.hasError changes
- **THEN** onChange handler SHALL update error UI
- **AND** it SHALL show/hide error view accordingly
- **AND** it SHALL update retry options
- **AND** it SHALL log error state changes

### Requirement: Diagnostic Logging Enhancement
TrimmerView SHALL provide comprehensive logging for state debugging.

#### Scenario: State transition logging
- **WHEN** any state change occurs
- **THEN** the change SHALL be logged with component name
- **AND** old and new state values SHALL be logged
- **AND** correlation ID SHALL be included when available
- **AND** timing information SHALL be included

#### Scenario: UI response logging
- **WHEN** UI updates in response to state changes
- **THEN** the UI change SHALL be logged
- **AND** the triggering state change SHALL be referenced
- **AND** any UI elements shown/hidden SHALL be logged
- **AND** user-visible changes SHALL be logged prominently

#### Scenario: Error logging with context
- **WHEN** errors are handled in TrimmerView
- **THEN** full error context SHALL be logged
- **AND** current state SHALL be included
- **AND** recovery attempts SHALL be logged
- **AND** user impact SHALL be assessed and logged