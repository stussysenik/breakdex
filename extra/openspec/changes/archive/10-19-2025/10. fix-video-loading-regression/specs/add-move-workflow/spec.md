## MODIFIED Requirements
### Requirement: Video Loading Completion
The AddMove workflow SHALL successfully complete video loading to 100% progress for all valid videos under 30 minutes in duration.

#### Scenario: Standard video loading completion
- **WHEN** user selects a valid video file
- **THEN** the loading progress SHALL advance monotonically to 100%
- **AND** the video SHALL be ready for trimming operations
- **AND** the workflow SHALL transition to Video Loaded state

#### Scenario: Cancel-trim-select-new-clip workflow
- **WHEN** user cancels trimming and selects a new video clip
- **THEN** the new video SHALL load from 0% to 100% without getting stuck
- **AND** the workflow SHALL successfully transition to Video Loaded state
- **AND** the user SHALL be able to trim the newly selected video

#### Scenario: Loading failure recovery
- **WHEN** video loading encounters an error
- **THEN** the system SHALL display appropriate error message
- **AND** the user SHALL be able to select a different video
- **AND** the subsequent loading attempt SHALL succeed if the new video is valid