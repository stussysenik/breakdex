## MODIFIED Requirements

### Requirement: Atomic State Transitions
The SharedVideoPlayer SHALL ensure @Published property updates are atomic and occur in separate UI frames to prevent SwiftUI observation throttling.

#### Scenario: Frame-Separated Property Updates
- **WHEN** video player initialization completes and state needs to be finalized
- **THEN** `state` property update SHALL occur in separate UI frame from `isReady` update
- **AND** each @Published change SHALL use MainActor.run scheduling for guaranteed frame separation
- **AND** iOS 18 @MainActor SHALL enforce main-thread execution with compiler validation
- **AND** maintain existing VideoPlayer behavior and API contracts

#### Scenario: SwiftUI Change Detection Compatibility
- **WHEN** multiple @Published properties need updating in response to player readiness
- **THEN** the system SHALL use MainActor.run scheduling to ensure separate UI frames
- **AND** prevent "onChange action tried to update multiple times per frame" warnings
- **AND** ensure subsequent @Published changes from other ViewModels propagate correctly
- **AND** leverage iOS 18's enhanced @MainActor SwiftUI View protocol enforcement

#### Scenario: KVO-Triggered State Updates
- **WHEN** AVPlayerItem status changes trigger player ready state
- **THEN** KVO response methods SHALL use the same frame-separated approach
- **AND** finalizePlayerReadyState() SHALL use MainActor.run for temporal separation
- **AND** ensure consistent behavior across all state transition code paths

## ADDED Requirements

### Requirement: @Published Update Diagnostics
The SharedVideoPlayer SHALL provide minimal diagnostic logging for @Published property update timing verification.

#### Scenario: Property update timing verification
- **WHEN** @Published properties are updated during state transitions
- **THEN** log timestamps for each property change with millisecond precision
- **AND** verify frame-aligned temporal separation through logging
- **AND** confirm no @Published collision occurs during state finalization
- **AND** log when "multiple updates per frame" warning is eliminated

#### Scenario: State propagation validation
- **WHEN** SharedVideoPlayer completes loading and finalizes state
- **THEN** log that AddMoveViewModel updates can now propagate correctly
- **AND** verify final state reaches 100% completion without throttling
- **AND** confirm no UI observation interference occurs
- **AND** provide clear diagnostic trail for future debugging

#### Scenario: Performance impact monitoring
- **WHEN** frame-separated @Published updates are implemented
- **THEN** log the timing difference between property updates
- **AND** verify no significant performance degradation
- **AND** monitor that video loading completes within expected timeframes