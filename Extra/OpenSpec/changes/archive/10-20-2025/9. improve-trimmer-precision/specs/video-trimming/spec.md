## ADDED Requirements

### Requirement: Frame-Precise Video Trimming
The video trimmer SHALL provide frame-level precision when users position trim handles, snapping to the nearest video frame rather than rounding to whole seconds.

#### Scenario: User drags start handle to precise position
- **WHEN** user drags the start trim handle and releases at a specific time position
- **THEN** the handle snaps to the nearest video frame boundary
- **AND** the time is calculated as `(nearestFrameNumber * frameDuration)`

#### Scenario: User drags end handle to precise position
- **WHEN** user drags the end trim handle and releases at a specific time position
- **THEN** the handle snaps to the nearest video frame boundary
- **AND** the time is calculated as `(nearestFrameNumber * frameDuration)`

#### Scenario: Frame rate unavailable
- **WHEN** the video frameRate is not available or is zero
- **THEN** the system falls back to second-level precision
- **AND** logs a warning about the fallback behavior

#### Scenario: High precision trimming for various frame rates
- **WHEN** trimming videos with different frame rates (24, 30, 60 fps)
- **THEN** the handle snapping respects the specific frame duration of each video
- **AND** maintains consistent precision across all supported frame rates