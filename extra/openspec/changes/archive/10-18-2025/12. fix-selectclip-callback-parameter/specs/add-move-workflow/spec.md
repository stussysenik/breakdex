## MODIFIED Requirements

### Requirement: SwiftUI View State Composition
The AddMoveView component SHALL properly execute view composition changes when @State properties change to ensure correct SwiftUI view switching.

#### Scenario: State change triggers view recomposition
- **WHEN** currentStep changes from .ready to .trimming
- **AND** SwiftUI detects the @State change
- **THEN** the switch statement shall execute the .trimming case
- **AND** MinimalTrimmerView shall be rendered
- **AND** MinimalTrimmerView.onAppear shall be called

#### Scenario: View composition validation
- **WHEN** handleStepChange updates currentStep
- **THEN** log SwiftUI state change detection
- **AND** verify which switch case is executed
- **AND** confirm target view appears

### Requirement: State Transition Diagnostics
The AddMoveView component SHALL provide comprehensive diagnostic logging to track view composition issues and state propagation.

#### Scenario: Complete transition tracking
- **WHEN** video loading completes and transition to trimming begins
- **THEN** log callback initiation, state update, and view appearance
- **AND** track thread execution and main thread compliance
- **AND** verify each step in the transition chain

### Requirement: SwiftUI Recomposition Assurance
The AddMoveView SHALL ensure SwiftUI properly recomputes view hierarchy when state changes occur using iOS 18 standard patterns.

#### Scenario: Forced view recomposition using explicit IDs
- **WHEN** @State changes don't trigger expected view updates
- **THEN** use explicit view ID property with id() modifier
- **AND** update view ID when currentStep changes to .trimming
- **AND** ensure SwiftUI treats the view as a new instance
- **AND** validate MinimalTrimmerView appears correctly

#### Scenario: iOS 18 compliance
- **WHEN** implementing view switching solutions
- **THEN** follow Apple's recommended @State-driven UI patterns
- **AND** use standard SwiftUI view lifecycle modifiers
- **AND** maintain main thread compliance for state updates