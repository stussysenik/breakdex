## MODIFIED Requirements
### Requirement: Main Thread State Updates
All SwiftUI @Published property updates SHALL occur on the main thread to prevent publishing changes from background threads errors. The system SHALL use MainActor.run for synchronous main thread operations and ensure proper concurrency compliance.

#### Scenario: State update from background context
- **WHEN** a background task needs to update @Published properties
- **THEN** the update SHALL be wrapped in MainActor.run or Task { @MainActor in ... }
- **AND** logging SHALL occur on the appropriate thread for the context

#### Scenario: Async state transition
- **WHEN** state transitions occur during async operations
- **THEN** all @Published property updates SHALL happen on the main thread
- **AND** logging SHALL preserve thread context for debugging

## ADDED Requirements
### Requirement: Swift 6 Concurrency Compliance
All async operations SHALL comply with Swift 6 concurrency requirements, including proper error handling in TaskGroup operations and correct function signatures for throwing functions.

#### Scenario: TaskGroup with throwing functions
- **WHEN** using TaskGroup with operations that can throw
- **THEN** function signatures SHALL correctly handle throwing vs non-throwing contexts
- **AND** error handling SHALL be properly implemented

#### Scenario: Pattern matching with tuples
- **WHEN** destructuring tuples in pattern matching
- **THEN** syntax SHALL follow Swift 6 requirements for valid patterns
- **AND** wildcard usage SHALL be limited to allowed contexts