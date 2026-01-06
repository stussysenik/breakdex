## MODIFIED Requirements
### Requirement: Robust Workflow Reset with Player Cleanup
The AddMoveViewModel SHALL provide complete workflow reset including SharedVideoPlayer cleanup to ensure reliable subsequent video loading operations.

#### Scenario: Complete workflow reset on cancel
- **WHEN** user cancels trimming operation
- **THEN** reset() method SHALL generate new session ID on MainActor
- **AND** SharedVideoPlayer cleanup SHALL be called before state reset
- **AND** all player state SHALL be cleared for fresh loading session
- **AND** diagnostic log SHALL record successful session boundary

#### Scenario: Video selection after reset
- **WHEN** user selects new video after workflow reset
- **THEN** loading SHALL proceed with clean SharedVideoPlayer state
- **AND** loading SHALL progress through all stages to fullyReady
- **AND** UI SHALL transition to trimming without getting stuck
- **AND** all state transitions SHALL occur on MainActor

## ADDED Requirements
### Requirement: Reset Success Diagnostics
The reset operation SHALL provide diagnostic logging to verify successful cleanup and session isolation.

#### Scenario: Reset completion verification
- **WHEN** AddMoveViewModel.reset() completes
- **THEN** diagnostic log SHALL confirm SharedVideoPlayer cleanup success
- **AND** log SHALL include session ID transition timing
- **AND** next loading attempt SHALL start from verified clean state