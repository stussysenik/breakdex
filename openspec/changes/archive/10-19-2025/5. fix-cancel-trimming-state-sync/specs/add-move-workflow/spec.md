## MODIFIED Requirements

### Requirement: State Synchronization Between ViewModel and View
The AddMoveView SHALL maintain synchronization with AddMoveViewModel state changes using SwiftUI's onChange modifier to ensure deterministic user interface transitions on the main actor.

#### Scenario: Cancel button transitions to video selection
- **WHEN** user taps "Cancel" during video trimming
- **AND** cancelTrimming() calls viewModel.reset()
- **AND** viewModel.loadingState changes to idle
- **THEN** AddMoveView SHALL detect this state change via onChange modifier
- **AND** AddMoveView SHALL update currentStep from trimming to ready on main thread
- **AND** viewTransitionID SHALL be regenerated for proper view lifecycle
- **AND** user SHALL be returned to video selection screen

#### Scenario: State transition logging for debugging
- **WHEN** viewModel.loadingState changes
- **AND** AddMoveView observes the change via onChange
- **THEN** system SHALL log the state transition details
- **AND** log SHALL include previous state, new state, and currentStep transition
- **AND** log SHALL be categorized for easy debugging
- **AND** logging SHALL occur on main thread for consistency

## ADDED Requirements

### Requirement: Automatic View State Recovery
When ViewModel state resets to idle during trimming, the View SHALL automatically recover to ready state without user intervention using SwiftUI's reactive state management.

#### Scenario: Async state transition handling
- **WHEN** viewModel.reset() is called asynchronously from cancelTrimming()
- **AND** loadingState transitions to idle after async completion
- **THEN** AddMoveView SHALL observe the async state change via onChange modifier
- **AND** currentStep SHALL be updated to ready automatically on main thread
- **AND** viewTransitionID SHALL be regenerated for proper view lifecycle
- **AND** View SHALL re-render SelectClip component immediately

#### Scenario: State transition validation
- **WHEN** currentStep transitions from trimming to ready
- **THEN** system SHALL validate the transition context (loadingState == .idle)
- **AND** system SHALL log successful transition with timing information
- **AND** diagnostic information SHALL include transition duration and thread context
- **AND** logging SHALL follow existing AppLogger protocol with metadata parameter