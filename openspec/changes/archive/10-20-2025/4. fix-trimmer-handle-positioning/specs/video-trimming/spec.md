## MODIFIED Requirements

### Requirement: Handle Positioning Accuracy
Video trimmer handles SHALL be positioned with mathematical precision to align their visual center with their corresponding time positions on the timeline.

#### Scenario: Start handle at timeline beginning
- **WHEN** trim start time is 0.0 seconds
- **THEN** start handle center SHALL be positioned at timeline position 0 (visible left edge)
- **AND** handle SHALL NOT appear off-screen or offset from timeline

#### Scenario: End handle at timeline end
- **WHEN** trim end time equals video duration
- **THEN** end handle right edge SHALL align with timeline right edge
- **AND** handle center SHALL be mathematically consistent with end time position

#### Scenario: Handle drag gesture precision
- **WHEN** user drags either handle to any position on timeline
- **THEN** the resulting time calculation SHALL be mathematically inverse of position calculation
- **AND** drag gesture SHALL maintain 1:1 correspondence between touch position and time value

#### Scenario: Mathematical consistency validation
- **WHEN** handle is at position X pixels from timeline left edge
- **THEN** calculated time SHALL be (X / timelineWidth) × videoDuration
- **AND** inverse calculation SHALL return original position X

### Requirement: Minimum Duration Constraint Preservation
Video trimmer SHALL enforce minimum trim duration while maintaining accurate handle positioning.

#### Scenario: Minimum duration enforcement
- **WHEN** user attempts to drag handles closer than 3 seconds
- **THEN** system SHALL constrain handles to minimum 3-second separation
- **AND** visual feedback SHALL accurately represent constrained positions
- **AND** handle positioning SHALL remain mathematically accurate within constraints

### Requirement: Diagnostic Logging
Video trimmer SHALL provide diagnostic logging for handle positioning verification following iOS 18 coordinate space best practices.

#### Scenario: Handle position logging
- **WHEN** trimmer view appears or handles are repositioned
- **THEN** system SHALL log handle positions, corresponding times, and timeline dimensions
- **AND** logs SHALL include mathematical validation of position/time correspondence
- **AND** logs SHALL include coordinate space information for debugging gesture-to-position mapping
- **AND** diagnostic data SHALL follow Apple's recommended logging patterns for production debugging

#### Scenario: Coordinate space consistency
- **WHEN** drag gestures are processed on timeline
- **THEN** system SHALL maintain consistent coordinate space mapping per iOS 18 coordinateSpace guidelines
- **AND** gesture coordinates SHALL be properly transformed to timeline local coordinates
- **AND** coordinate transformations SHALL be validated in diagnostic logs