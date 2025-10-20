## ADDED Requirements
### Requirement: Simple Loading State Interface
The system SHALL provide a simple state management interface for video loading that hides internal complexity while maintaining robust functionality.

#### Scenario: Loading state simplicity
- **WHEN** a user selects a video from Photos picker
- **THEN** the UI shows only: idle → loading → ready/failed with progress
- **AND** all internal coordination is hidden from the view layer

#### Scenario: Robust loading preservation
- **WHEN** loading any video (local, iCloud, large file)
- **THEN** the robust loader handles all complexity internally
- **AND** provides the same reliability as current implementation

### Requirement: Robust Video Loader Service
The system SHALL maintain a robust video loading service that handles all complex scenarios while presenting a simple interface using iOS 18 best practices.

#### Scenario: iCloud video handling
- **WHEN** user selects an iCloud-only video
- **THEN** RobustVideoLoader handles PHAsset.requestAVAsset with proper async/await concurrency
- **AND** presents simple loading state to the UI
- **AND** manages download progress, network conditions, and temporary storage

#### Scenario: Large file handling
- **WHEN** user selects a video larger than 50MB
- **THEN** RobustVideoLoader uses Swift 6 async/await with structured concurrency
- **AND** manages memory pressure and streaming
- **AND** provides progress updates through simple interface

#### Scenario: Network resilience
- **WHEN** network conditions change during loading
- **THEN** RobustVideoLoader handles retries with exponential backoff using Swift Concurrency
- **AND** maintains simple state interface for the UI

### Requirement: Temporary File Management
The system SHALL properly manage temporary files created during video loading and ensure proper cleanup following Apple's recommended practices.

#### Scenario: Temporary file creation and cleanup
- **WHEN** RobustVideoLoader creates temporary files for iCloud videos
- **THEN** files are created in the system temp directory using NSTemporaryDirectory()
- **AND** files are automatically cleaned up when loading completes or fails
- **AND** cleanup uses proper error handling with do-catch blocks

#### Scenario: Memory pressure handling
- **WHEN** memory pressure occurs during large file loading
- **THEN** RobustVideoLoader responds to system memory warnings
- **AND** cleans up temporary resources appropriately
- **AND** maintains loading progress when possible

### Requirement: Proper Encapsulation and Cleanup
The system SHALL encapsulate complex loading logic and properly delete unnecessary files and components following SRP principles.

#### Scenario: Legacy component cleanup
- **WHEN** the new architecture is implemented
- **THEN** AtomicStateCoordinator, StateValidationMiddleware, and UnifiedState files are completely removed
- **AND** all imports and references to these components are deleted
- **AND** build phases are updated to exclude deleted files

#### Scenario: Service encapsulation
- **WHEN** RobustVideoLoader handles complex scenarios
- **THEN** all iCloud handling, network management, and file operations are internal to the service
- **AND** external interface exposes only simple states and progress
- **AND** internal complexity is not visible to view models

## MODIFIED Requirements
### Requirement: Video Loading State Management
The video loading system SHALL use simple SwiftUI state management instead of atomic state coordination while maintaining all robust loading capabilities.

#### Scenario: State transition simplification
- **WHEN** video loading begins
- **THEN** state transitions from idle to loading without atomic coordination
- **AND** provides the same user experience and reliability

#### Scenario: Error state handling
- **WHEN** loading fails for any reason
- **THEN** simple error state is presented to the UI
- **AND** internal retry mechanisms continue to work robustly

### Requirement: AddMoveViewModel State Architecture
The system SHALL replace AddMoveUnifiedState with a simplified AddMoveViewModel using standard SwiftUI patterns while maintaining all functionality.

#### Scenario: Simple state management structure
- **WHEN** the new architecture is implemented
- **THEN** AddMoveViewModel uses @Published properties for basic state only
- **AND** complex state coordination is removed in favor of simple enum states
- **AND** @StateObject is used for view model lifecycle management

#### Scenario: State enum simplification
- **WHEN** representing loading states
- **THEN** LoadingState enum provides: idle, loading(progress), ready(asset), failed(message)
- **AND** no complex flow states or atomic transitions are used
- **AND** UI responds to simple state changes via @Published

#### Scenario: ViewModel-Service separation
- **WHEN** AddMoveViewModel handles video loading
- **THEN** RobustVideoLoader encapsulates all complex loading logic internally
- **THEN** ViewModel only manages basic state and user interactions
- **AND** service complexity is not exposed to the view layer

## REMOVED Requirements
### Requirement: Atomic State Coordination
**Reason**: Over-engineered for video loading use case, adds unnecessary complexity
**Migration**: Replace with simple SwiftUI @State and @StateObject patterns

### Requirement: State Validation Middleware
**Reason**: Complex validation is not needed for simple loading states
**Migration**: Basic validation within view models, remove comprehensive middleware

### Requirement: Unified State Management
**Reason**: Complex state management is not justified for this single feature
**Migration**: Use standard SwiftUI state management patterns