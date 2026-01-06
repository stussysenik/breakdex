## MODIFIED Requirements

### Requirement: Single Observer Loading State Management
The AddMove feature SHALL use a single observer pattern for loading state to prevent SwiftUI update coalescing conflicts.

#### Scenario: Exclusive loading state observation
- **WHEN** AddMoveViewModel publishes loadingState changes
- **THEN** only SelectClip SHALL observe these changes directly
- **AND** AddMoveView SHALL NOT have onChange(of: loadingState) handler
- **AND** no "multiple updates per frame" warnings SHALL be generated

#### Scenario: Callback-based step transitions
- **WHEN** SelectClip completes loading state transitions
- **THEN** SelectClip SHALL notify AddMoveView via enhanced onStepChange callback
- **AND** step transitions (ready → selecting → trimming) SHALL work correctly
- **AND** AddMoveView SHALL orchestrate steps without observing loadingState

#### Scenario: Preserved frame separation
- **WHEN** AddMoveViewModel performs sequential loadingState updates
- **THEN** existing await Task.yield() frame separation SHALL be preserved
- **AND** loading progression 95% → 99% → 100% SHALL occur in separate UI frames
- **AND** diagnostic logs SHALL track frame separation effectiveness

### Requirement: Enhanced Diagnostic Logging
The AddMove feature SHALL provide diagnostic logging to identify observer conflicts and frame timing issues.

#### Scenario: Observer conflict detection
- **WHEN** loadingState changes occur
- **THEN** logs SHALL identify which view handles each state change
- **AND** logs SHALL track frame separation timing between state updates
- **AND** any remaining multi-observer conflicts SHALL be logged for debugging

#### Scenario: Loading completion verification
- **WHEN** video loading reaches 100% completion
- **THEN** logs SHALL confirm successful state propagation
- **AND** logs SHALL verify UI reflects final loading state
- **AND** any discrepancy between ViewModel and UI state SHALL be logged

## ADDED Requirements

### Requirement: Callback Communication Enhancement
The SelectClip view SHALL provide enhanced callback communication to AddMoveView for loading state completion.

#### Scenario: Loading completion callback
- **WHEN** SelectClip detects loadingState.fullyReady
- **THEN** SelectClip SHALL call onStepChange(.trimming)
- **AND** callback SHALL include loading completion context
- **AND** AddMoveView SHALL receive step transition without observing loadingState

#### Scenario: Error state communication
- **WHEN** SelectClip detects loadingState.error
- **THEN** SelectClip SHALL communicate error state via callback mechanism
- **AND** AddMoveView SHALL handle error state through callback interface
- **AND** error handling SHALL not require direct loadingState observation