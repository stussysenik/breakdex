## MODIFIED Requirements

### Requirement: Workflow Suspension Logic
The AddMoveViewModel SHALL suspend workflow state without destroying video player resources to enable quick return scenarios.

#### Scenario: Quick return workflow restoration
- **WHEN** user returns to Add Move tab within 5 seconds
- **AND** video player instance is maintained in memory
- **THEN** workflow SHALL be restored to Video Loaded state
- **AND** MinimalTrimmerView SHALL display video immediately
- **AND** no black screen delay SHALL occur

#### Scenario: State coordination timing
- **WHEN** AddMoveView appears after quick return
- **THEN** view transition SHALL wait for SharedVideoPlayer.isReady
- **AND** currentStep SHALL change to trimming only after player readiness
- **AND** video SHALL appear instantaneously with view transition

### Requirement: Tab Navigation State Management
The AddMoveView SHALL coordinate view state transitions with video player readiness to eliminate temporal mismatch.

#### Scenario: Coordinated view appearance
- **WHEN** suspended workflow is detected on view appearance
- **AND** video player is ready
- **THEN** view SHALL transition to trimming state immediately
- **AND** video SHALL be visible without delay

#### Scenario: Player readiness verification
- **WHEN** preloading completes for quick return scenario
- **THEN** AddMoveView SHALL verify SharedVideoPlayer.isReady
- **AND** SHALL only show MinimalTrimmerView after verification
- **AND** SHALL log timing metrics for coordination verification

## ADDED Requirements

### Requirement: Temporal Coordination Validation
The system SHALL validate proper timing between async preloading and sync view appearance to ensure deterministic behavior.

#### Scenario: Preload completion verification
- **WHEN** preloadVideoForQuickReturn() completes
- **THEN** system SHALL measure completion time (< 500ms expected)
- **AND** SHALL verify player is ready for immediate display
- **AND** SHALL log coordination success or failure

#### Scenario: View transition timing
- **WHEN** currentStep changes to trimming
- **THEN** system SHALL measure time to video visibility (< 100ms expected)
- **AND** SHALL verify no black screen period occurs
- **AND** SHALL alert if coordination threshold exceeded