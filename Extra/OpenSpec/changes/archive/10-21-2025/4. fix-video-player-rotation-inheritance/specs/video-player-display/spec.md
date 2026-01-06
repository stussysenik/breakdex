## MODIFIED Requirements
### Requirement: Video Player Display Consistency
The system SHALL preserve video rotation across all stages of the add move workflow, ensuring that user-selected rotation applied during trimming remains visible in the naming and preview stages.

#### Scenario: Rotation preservation workflow
- **WHEN** user applies 90° rotation during video trimming
- **AND** navigates to the NameMoveView
- **THEN** the video SHALL display with 90° rotation applied

#### Scenario: Rotation consistency across all angles
- **WHEN** user applies any rotation (0°, 90°, 180°, 270°) during trimming
- **AND** navigates between workflow stages
- **THEN** the video SHALL maintain the selected rotation throughout

#### Scenario: Architecture consistency
- **WHEN** video is displayed in SelectClip, MinimalTrimmerView, or NameMoveView
- **THEN** the same underlying SharedVideoPlayer instance SHALL be used to ensure consistent state management