## MODIFIED Requirements

### Requirement: Video Container Layout
The system SHALL display video content within properly sized containers that account for rotation transforms.

#### Scenario: Video fits container at any rotation
- **WHEN** a video with any dimensions is loaded with rotation transform
- **THEN** the video SHALL fit within the container bounds without overflow
- **AND** the system SHALL NOT generate CoreGraphics NaN errors

#### Scenario: Portrait video with 90° rotation
- **WHEN** a 1080x1920 video is displayed with 90° rotation
- **THEN** the effective 1920x1080 dimensions SHALL fit within container bounds
- **AND** container SHALL use aspect ratio fitting to prevent overflow

#### Scenario: Container overflow detection
- **WHEN** video dimensions exceed container capacity
- **THEN** diagnostic logs SHALL report exact overflow measurements
- **AND** clipping SHALL prevent visual overflow beyond container

### Requirement: Video Display Stability
The system SHALL maintain stable video rendering without numeric errors.

#### Scenario: Prevent CoreGraphics NaN errors
- **WHEN** video content is loaded and displayed
- **THEN** all dimension calculations SHALL produce valid numeric values
- **AND** no CoreGraphics NaN errors SHALL be generated

#### Scenario: Navigation system reliability
- **WHEN** video container is properly sized
- **THEN** MoveDetailView navigation SHALL function correctly
- **AND** navigation SHALL NOT be affected by video layout issues

### Requirement: Diagnostic Logging
The system SHALL provide minimal diagnostic information for video container issues.

#### Scenario: Container dimension logging
- **WHEN** video content is loaded
- **THEN** original video dimensions SHALL be logged
- **AND** effective rotated dimensions SHALL be logged
- **AND** container dimensions SHALL be logged
- **AND** overflow calculations SHALL be logged if applicable