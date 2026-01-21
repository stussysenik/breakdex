## ADDED Requirements
### Requirement: Real Video Export to Photos Library
The system SHALL export trimmed video segments to the Photos library using AVAssetExportSession instead of generating placeholder identifiers.

#### Scenario: Successful trimmed video export
- **WHEN** a move is saved with trim boundaries
- **THEN** the system exports the trimmed video segment using AVAssetExportSession with the specified timeRange
- **AND** the exported video is saved to Photos library using PHPhotoLibrary.performChanges()
- **AND** the move entity stores the real Photos library identifier

#### Scenario: Video export failure handling
- **WHEN** video export fails due to insufficient permissions or disk space
- **THEN** the system provides a descriptive error message
- **AND** no placeholder identifier is generated
- **AND** temporary files are cleaned up

## MODIFIED Requirements
### Requirement: Video Asset Persistence
Move entities SHALL store real Photos library identifiers that reference actual video files in the Photos library.

#### Scenario: Move creation with trimmed video
- **WHEN** a user creates a move with trimmed video boundaries
- **THEN** the system exports the trimmed segment to Photos library
- **AND** stores the resulting Photos identifier in the move entity
- **AND** the identifier can be used to fetch the actual video asset

#### Scenario: Loading existing move video
- **WHEN** loading a move with a Photos identifier
- **THEN** PHAsset.fetchAssets(withLocalIdentifiers:) returns the actual video asset
- **AND** the video can be played within the specified trim boundaries
