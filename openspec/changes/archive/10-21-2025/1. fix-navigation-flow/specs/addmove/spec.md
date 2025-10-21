# Add Move Feature Delta

## MODIFIED Requirements

### State Management and Navigation

#### Scenario: Complete Workflow Navigation
**When** user trims video in MinimalTrimmerView and hits "Submit"
**Then** AddMoveView automatically transitions to NameMoveView
**And** NameMoveView displays the exact trimmed and rotated video

#### Scenario: Save Completion Navigation
**When** user saves move in NameMoveView
**Then** AddMoveView automatically transitions to complete state
**And** user returns to Arsenal tab with new move visible

#### Scenario: State Observation Pattern
**When** AddMoveViewModel publishes state changes
**Then** AddMoveView observers detect and handle transitions
**And** diagnostic logging records all state transitions for debugging

## ADDED Requirements

### ViewModel Save State Management

#### Scenario: Centralized Save Operations
**When** NameMoveView initiates save operation
**Then** AddMoveViewModel handles all save logic
**And** publishes save state via `@Published saveState` property
**And** NameMoveView only handles UI input and display

#### Scenario: Save State Enumeration
**When** save operation is in progress
**Then** `saveState` reflects current status (.idle, .saving, .saved, .failed)
**And** AddMoveView observers respond to state changes
**And** UI updates accordingly

## REMOVED Requirements

### Dual State Management

#### Scenario: MVVM Violation Elimination
**When** NameMoveView needs to save a move
**Then** it cannot use separate MoveSaver service
**And** must route all operations through AddMoveViewModel
**And** maintain single source of truth for state

## MODIFIED Implementation Details

### AddMoveView State Observers

**Line 114-128**: Add missing state observers:
```swift
.onChange(of: viewModel.currentTrimModification) { _, modification in
    if modification != nil {
        logger.info("🔄 NAVIGATION: Trim modification detected, transitioning to naming")
        currentStep = .naming
    }
}

.onChange(of: viewModel.saveState) { _, state in
    if case .saved = state {
        logger.info("🔄 NAVIGATION: Save completed, transitioning to complete")
        currentStep = .complete
    }
}
```

### AddMoveViewModel Save Management

**New Properties:**
```swift
@Published var saveState: SaveState = .idle

enum SaveState {
    case idle
    case saving
    case saved(Move)
    case failed(Error)
}
```

**New Methods:**
```swift
func saveMove(name: String) async {
    // Centralized save logic with state management
    // Diagnostic logging for all phases
    // Error handling and state updates
}
```

### NameMoveView Simplification

**Removed:** MoveSaver dependency and save state management
**Added:** ViewModel save method calls with diagnostic logging