## MODIFIED Requirements
### Requirement: Session-Isolated Video Loading
The video loading system SHALL maintain complete session isolation to ensure reliable loading across user interactions, preventing cross-session state corruption that causes loading failures.

#### Scenario: First video loads successfully
- **WHEN** user selects first video clip
- **THEN** video loads to fullyReady state and transitions to trimming
- **AND** SharedVideoPlayer maintains clean state for current session

#### Scenario: User cancels trimming and selects new video
- **WHEN** user cancels trimming workflow and selects different video
- **THEN** reset() method SHALL clean up SharedVideoPlayer state completely
- **AND** new loading session SHALL start with fresh player state
- **AND** video SHALL load to fullyReady state without getting stuck

#### Scenario: Session boundary state isolation
- **WHEN** AddMoveViewModel.reset() is called
- **THEN** all SharedVideoPlayer observers SHALL be removed on MainActor
- **AND** current player item SHALL be replaced with nil
- **AND** new session ID SHALL be generated for clean state tracking
- **AND** subsequent loading SHALL use isolated player state

#### Scenario: MainActor-compliant cleanup operations
- **WHEN** session cleanup is performed
- **THEN** all player cleanup SHALL occur on MainActor
- **AND** KVO observer removal SHALL be thread-safe
- **AND** diagnostic logs SHALL include session ID and thread context

## ADDED Requirements
### Requirement: Session Boundary Diagnostics
The system SHALL provide minimal diagnostic logging to track session boundaries and verify proper isolation between loading sessions.

#### Scenario: Session boundary logging
- **WHEN** a new loading session begins
- **THEN** log SHALL include new session ID and timestamp
- **AND** log SHALL indicate previous session has been cleaned up
- **AND** all session operations SHALL be traceable through logs

#### Scenario: Player state verification
- **WHEN** SharedVideoPlayer cleanup completes
- **THEN** diagnostic log SHALL confirm player is in clean state
- **AND** log SHALL verify no observers remain registered
- **AND** next loading session SHALL start from verified clean state