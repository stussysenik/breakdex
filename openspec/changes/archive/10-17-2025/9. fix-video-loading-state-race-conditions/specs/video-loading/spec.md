## ADDED Requirements

### Requirement: Unified Video Loading State Management
The system SHALL maintain a single source of truth for video loading state through reactive observation, eliminating competing state management paradigms that cause UI binding breaks. The manual state assignments in AddMoveViewModel.handleVideoLoaded() SHALL be removed to prevent breaking the Combine observation chain from RobustVideoLoader.

#### Scenario: First video load succeeds
- **WHEN** user loads first video
- **THEN** state progresses from 0% to 100% through RobustVideoLoader observation
- **AND** no manual state setting interferes with loader state progression
- **AND** SharedVideoPlayer async boundary is properly handled

#### Scenario: Second video load succeeds without hanging
- **WHEN** user loads second video after first completes
- **THEN** state observation properly handles loader state reset
- **AND** no stale state (10%) from previous load interferes with new loading
- **AND** UI shows continuous progress from 0% to 100% without interruption

#### Scenario: State coordination during active loading
- **WHEN** video loading is in progress
- **THEN** AddMoveViewModel.handleVideoLoaded() SHALL NOT manually set loadingState
- **AND** only RobustVideoLoader state changes SHALL be processed via Combine observation
- **AND** manual state assignments SHALL be completely removed to prevent UI binding breaks

### Requirement: Async Boundary State Coordination
The system SHALL coordinate state transitions across async boundaries without breaking the reactive observation chain.

#### Scenario: SharedVideoPlayer initialization coordination
- **WHEN** RobustVideoLoader completes asset loading
- **AND** SharedVideoPlayer requires async initialization
- **THEN** the loader SHALL maintain loading state during player initialization
- **AND** SHALL transition to fullyReady only after player async completion
- **AND** SHALL not allow manual state overrides during this process

#### Scenario: Continuation-based state progression
- **WHEN** using withCheckedContinuation for async boundaries
- **THEN** the reactive observation SHALL remain the primary state source
- **AND** continuation completion SHALL trigger observed state change in loader
- **AND** ViewModel SHALL not set state directly based on continuation callback

### Requirement: State Transition Race Condition Prevention
The system SHALL prevent race conditions between different state update mechanisms through coordination guards.

#### Scenario: Loading state coordination guard
- **WHEN** video loading process begins
- **THEN** system SHALL establish coordination guard to prevent conflicting state updates
- **AND** SHALL allow only loader-originated state changes during loading
- **AND** SHALL reject manual state setting attempts until loading completes

#### Scenario: State override protection
- **WHEN** manual state setting is attempted during active loading
- **THEN** system SHALL log warning about race condition prevention
- **AND** SHALL ignore the manual state update
- **AND** SHALL maintain loader state as single source of truth

### Requirement: Comprehensive State Transition Logging
The system SHALL provide detailed logging for state transition debugging and race condition detection.

#### Scenario: State transition source tracking
- **WHEN** any state transition occurs
- **THEN** system SHALL log the source (loader vs manual)
- **AND** SHALL include coordination guard status
- **AND** SHALL indicate whether transition was accepted or rejected

#### Scenario: Race condition detection logging
- **WHEN** potential race condition is detected
- **THEN** system SHALL log detailed analysis of conflicting state changes
- **AND** SHALL include timing information and source attribution
- **AND** SHALL provide clear diagnostic information for debugging

## MODIFIED Requirements

### Requirement: AddMoveViewModel Video Loading Coordination
AddMoveViewModel SHALL coordinate video loading state changes exclusively through RobustVideoLoader observation, maintaining Single Responsibility Principle by avoiding direct state manipulation.

#### Scenario: Video loading initiation
- **WHEN** user initiates video loading through any loadVideo() method
- **THEN** AddMoveViewModel SHALL delegate all state management to RobustVideoLoader
- **AND** handleVideoLoaded() SHALL NOT manually assign loadingState = .assetReady(asset)
- **AND** SHALL NOT manually assign loadingState = .loading(progress: 0.76, ...)
- **AND** SHALL NOT manually assign loadingState = .fullyReady(asset)
- **AND** SHALL only observe and react to loader state changes

#### Scenario: Video loading completion handling
- **WHEN** RobustVideoLoader reports fullyReady state
- **THEN** AddMoveViewModel SHALL update selectedVideo and derived properties
- **AND** SHALL not trigger additional state transitions
- **AND** SHALL preserve loader state as final state

#### Scenario: Error state coordination
- **WHEN** RobustVideoLoader reports error state
- **THEN** AddMoveViewModel SHALL propagate error to UI properties
- **AND** SHALL not create conflicting loading states
- **AND** SHALL maintain error state until user initiates new action