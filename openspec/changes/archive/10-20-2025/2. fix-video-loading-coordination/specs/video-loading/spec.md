## ADDED Requirements

### Requirement: Video Loading Coordination
The system SHALL coordinate video asset loading with SharedVideoPlayer initialization before transitioning to the trimming interface.

#### Scenario: Successful coordination flow
- **WHEN** RobustVideoLoader completes asset loading (LoadingState.fullyReady)
- **AND** SelectClip handles the fullyReady state
- **THEN** SharedVideoPlayer.loadVideo(asset) SHALL be called
- **AND** the system SHALL wait for the player to become ready
- **AND** the app SHALL transition to trimming only after videoPlayer.isReady = true

#### Scenario: Asset validation before player loading
- **WHEN** SelectClip receives LoadingState.fullyReady
- **THEN** the system SHALL validate that selectedVideo asset exists
- **AND** SHALL proceed with player loading only if asset is valid
- **AND** SHALL handle invalid asset state appropriately

#### Scenario: Error handling for player initialization
- **WHEN** SharedVideoPlayer.loadVideo() fails to initialize
- **THEN** the system SHALL handle the error gracefully
- **AND** SHALL maintain appropriate error state in the UI
- **AND** SHALL provide feedback to the user about the failure

#### Scenario: Prevention of duplicate initialization
- **WHEN** SelectClip receives multiple fullyReady states
- **THEN** the system SHALL prevent duplicate SharedVideoPlayer.loadVideo() calls
- **AND** SHALL validate current player state before attempting initialization
- **AND** SHALL maintain idempotent behavior for coordination logic

### Requirement: Async Coordination Pattern
The system SHALL use proper async/await patterns for video player coordination operations.

#### Scenario: Main actor isolation
- **WHEN** performing SharedVideoPlayer operations
- **THEN** all operations SHALL be executed on the MainActor
- **AND** SHALL maintain proper UI thread synchronization
- **AND** SHALL prevent race conditions in player state updates

#### Scenario: Error propagation
- **WHEN** player loading encounters an error
- **THEN** the error SHALL be properly propagated through the async chain
- **AND** SHALL be caught and handled at appropriate coordination points
- **AND** SHALL not cause unhandled promise rejections

### Requirement: Diagnostic Coordination Logging
The system SHALL provide diagnostic logging for video loading coordination debugging.

#### Scenario: Coordination step logging
- **WHEN** SelectClip begins player coordination
- **THEN** the system SHALL log the coordination start
- **AND** SHALL log player loading progress
- **AND** SHALL log successful coordination completion

#### Scenario: State validation logging
- **WHEN** validating player readiness
- **THEN** the system SHALL log current player state
- **AND** SHALL log asset validation results
- **AND** SHALL log any coordination errors with context