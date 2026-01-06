## MODIFIED Requirements

### Requirement: Tab Navigation State Persistence
The AddMoveView SHALL preserve MinimalTrimmerView state when users navigate away from and back to the Add Move tab, maintaining video loading and trim state without requiring users to restart their work, following Apple's guidance that "View is a function of a state" and ensuring @State properly reflects @StateObject state.

#### Scenario: Tab navigation with loaded video
- **WHEN** user has loaded a video and is viewing the MinimalTrimmerView
- **AND** user navigates to a different tab
- **AND** user returns to the Add Move tab within 5 seconds
- **THEN** the MinimalTrimmerView SHALL be immediately visible with all video state preserved

#### Scenario: Fresh start for new sessions
- **WHEN** user navigates to the Add Move tab with no suspended workflow
- **THEN** the view SHALL initialize to the ready state for fresh video selection
- **AND** normal video loading workflow SHALL be available

#### Scenario: State synchronization during view recreation
- **WHEN** SwiftUI recreates the AddMoveView due to TabView navigation lifecycle
- **AND** the @StateObject ViewModel has a suspended workflow state
- **THEN** the @State view SHALL initialize to the trimming state instead of ready
- **AND** SHALL trigger ViewModel restoration immediately following Apple's "unidirectional data flow" pattern
- **AND** SHALL avoid side effects during view body computation

## ADDED Requirements

### Requirement: View State Synchronization
The AddMoveView SHALL synchronize its @State initialization with the @StateObject ViewModel's workflow state to ensure proper state preservation across SwiftUI view lifecycle events, following Apple's principle that "views should be lightweight and cheap" and avoiding side effects during view updates.

#### Scenario: Suspended workflow detection
- **WHEN** setupInitialState() is called during TabView view recreation
- **AND** viewModel.canRestoreWorkflow returns true
- **THEN** the view SHALL initialize to trimming state
- **AND** SHALL log "Detected suspended workflow - restoring to trimming"
- **AND** SHALL follow the pattern that "modifying state during view update causes undefined behavior"

#### Scenario: Restoration timing optimization
- **WHEN** a suspended workflow is detected during view initialization
- **THEN** restoration SHALL begin immediately in the same Task context
- **AND** SHALL not wait for onAppear lifecycle events (which fire after view appears)
- **AND** SHALL provide immediate visual feedback to user following iOS 18 TabView patterns
- **AND** SHALL maintain "unidirectional data flow" as recommended in modern MVVM SwiftUI

### Requirement: Diagnostic State Logging
The AddMoveView SHALL provide diagnostic logging for state synchronization events to help debug tab navigation persistence issues.

#### Scenario: State initialization logging
- **WHEN** setupInitialState() executes
- **THEN** it SHALL log whether a suspended workflow was detected
- **AND** SHALL log the resulting initial state (ready or trimming)
- **AND** SHALL include the viewTransitionID for tracking

#### Scenario: Restoration event logging
- **WHEN** workflow restoration is triggered during view initialization
- **THEN** it SHALL log the restoration start and completion
- **AND** SHALL include timing information for debugging
- **AND** SHALL follow existing emoji and formatting conventions