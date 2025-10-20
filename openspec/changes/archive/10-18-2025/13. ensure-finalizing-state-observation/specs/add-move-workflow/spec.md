# Add Move Workflow - State Observation

## ADDED Requirements

### Requirement: State Frame Separation
The AddMoveViewModel SHALL ensure each loading state transition crosses UI frame boundaries to prevent SwiftUI observation coalescing.

#### Scenario: Complete State Progression Observation
**GIVEN** AddMoveViewModel is loading a video and transitions from preparingPlayback to finalizing state
**WHEN** the preparingPlayback state is set at 95% progress
**THEN** the system SHALL cross a UI frame boundary before setting the finalizing state
**AND** SelectClip SHALL observe the preparingPlayback state before the finalizing state is set
**AND** the finalizing state SHALL be observed by SelectClip at 99% progress

#### Scenario: Frame Boundary Enforcement
**GIVEN** multiple state updates need to occur in sequence
**WHEN** a state transition is initiated
**THEN** the system SHALL use `await MainActor.run { }` to ensure main thread execution
**AND** SHALL use `await Task.yield()` to cross UI frame boundaries
**AND** SHALL validate that the state was observed before proceeding

### Requirement: State Propagation Validation
The AddMoveViewModel SHALL provide diagnostic logging to verify state propagation timing between ViewModel and View layers.

#### Scenario: State Timing Diagnostics
**GIVEN** AddMoveViewModel sets a loading state
**WHEN** the state is set
**THEN** the system SHALL log the timestamp when the state is set
**AND** SHALL log the frame boundary information
**AND** SHALL measure the time until the state is observed by SelectClip

#### Scenario: Frame Coalescing Detection
**GIVEN** SelectClip observes state changes
**WHEN** multiple state updates occur within less than 16.67ms (one frame)
**THEN** the system SHALL log a warning about potential frame coalescing
**AND** SHALL identify which states may have been skipped
**AND** SHALL provide diagnostic information for debugging

### Requirement: MainActor Synchronization
All loading state updates SHALL occur on the MainActor with proper frame separation to ensure SwiftUI observation reliability.

#### Scenario: MainActor State Setting
**GIVEN** AddMoveViewModel needs to update loading state
**WHEN** setting a new loading state
**THEN** the update SHALL occur on the MainActor
**AND** SHALL be synchronized with UI frame boundaries
**AND** SHALL be observable by SwiftUI views

#### Scenario: Sequential State Updates
**GIVEN** a sequence of state updates (preparingPlayback → finalizing → fullyReady)
**WHEN** executing the sequence
**THEN** each state SHALL be set on MainActor with frame separation
**AND** each state SHALL be observed before the next state is set
**AND** the complete sequence SHALL be logged for diagnostic purposes

## MODIFIED Requirements

### Requirement: Loading State Transition Timing
The AddMoveViewModel SHALL implement enhanced frame separation between loading state transitions to ensure reliable UI observation.

#### Scenario: Enhanced State Transition Reliability
**GIVEN** the current state transition implementation using `await Task.yield()`
**WHEN** state transitions are occurring too rapidly for UI observation
**THEN** the implementation SHALL be enhanced with `await MainActor.run { }` synchronization
**AND** SHALL provide frame boundary guarantees between state updates
**AND** SHALL maintain existing MVVM architecture patterns