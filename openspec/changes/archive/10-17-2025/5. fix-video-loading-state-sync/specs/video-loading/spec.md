## MODIFIED Requirements
### Requirement: Video Loading State Synchronization
The video loading system SHALL maintain functorial composition between system states and UI states, ensuring continuous progress mapping without state synchronization breaks, following Apple's latest async/await best practices while preserving MVVM/SRP architectural boundaries.

#### Scenario: Architectural boundary preservation
- **WHEN** implementing state synchronization fixes
- **THEN** RobustVideoLoader (Service layer) SHALL handle only video loading operations and progress reporting
- **AND** AddMoveViewModel (ViewModel layer) SHALL handle only UI state mapping and presentation logic
- **AND** SHALL maintain single responsibility principle for each component
- **AND** SHALL NOT cross architectural boundaries or mix concerns

#### Scenario: iCloud download completion transitions smoothly
- **WHEN** iCloud download completes (progress reaches 100%)
- **THEN** the system SHALL transition through intermediate states: .transferringFile → .validatingFile → .creatingAsset → .fullyReady
- **AND** progress SHALL flow continuously: 60% → 70% → 80% → 100%
- **AND** SHALL use async/await patterns recommended by Apple for responsive media apps

#### Scenario: PHVideoRequestOptions with proper async/await integration
- **WHEN** using PHVideoRequestOptions progressHandler for iCloud downloads
- **THEN** the progressHandler SHALL be properly configured with MainActor isolation
- **AND** SHALL use withCheckedThrowingContinuation to bridge completion handlers to async/await
- **AND** SHALL maintain continuous progress reporting without gaps

#### Scenario: AddMoveViewModel receives all progress updates
- **WHEN** RobustVideoLoader publishes progress updates
- **THEN** AddMoveViewModel SHALL process ALL updates regardless of current loading state
- **AND** SHALL NOT filter progress updates based on loadingState.isLoading predicate
- **AND** SHALL use Apple's recommended async/await patterns for UI responsiveness

#### Scenario: UI progress bar shows continuous progression
- **WHEN** video loading is in progress
- **THEN** the UI progress bar SHALL update smoothly without hanging at intermediate values
- **AND** SHALL complete at 100% when video is fully ready for playback
- **AND** SHALL follow Apple's HIG loading recommendations for user experience

#### Scenario: Swift concurrency with structured cancellation
- **WHEN** video loading operations are cancelled
- **THEN** the system SHALL properly handle task cancellation using structured concurrency
- **AND** SHALL cleanup resources and reset state according to Apple's async/await best practices
- **AND** SHALL prevent memory leaks following Apple's concurrency guidelines

#### Scenario: State chain maintains categorical composition
- **WHEN** multiple state transitions occur in sequence
- **THEN** the composition F(g ∘ f) SHALL equal F(g) ∘ F(f) for the UI mapping functor
- **AND** no morphisms SHALL be lost in the state → UI transformation chain
- **AND** SHALL maintain proper async context propagation throughout the chain

## ADDED Requirements
### Requirement: Intermediate Loading Stage Transitions
The system SHALL provide explicit intermediate loading stages for video processing operations, following Apple's responsive media app recommendations.

#### Scenario: Post-download file transfer
- **WHEN** iCloud download completes successfully
- **THEN** the system SHALL enter .transferringFile stage with 70% progress
- **AND** SHALL display "Transferring file..." message to user
- **AND** SHALL use async/await to maintain UI responsiveness

#### Scenario: Asset validation phase
- **WHEN** file transfer completes
- **THEN** the system SHALL enter .validatingFile stage with 80% progress
- **AND** SHALL display "Validating video file..." message to user
- **AND** SHALL validate asset using AVAsset's async load methods

#### Scenario: Final asset creation
- **WHEN** validation completes successfully
- **THEN** the system SHALL enter .creatingAsset stage with 90% progress
- **AND** SHALL display "Creating video asset..." message to user
- **AND** SHALL create AVURLAsset with wide tolerances per Apple's recommendations

### Requirement: Swift Concurrency Integration
The video loading system SHALL implement proper Swift concurrency patterns following Apple's latest guidelines.

#### Scenario: Async/await with PHVideoRequestOptions
- **WHEN** requesting video assets from iCloud
- **THEN** the system SHALL use withCheckedThrowingContinuation to bridge completion handlers
- **AND** SHALL maintain proper MainActor isolation for UI updates
- **AND** SHALL handle progress updates on the main thread

#### Scenario: Structured concurrency for cancellation
- **WHEN** users cancel video loading operations
- **THEN** the system SHALL use structured concurrency for automatic cancellation propagation
- **AND** SHALL cleanup temporary files and network connections
- **AND** SHALL reset loading state to idle per Apple's cancellation patterns

#### Scenario: Responsive UI during background loading
- **WHEN** video loading occurs in background
- **THEN** the UI SHALL remain responsive using async/await patterns
- **AND** SHALL provide continuous progress feedback
- **AND** SHALL follow Apple's Human Interface Guidelines for loading states