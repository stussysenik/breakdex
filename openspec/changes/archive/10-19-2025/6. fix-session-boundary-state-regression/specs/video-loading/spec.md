## MODIFIED Requirements
### Requirement: Session-Aware State Machine Validation
The loading system SHALL implement session-aware state validation following Apple's state machine patterns, ensuring monotonic transitions within sessions while allowing legitimate new loading sessions with proper @MainActor isolation.

#### Scenario: New session after cancel trimming (iOS 2024 pattern)
- **WHEN** user cancels trimming and selects a new video
- **THEN** fullyReady → loading transition SHALL be allowed as new session
- **AND** session ID SHALL be regenerated on @MainActor to distinguish from previous session
- **AND** state validation SHALL follow Apple's recommended state machine approach

#### Scenario: State regression within active session
- **WHEN** loading progress attempts to regress during active loading
- **THEN** transition SHALL be rejected to maintain monotonicity
- **AND** diagnostic log SHALL indicate session boundary violation
- **AND** rejection SHALL occur on @MainActor for thread safety

#### Scenario: Thread-safe session boundary detection
- **WHEN** ViewModel.reset() is called
- **THEN** new session ID SHALL be generated on @MainActor
- **AND** diagnostic log SHALL record session boundary event with thread context
- **AND** subsequent loading SHALL use new session context

## ADDED Requirements
### Requirement: @MainActor-Isolated Session Management
The loading system SHALL track session boundaries with proper MainActor isolation following iOS 2024 concurrency best practices.

#### Scenario: Session initialization with MainActor
- **WHEN** AddMoveViewModel is initialized
- **THEN** unique session ID SHALL be generated on @MainActor
- **AND** session ID SHALL be included in diagnostic logs
- **AND** all session state SHALL be MainActor-isolated

#### Scenario: Session reset with proper concurrency
- **WHEN** user cancels trimming workflow
- **THEN** reset() method SHALL generate new session ID on @MainActor
- **AND** previous session SHALL be marked as completed
- **AND** diagnostic log SHALL record session transition timing
- **AND** all state transitions SHALL maintain MainActor isolation

### Requirement: Thread-Safe Diagnostic Logging
The system SHALL provide minimal diagnostic logging that respects iOS 2024 concurrency patterns and MainActor isolation.

#### Scenario: MainActor-compliant session boundary logging
- **WHEN** session ID changes
- **THEN** log SHALL include old and new session IDs
- **AND** timestamp SHALL be recorded for session duration analysis
- **AND** logging SHALL occur on @MainActor for thread safety

#### Scenario: Thread-safe state transition validation
- **WHEN** state transition is evaluated
- **THEN** log SHALL include session context and validation result
- **AND** rejection reason SHALL be clearly stated for debugging
- **AND** all diagnostic operations SHALL respect MainActor isolation