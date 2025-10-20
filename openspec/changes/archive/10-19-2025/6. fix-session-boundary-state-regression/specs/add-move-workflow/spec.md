## MODIFIED Requirements
### Requirement: @MainActor-Compliant Workflow Reset
The AddMoveViewModel SHALL support workflow reset with session boundary management using iOS 2024 concurrency patterns to enable reliable re-loading.

#### Scenario: Thread-safe cancel trimming workflow reset
- **WHEN** user cancels trimming operation
- **THEN** reset() method SHALL generate new session ID on @MainActor
- **AND** all loading state SHALL be cleared
- **AND** new loading session SHALL be immediately available
- **AND** all state changes SHALL respect MainActor isolation

#### Scenario: Video selection after session reset
- **WHEN** user selects new video after canceling trimming
- **THEN** loading SHALL proceed without state regression errors
- **AND** new session context SHALL be used for all state transitions
- **AND** loading progress SHALL start from 0% in new session
- **AND** all transitions SHALL occur on @MainActor

## ADDED Requirements
### Requirement: MainActor-Isolated Session State Management
The ViewModel SHALL maintain session state across user interactions with proper concurrency support to follow iOS 2024 best practices.

#### Scenario: Thread-safe session context preservation
- **WHEN** loading session is active
- **THEN** session ID SHALL remain constant throughout loading
- **AND** session context SHALL be included in all state validation
- **AND** diagnostic logs SHALL track session lifecycle
- **AND** all session operations SHALL be @MainActor-isolated

#### Scenario: Concurrency-safe multi-session workflow support
- **WHEN** user performs multiple load attempts in single session
- **THEN** each successful load SHALL complete with stable session ID
- **AND** failed loads SHALL not affect session validity
- **AND** user can retry loading without session conflicts
- **AND** all session state SHALL maintain proper isolation
- **AND** no race conditions SHALL occur during session transitions