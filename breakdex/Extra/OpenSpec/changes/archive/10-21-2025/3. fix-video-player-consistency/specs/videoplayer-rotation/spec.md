# Video Player Rotation Specification

## ADDED Requirements

### Rotation-Aware Video Player
**Requirement**: All video players must use SharedVideoPlayer to properly handle video rotation metadata.

#### Scenario: NameMoveView displays video preview with rotation
- **GIVEN** User has trimmed a video with rotation (e.g., 90°)
- **WHEN** NameMoveView displays the video preview
- **THEN** SharedVideoPlayer should create rotation-aware player
- **AND** Video should display with correct orientation
- **AND** Enhanced logging should confirm "ROTATION_PROOF: SharedVideoPlayer created with rotation X°"

#### Scenario: MoveDetailView displays video with rotation
- **GIVEN** Move has stored rotation metadata in Core Data
- **WHEN** MoveDetailView loads and displays the video
- **THEN** SharedVideoPlayer should apply correct rotation transform
- **AND** Video should play in correct orientation
- **AND** Logging should confirm rotation metadata flow from storage to display

## MODIFIED Requirements

### Video Player Creation Pattern
**Requirement**: Standardize all video player creation to use SharedVideoPlayer instead of raw AVPlayer instances.

#### Scenario: NameMoveView video player creation
- **GIVEN** NameMoveView needs to display video preview
- **WHEN** Creating video player
- **THEN** Must use SharedVideoPlayer(mode: .preview) instead of AVPlayer(playerItem:)
- **AND** Must pass rotation metadata from AddMoveViewModel
- **AND** Must log "VIDEO_PLAYER_PROOF: SharedVideoPlayer created successfully"

#### Scenario: Rotation metadata validation
- **GIVEN** Video player is created with rotation data
- **WHEN** Player loads video asset
- **THEN** Rotation should be applied via AVPlayerLayer transform
- **AND** Enhanced logging should capture rotation application
- **AND** Video should display in correct orientation without distortion

