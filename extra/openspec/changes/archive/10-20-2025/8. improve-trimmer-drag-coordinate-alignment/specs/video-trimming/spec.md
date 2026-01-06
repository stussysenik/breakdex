## MODIFIED Requirements

### Requirement: Handle Drag Interaction Precision
Users SHALL be able to drag trim handles with precise 1:1 coordination between finger movement and handle position.

#### Scenario: Finger-to-handle coordination
- **WHEN** a user places their finger on a trim handle and drags
- **THEN** the handle SHALL move in perfect sync with the finger movement
- **AND** there SHALL be no perceptible offset between finger position and handle center
- **AND** the handle SHALL remain under the user's finger throughout the drag gesture

#### Scenario: Coordinate system separation
- **WHEN** converting between time positions and visual coordinates
- **THEN** the coordinate functions SHALL work with pure mathematical mappings
- **AND** visual offsets SHALL be applied only in the view layer
- **AND** drag gesture coordinates SHALL be properly mapped to handle center positions

### Requirement: Accurate Coordinate-to-Time Mapping
The trimmer SHALL maintain mathematically consistent mapping between time positions and visual coordinates.

#### Scenario: Time-to-coordinate conversion (enhanced)
- **WHEN** converting a time position to a visual coordinate
- **THEN** the coordinate SHALL represent the position on the available track only
- **AND** handle width considerations SHALL be handled separately in the view layer
- **AND** the mapping SHALL be linear and proportional across the usable timeline

#### Scenario: Coordinate-to-time conversion (enhanced)
- **WHEN** converting a visual coordinate to a time position
- **THEN** the input coordinate SHALL represent the handle center position on the available track
- **AND** the time SHALL accurately reflect the handle center's position within the video duration
- **AND** the conversion SHALL handle coordinates that are already adjusted for handle geometry

#### Scenario: Drag gesture coordinate mapping
- **WHEN** processing drag gesture coordinates from finger position
- **THEN** the system SHALL subtract handle radius to map finger position to track coordinate
- **AND** the resulting time calculation SHALL accurately reflect the intended handle position
- **AND** the handle visual SHALL be positioned with radius offset for proper display