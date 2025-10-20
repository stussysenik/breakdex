# SwiftUI View Invalidation Fix Specification

## ADDED Requirements

### Requirement: Ensure Immediate View Transition After Video Loading
The app MUST provide immediate visual feedback when video loading completes, transitioning from the SelectClip interface to MinimalTrimmerView without delay or user confusion.

#### Scenario: User selects video and loading completes
**Given** the user selects a video from PhotosPicker
**And** the video loading reaches 100%
**When** the AddMoveViewModel transitions to `fullyReady` state
**Then** the app must immediately show MinimalTrimmerView within 100ms

#### Scenario: State change triggers view recomposition
**Given** AddMoveView `currentStep` changes from `ready` to `trimming`
**When** the state transition occurs
**Then** SwiftUI must recompose the view and render MinimalTrimmerView
**And** the view transition ID must change to force invalidation

### Requirement: Provide Diagnostic Visibility
The system MUST provide comprehensive logging for view transitions and state changes to enable effective debugging and monitoring of the SwiftUI view lifecycle.

#### Scenario: View transition debugging
**Given** a view transition occurs between steps
**When** the transition happens
**Then** the system must log the old step, new step, and view transition ID
**And** the logs must show view appearance confirmation

#### Scenario: State synchronization tracking
**Given** any change to `currentStep` or `viewTransitionID`
**When** the change occurs
**Then** the system must log the change with timestamp
**And** the logs must show the change propagated to SwiftUI

### Requirement: Maintain MVVM Architecture
All view invalidation fixes MUST respect the Model-View-ViewModel pattern, ensuring clear separation between state management (ViewModel) and view rendering (View) responsibilities.

#### Scenario: View invalidation implementation
**Given** the need to fix view rendering
**When** implementing view invalidation fixes
**Then** all changes must respect MVVM separation of concerns
**And** ViewModel must handle state, View must handle rendering only

## MODIFIED Requirements

### Requirement: SwiftUI View Composition
The AddMoveView MUST use explicit view identity and state synchronization patterns to ensure SwiftUI properly processes step-based view transitions and renders the correct interface.

#### Scenario: Step-based view rendering
**Given** AddMoveView uses switch statement on `currentStep`
**When** `currentStep` equals `trimming`
**Then** render MinimalTrimmerView with explicit view identity
**And** add view lifecycle logging for debugging

#### Scenario: State transition handling
**Given** AddMoveView receives state change request
**When** `handleStepChange` is called
**Then** update `currentStep` and `viewTransitionID` atomically
**And** use `await Task.yield()` to ensure SwiftUI processes changes