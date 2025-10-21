## ADDED Requirements
### Requirement: Trim Boundary Enforcement
The system SHALL enforce video playback boundaries to only play the trimmed segment of saved moves.

#### Scenario: Apply trim range on load
- **WHEN** MoveDetailView loads a video with trim bounds
- **THEN** the system SHALL set AVPlayer.currentItem.forwardPlaybackEndTime to trimEndTime
- **AND** seek to trimStartTime position
- **AND** log successful trim range application

#### Scenario: Enforce playback boundaries
- **WHEN** video playback reaches the trim end time
- **THEN** the system SHALL automatically pause playback
- **AND** seek back to the trim start position
- **AND** log boundary enforcement event

#### Scenario: Handle missing trim bounds
- **WHEN** a move has trimStartTime equal to trimEndTime
- **THEN** the system SHALL play the full video without boundaries
- **AND** log that no trim bounds were applied

## MODIFIED Requirements
### Requirement: Video Asset Loading
The system SHALL load videos from Photos library using real Photos identifiers and apply trim boundaries during playback.

#### Scenario: Load video with real identifier
- **WHEN** MoveDetailView loads a move with valid photosIdentifier
- **THEN** the system SHALL fetch the asset using PhotosAssetLoader.fetchAsset()
- **AND** validate the asset exists and is playable
- **AND** load the asset into SharedVideoPlayer
- **AND** apply trim boundaries if specified

#### Scenario: Handle invalid Photos identifiers
- **WHEN** PhotosAssetLoader.fetchAsset() returns nil
- **THEN** the system SHALL display "Video not found in Photos library" error
- **AND** log the invalid identifier for debugging