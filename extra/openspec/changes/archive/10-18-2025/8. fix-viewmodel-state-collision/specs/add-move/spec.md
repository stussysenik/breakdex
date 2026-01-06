## MODIFIED Requirements

### Requirement: Video Loading State Management
The AddMove feature SHALL manage video loading state transitions using frame separation to prevent SwiftUI update coalescing issues that cause UI hangs.

#### Scenario: Smooth loading state progression
- **WHEN** video player initialization completes
- **THEN** loading state SHALL progress from 94% → 95% → 99% → 100% with visible UI updates for each stage
- **AND** each state transition SHALL occur in separate UI frames using `await Task.yield()`
- **AND** no "multiple updates per frame" warnings SHALL be generated

#### Scenario: Reliable video loading completion
- **WHEN** user initiates video loading in AddMove
- **THEN** loading UI SHALL consistently reach 100% completion
- **AND** video playback SHALL be ready immediately after loading completes
- **AND** diagnostic logs SHALL show frame separation timing for debugging

### Requirement: State Update Collision Prevention
The AddMove ViewModel SHALL prevent @Published state update collisions that occur when multiple state changes happen within the same UI frame.

#### Scenario: Frame-separated state updates
- **WHEN** multiple loadingState updates need to occur sequentially
- **THEN** each update SHALL be separated by `await Task.yield()`
- **AND** each update SHALL be logged with frame timestamp diagnostics
- **AND** the UI SHALL reflect each intermediate state before the final state

#### Scenario: Service layer responsibility restoration
- **WHEN** video loading operations are performed
- **THEN** SharedVideoPlayer SHALL use "fire-and-forget" Task pattern for business logic
- **AND** AddMoveViewModel SHALL handle UI state management with proper frame separation
- **AND** separation of concerns SHALL be maintained between service and view layers