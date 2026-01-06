## MODIFIED Requirements
### Requirement: Video Asset Persistence
The system SHALL save trimmed video segments to the Photos library and return real Photos identifiers that can be used to load the videos later.

#### Scenario: Save trimmed video to Photos library
- **WHEN** a user trims a video and saves a move
- **THEN** the system SHALL export the trimmed video segment to a temporary file
- **AND** save the trimmed video to the Photos library using PHPhotoLibrary.performChanges()
- **AND** return the real Photos library local identifier
- **AND** clean up the temporary file after successful save

#### Scenario: Handle video export failures
- **WHEN** video export fails during save
- **THEN** the system SHALL log specific error details
- **AND** throw MovePersistenceError with descriptive error message
- **AND** ensure no orphaned temporary files remain

#### Scenario: Request Photos library permissions
- **WHEN** saving a video for the first time
- **THEN** the system SHALL request Photos library add-only permissions
- **AND** throw MovePersistenceError.photosAccessDenied if permissions not granted

## ADDED Requirements
### Requirement: Trimmed Video Export
The system SHALL export video segments using AVAssetExportSession with precise timeRange boundaries.

#### Scenario: Create trimmed video composition
- **WHEN** trim bounds are provided (startTime, endTime)
- **THEN** the system SHALL create AVMutableComposition with video and audio tracks
- **AND** insert the specified timeRange from original asset
- **AND** preserve original video quality and audio synchronization

#### Scenario: Export with timeRange
- **WHEN** exporting trimmed video
- **THEN** the system SHALL configure AVAssetExportSession with timeRange
- **AND** use AVAssetExportPresetHighQuality preset
- **AND** set outputFileType to .mov for compatibility
- **AND** complete export within 10 seconds for 30-second videos