# Loading Progress - State Observation

## ADDED Requirements

### Requirement: Intermediate Progress State Visibility
The loading progress system SHALL ensure that all intermediate progress states (95%, 99%, 100%) are visible to users during video loading.

#### Scenario: Complete Progress Sequence Display
**GIVEN** a video is being loaded in the AddMove workflow
**WHEN** the loading progresses through the final stages
**THEN** users SHALL see 95% progress during preparingPlayback stage
**AND** SHALL see 99% progress during finalizing stage
**AND** SHALL see 100% progress when fullyReady
**AND** SHALL NOT see jumps from 95% directly to 100%

#### Scenario: Progress State Consistency
**GIVEN** the LoadingState calculation system with stage-based progress
**WHEN** progressing through loading stages
**THEN** each stage SHALL be properly observed by the UI
**AND** progress percentages SHALL align with user expectations
**AND** intermediate states SHALL NOT be skipped due to timing issues

### Requirement: Frame-Aware Progress Updates
Progress updates SHALL be frame-aware to prevent SwiftUI coalescing of intermediate loading states.

#### Scenario: Frame Boundary Progress Updates
**GIVEN** multiple progress updates need to occur in sequence
**WHEN** updating progress from one stage to another
**THEN** each update SHALL cross at least one UI frame boundary
**AND** SHALL be processed by SwiftUI before the next update
**AND** SHALL maintain proper timing separation between updates

#### Scenario: Progress Update Timing Validation
**GIVEN** progress updates are being set
**WHEN** measuring update timing
**THEN** updates SHALL be separated by at least one UI frame (~16.67ms)
**AND** timing SHALL be logged for diagnostic purposes
**AND** same-frame updates SHALL trigger warnings for debugging

### Requirement: Progress State Diagnostics
The loading progress system SHALL provide comprehensive diagnostics to verify that all progress states are properly observed.

#### Scenario: Progress Propagation Tracking
**GIVEN** loading progress states are being set
**WHEN** each state is set
**THEN** the system SHALL log the state being set with timestamp
**AND** SHALL log when the state is observed by the UI
**AND** SHALL calculate the propagation delay
**AND** SHALL validate that the delay indicates proper frame separation

#### Scenario: Missing State Detection
**GIVEN** expected progress states in a sequence
**WHEN** a state is not observed within expected timeframe
**THEN** the system SHALL log a warning about the missing state
**AND** SHALL provide diagnostic information about timing
**AND** SHALL suggest potential frame coalescing issues

## MODIFIED Requirements

### Requirement: Progress Transition Smoothness
The loading progress system SHALL ensure smooth transitions between all progress states without perceptible jumps.

#### Scenario: Smooth Final Stage Progression
**GIVEN** the final stages of video loading (preparingPlayback → finalizing → fullyReady)
**WHEN** these stages execute
**THEN** users SHALL see smooth progression through 95% → 99% → 100%
**AND** SHALL NOT experience jumps that suggest stuck loading
**AND** SHALL transition to trimming only after reaching 100%

#### Scenario: Enhanced Frame Separation Implementation
**GIVEN** existing frame separation using `await Task.yield()`
**WHEN** intermediate states are still being skipped
**THEN** the implementation SHALL be enhanced with MainActor synchronization
**AND** SHALL provide guaranteed frame boundary crossing
**AND** SHALL validate state observation at each step