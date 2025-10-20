## MODIFIED Requirements

### Requirement: Trimmer Handle Initialization Timing
Video trimmer handles SHALL be positioned using correct trim time values during view initialization, ensuring mathematical consistency between time positions and visual coordinates following iOS 18 coordinate space best practices.

#### Scenario: Correct handle positioning at timeline start
- **WHEN** trim view appears and ViewModel trimStartTime = 0.0s
- **THEN** left handle SHALL be positioned at timeline position 0 (visible left edge)
- **AND** handle positioning SHALL use ViewModel trim values, not uninitialized defaults
- **AND** coordinate calculations SHALL use GeometryReader local coordinate space

#### Scenario: Correct handle positioning at timeline end
- **WHEN** trim view appears and ViewModel trimEndTime = videoDuration
- **THEN** right handle SHALL be positioned at timeline right edge
- **AND** handle positioning calculations SHALL have videoDuration > 0 to prevent undefined arithmetic
- **AND** positioning SHALL wait for async video duration loading to complete

#### Scenario: State propagation verification with async loading
- **WHEN** MinimalTrimmerView initializes
- **THEN** startTime SHALL inherit from viewModel.trimStartTime before handle positioning
- **AND** endTime SHALL inherit from viewModel.trimEndTime before handle positioning
- **AND** videoDuration SHALL be loaded via async AVFoundation `load(.duration)` before coordinate calculations
- **AND** coordinate space SHALL be properly established before `.onAppear` executes

#### Scenario: Mathematical consistency validation with proper timing
- **WHEN** handle is positioned at time X with videoDuration D
- **THEN** handle offset SHALL be (timelineWidth × X ÷ D) with D > 0
- **AND** the inverse calculation SHALL return the original time X
- **AND** logs SHALL verify the mathematical relationship after async loading completes
- **AND** coordinate calculations SHALL use proper local coordinate space from GeometryReader

### Requirement: Diagnostic Logging for Handle Positioning
Video trimmer SHALL provide minimal diagnostic logging to verify trim value propagation and handle positioning correctness following production best practices.

#### Scenario: Async loading coordination logging
- **WHEN** MinimalTrimmerView begins initialization
- **THEN** system SHALL log ViewModel trimStartTime/trimEndTime values
- **AND** system SHALL log video duration loading status (loaded/pending)
- **AND** system SHALL log coordinate space availability from GeometryReader

#### Scenario: State propagation verification logging
- **WHEN** MinimalTrimmerView inherits ViewModel trim values
- **THEN** system SHALL log ViewModel trimStartTime/trimEndTime values
- **AND** system SHALL log local startTime/endTime values after inheritance
- **AND** logs SHALL confirm successful state propagation before handle positioning

#### Scenario: Handle positioning verification logging
- **WHEN** trimmer handles appear on screen with videoDuration > 0
- **THEN** system SHALL log the mathematical calculation: timelineWidth × (time ÷ videoDuration)
- **AND** system SHALL log the resulting pixel offset using local coordinate space
- **AND** system SHALL verify the position matches expected timeline percentage

#### Scenario: Production monitoring
- **WHEN** coordinate calculations are performed
- **THEN** system SHALL log if videoDuration was properly loaded before calculations
- **AND** system SHALL log if coordinate space was available from GeometryReader
- **AND** system SHALL verify handles appear at expected positions without NaN values