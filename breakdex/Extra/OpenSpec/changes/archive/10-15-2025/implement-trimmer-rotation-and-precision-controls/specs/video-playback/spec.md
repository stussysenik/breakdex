## MODIFIED Requirements

### Requirement: AVPlayer Integration
The AVPlayer system SHALL support real-time rotation transformations and precise seek operations while maintaining current loading performance characteristics.

#### Scenario: Player receives rotation transformation
- **WHEN** trimmer applies 90-degree rotation
- **THEN** AVPlayer renders video with applied rotation
- **AND** playback performance remains smooth
- **AND** loading time maintains 0.14s benchmark

#### Scenario: Player handles precise seeking
- **WHEN** user scrubs timeline with millisecond precision
- **THEN** AVPlayer seeks to exact frame position
- **AND** state synchronization preserves player readiness
- **AND** gap detection recovery maintains current reliability

### Requirement: Player State Synchronization
The player state management SHALL integrate trim and rotation states while maintaining existing state transition patterns.

#### Scenario: Player state transitions with modifications
- **WHEN** video has applied trim or rotation modifications
- **THEN** state transitions follow existing loadingVideo → ready → playing pattern
- **AND** gap detection handles modified player state correctly
- **AND** auto state sync preserves modification context

#### Scenario: Player gap recovery with modifications
- **WHEN** player idle gap is detected with modified video
- **THEN** enhanced loading recovery preserves all modifications
- **AND** player loads with rotation applied
- **AND** trim boundaries are maintained during recovery

## ADDED Requirements

### Requirement: Memory Management for Video Playback
The AVPlayer system SHALL implement efficient memory management for rotated and trimmed video playback.

#### Scenario: High memory usage during rotation
- **WHEN** video rotation processing exceeds memory thresholds
- **THEN** AVPlayer automatically reduces preview quality
- **AND** original quality is preserved for export
- **AND** user sees "Optimizing for performance" indicator

#### Scenario: Background processing during playback
- **WHEN** app enters background during video editing
- **THEN** video processing is automatically paused
- **AND** current state is preserved
- **AND** processing resumes seamlessly on return

### Requirement: Performance Monitoring
The system SHALL monitor and maintain playback performance across all device capabilities.

#### Scenario: Frame rate drops below threshold
- **WHEN** playback frame rate drops below 30fps
- **THEN** system automatically reduces visual effects
- **AND** quality adjustments are made smoothly
- **AND** user is notified of performance optimizations

#### Scenario: Battery optimization mode active
- **WHEN** device enables low power mode
- **THEN** video processing automatically optimizes for battery life
- **AND** non-real-time processing is deferred
- **AND** core functionality remains unaffected