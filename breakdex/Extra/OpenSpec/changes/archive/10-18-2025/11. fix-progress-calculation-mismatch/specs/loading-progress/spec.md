## MODIFIED Requirements

### Requirement: Accurate Progress Display Calculation
The video loading system SHALL display progress percentages that align with user expectations and developer intent, eliminating confusing percentage discrepancies during loading stages.

#### Scenario: Preparing playback stage progress display
- **WHEN** the AddMoveViewModel sets loading state to preparing playback stage
- **THEN** the system SHALL display exactly 95% progress to users
- **AND** SHALL use stage-relative progress value of 0.0 for preparing playback stage
- **AND** SHALL calculate final progress as 0.95 + (0.0 × 0.04) = 0.95 (95%)
- **AND** SHALL log the progress transition for debugging purposes

#### Scenario: Finalizing stage progress display
- **WHEN** the AddMoveViewModel sets loading state to finalizing stage
- **THEN** the system SHALL display exactly 99% progress to users
- **AND** SHALL use stage-relative progress value of 0.0 for finalizing stage
- **AND** SHALL calculate final progress as 0.99 + (0.0 × 0.01) = 0.99 (99%)
- **AND** SHALL log the progress transition for debugging purposes

#### Scenario: Complete loading progression display
- **WHEN** video loading progresses through all stages
- **THEN** users SHALL see expected percentages: 0% → 10% → 60% → 80% → 90% → 95% → 99% → 100%
- **AND** SHALL NOT see confusing percentages like 98.8% during preparing playback
- **AND** SHALL maintain smooth progression without unexpected jumps
- **AND** SHALL complete successfully at 100% with transition to MinimalTrimmerView

### Requirement: Progress Calculation Diagnostic Logging
The loading system SHALL provide diagnostic logging for progress calculations to help developers debug display issues and verify correct behavior.

#### Scenario: Progress transition logging
- **WHEN** AddMoveViewModel updates loading state progress
- **THEN** the system SHALL log before and after progress percentages
- **AND** SHALL include the loading stage in log messages
- **AND** SHALL use format: "📊 Progress transition: X% → Y% (stage)"
- **AND** SHALL be visible in debug builds for development

#### Scenario: Progress display validation logging
- **WHEN** calculating progress display values
- **THEN** the system SHALL log raw progress vs displayed percentage
- **AND** SHALL validate calculation results match expected values
- **AND** SHALL use format: "🔍 Progress display validation: stage = X%"
- **AND** SHALL help identify calculation discrepancies immediately

#### Scenario: ProgressPercentage computed property logging
- **WHEN** SelectClip view accesses progressPercentage property
- **THEN** the system SHALL log the raw loadingState.progress value
- **AND** SHALL log the final displayed integer percentage
- **AND** SHALL use format: "🔍 Progress display: raw=X.XXX, display=X%"
- **AND** SHALL provide visibility into display calculation process

### Requirement: MVVM State Management Consistency
The progress display system SHALL follow MVVM pattern with clear separation between state calculation (Model/ViewModel) and display (View), maintaining single responsibility and testable code structure.

#### Scenario: ViewModel progress calculation responsibility
- **WHEN** managing loading state progress
- **THEN** AddMoveViewModel SHALL handle stage-relative progress values
- **AND** SHALL delegate final progress calculation to LoadingState
- **AND** SHALL provide computed properties for display formatting
- **AND** SHALL maintain observable state for SwiftUI updates

#### Scenario: View progress display responsibility
- **WHEN** displaying loading progress to users
- **THEN** SelectClip view SHALL use AddMoveViewModel.progressPercentage
- **AND** SHALL format values as integers for user display
- **AND** SHALL trigger UI updates through SwiftUI observation
- **AND** SHALL NOT perform calculation logic directly

#### Scenario: State transition validation
- **WHEN** updating loading state between stages
- **THEN** the system SHALL validate monotonic progress increases
- **AND** SHALL prevent progress regression or confusing jumps
- **AND** SHALL maintain consistent state throughout loading workflow
- **AND** SHALL handle edge cases and error states appropriately