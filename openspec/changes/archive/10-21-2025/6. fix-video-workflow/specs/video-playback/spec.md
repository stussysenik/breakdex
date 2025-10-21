## ADDED Requirements
### Requirement: Trim Boundary Enforcement
The system SHALL enforce video playback boundaries according to the move's trim start and end times.

#### Scenario: Video playback respects trim boundaries
- **WHEN** playing a move video
- **THEN** AVPlayer.forwardPlaybackEndTime is set to the trim end time
- **AND** a boundary time observer stops playback at the trim end
- **AND** automatic seek positions video at trim start time

#### Scenario: Trim boundary violation prevention
- **WHEN** user attempts to seek beyond trim boundaries
- **THEN** the system constrains playback within the trim range
- **AND** visual feedback shows the valid playback region

## MODIFIED Requirements
### Requirement: Video Asset Loading
MoveDetailView SHALL load video assets with trim range constraints applied.

#### Scenario: Load video with trim constraints
- **WHEN** MoveDetailView.loadVideoAsset() is called
- **THEN** the video asset is loaded with trim boundaries applied
- **AND** playback is automatically positioned at trim start
- **AND** end time is constrained to trim end position
