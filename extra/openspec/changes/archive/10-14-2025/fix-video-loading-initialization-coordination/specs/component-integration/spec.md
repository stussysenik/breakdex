## MODIFIED Requirements

### Requirement: Unified State Management Integration
All video loading components SHALL integrate through UnifiedState as the single source of truth.

#### Scenario: Component state coordination
- **WHEN** any video loading component updates its state
- **THEN** it SHALL notify UnifiedState of the change
- **AND** UnifiedState SHALL coordinate state updates to all dependent components
- **AND** components SHALL NOT directly communicate with each other for state changes

#### Scenario: Progress reporting through UnifiedState
- **WHEN** VideoLoadingService or VideoLoadingOperationManager reports progress
- **THEN** the progress SHALL be routed through UnifiedState.updateProgress()
- **AND** UnifiedState SHALL coordinate progress updates to all UI components
- **AND** UI components SHALL observe UnifiedState for progress changes

#### Scenario: Error state coordination
- **WHEN** any component encounters an error
- **THEN** the error SHALL be reported to UnifiedState.setError()
- **AND** UnifiedState SHALL coordinate error state to all UI components
- **AND** UI components SHALL display error state based on UnifiedState.hasError

### Requirement: TrimmerView Integration Simplification
TrimmerView SHALL simplify its integration by relying entirely on UnifiedState for video loading state.

#### Scenario: Loading state elimination
- **WHEN** TrimmerView needs to show loading state
- **THEN** it SHALL derive loading state from UnifiedState.flowState
- **AND** it SHALL NOT maintain separate isLoadingVideo state variable
- **AND** loading message SHALL be derived from UnifiedState.loadingProgress.phase

#### Scenario: Video asset integration
- **WHEN** TrimmerView needs to display a video
- **THEN** it SHALL use UnifiedState.selectedVideo as the video source
- **AND** it SHALL observe changes to UnifiedState.selectedVideo
- **AND** video player SHALL be updated immediately when asset changes

#### Scenario: Progress UI integration
- **WHEN** TrimmerView displays loading progress
- **THEN** it SHALL use UnifiedState.loadingProgress for all progress information
- **AND** it SHALL NOT use VideoLoadingOperationManager.currentProgress directly
- **AND** progress phases SHALL be consistent with UnifiedState state

### Requirement: Service Integration Coordination
VideoLoadingService and VideoLoadingOperationManager SHALL coordinate their integration with UnifiedState.

#### Scenario: Service collaboration
- **WHEN** VideoLoadingService is used
- **THEN** VideoLoadingOperationManager SHALL coordinate with the service
- **AND** both SHALL report to the same UnifiedState instance
- **AND** correlation IDs SHALL be shared between services

#### Scenario: Operation lifecycle coordination
- **WHEN** VideoLoadingOperationManager starts an operation
- **THEN** it SHALL coordinate with VideoLoadingService for the actual loading
- **AND** UnifiedState SHALL track the operation through its lifecycle
- **AND** completion SHALL be reported through UnifiedState methods

### Requirement: State Change Propagation
State changes SHALL propagate correctly through the component hierarchy.

#### Scenario: Top-down state propagation
- **WHEN** UnifiedState updates loadingProgress
- **THEN** all observing components SHALL receive the update
- **AND** TrimmerView SHALL update its UI immediately
- **AND** the update SHALL include correlation ID for debugging

#### Scenario: Bottom-up state reporting
- **WHEN** VideoLoadingService completes loading
- **THEN** it SHALL report success to UnifiedState
- **AND** UnifiedState SHALL update flowState to .trimming
- **AND** TrimmerView SHALL automatically receive the state change

#### Scenario: Lateral state synchronization
- **WHEN** VideoLoadingOperationManager updates progress
- **THEN** it SHALL coordinate with VideoLoadingService progress
- **AND** both SHALL maintain consistent state through UnifiedState
- **AND** conflicts SHALL be resolved with defined precedence rules

### Requirement: Component Lifecycle Management
Component lifecycles SHALL be managed to prevent state desynchronization.

#### Scenario: Component initialization
- **WHEN** components initialize
- **THEN** UnifiedState SHALL initialize first
- **AND** services SHALL initialize with reference to UnifiedState
- **AND** UI components SHALL initialize to observe UnifiedState
- **AND** initialization order SHALL be deterministic

#### Scenario: Component cleanup
- **WHEN** components are deallocated
- **THEN** they SHALL remove observers from UnifiedState
- **AND** services SHALL cancel ongoing operations
- **AND** UnifiedState SHALL maintain consistent state during cleanup

#### Scenario: State restoration
- **WHEN** components are recreated
- **THEN** they SHALL restore state from UnifiedState
- **AND** UnifiedState SHALL maintain state across component lifecycles
- **AND** no redundant loading operations SHALL be triggered

### Requirement: Error Handling Integration
Error handling SHALL be integrated across all components through UnifiedState.

#### Scenario: Error propagation
- **WHEN** an error occurs in any component
- **THEN** the error SHALL propagate to UnifiedState
- **AND** UnifiedState SHALL coordinate error state to all components
- **AND** UI components SHALL display consistent error information

#### Scenario: Error recovery coordination
- **WHEN** error recovery is attempted
- **THEN** all components SHALL coordinate through UnifiedState
- **AND** retry operations SHALL be managed centrally
- **AND** recovery progress SHALL be tracked consistently

#### Scenario: Error state clearing
- **WHEN** errors are cleared
- **THEN** UnifiedState.clearError() SHALL be called
- **AND** all components SHALL reset error state
- **AND** normal operation SHALL resume seamlessly

### Requirement: Performance Optimization Integration
Performance optimizations SHALL be integrated across all components.

#### Scenario: Lazy loading coordination
- **WHEN** video data is needed
- **THEN** components SHALL coordinate lazy loading through UnifiedState
- **AND** loading SHALL be triggered only when necessary
- **AND** cached data SHALL be shared between components

#### Scenario: Memory management coordination
- **WHEN** memory pressure occurs
- **THEN** UnifiedState SHALL coordinate cleanup across components
- **AND** unnecessary resources SHALL be released
- **AND** critical state SHALL be preserved

#### Scenario: Background operation coordination
- **WHEN** background operations are needed
- **THEN** they SHALL be coordinated through UnifiedState
- **AND** progress SHALL be reported consistently
- **AND** cancellation SHALL be handled gracefully