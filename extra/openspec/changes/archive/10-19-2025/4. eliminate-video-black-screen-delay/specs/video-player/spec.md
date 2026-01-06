## MODIFIED Requirements

### Requirement: Video Player Instance Persistence
The SharedVideoPlayer SHALL maintain its AVPlayer instance in memory across tab navigation to enable instantaneous video display.

#### Scenario: Quick tab return (< 5s)
- **WHEN** user navigates away from Add Move tab with loaded video
- **AND** returns within 5 seconds
- **THEN** video displays instantaneously without black screen delay
- **AND** player instance remains loaded in memory

#### Scenario: Player state coordination
- **WHEN** MinimalTrimmerView appears after quick return
- **THEN** SharedVideoPlayer.isReady SHALL be true
- **AND** video frames SHALL be immediately visible

## ADDED Requirements

### Requirement: Player Lifecycle Management
The system SHALL distinguish between temporary view detachment and permanent player cleanup to optimize for quick return scenarios.

#### Scenario: View detachment without cleanup
- **WHEN** user navigates away from Add Move tab
- **THEN** SharedVideoPlayer SHALL detach from current view layer
- **AND** SHALL NOT cleanup AVPlayer instance or buffers
- **AND** SHALL cache player state for immediate restoration

#### Scenario: Quick return detection
- **WHEN** user returns to Add Move tab within 5 seconds
- **THEN** system SHALL detect quick return scenario
- **AND** SHALL reuse cached AVPlayer instance
- **AND** SHALL attach player to new view layer instantly

### Requirement: Diagnostic Logging
The system SHALL provide detailed timing metrics for player state transitions to enable performance optimization and debugging.

#### Scenario: Player state timing
- **WHEN** player state changes occur
- **THEN** system SHALL log timestamp, state, and source of transition
- **AND** SHALL measure time between view appearance and player readiness
- **AND** SHALL detect and log performance anomalies (> 100ms delays)

#### Scenario: Memory usage monitoring
- **WHEN** player instance persists in memory
- **THEN** system SHALL monitor memory usage
- **AND** SHALL log warnings if usage exceeds thresholds
- **AND** SHALL provide cleanup metrics for optimization

## REMOVED Requirements

### Requirement: Comprehensive Player Cleanup During Suspension
**Reason**: Comprehensive cleanup prevents instantaneous video display by requiring full player reload on return.

**Migration**: Replace with selective cleanup that maintains player instance for quick return scenarios while still managing memory appropriately for long-term navigation.