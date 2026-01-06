# Video Loading Synchronization Specification

## ADDED Requirements

### Requirement: Enhanced Loading State Management
The system SHALL provide granular loading state tracking that accurately reflects both asset and player readiness.

#### Scenario: Asset Loading Completion
When the AVAsset loading completes, the system SHALL:
1. Set loading state to `assetReady` with 60% progress
2. Trigger transition to trimming view
3. Begin player initialization in background
4. Show loading overlay indicating player preparation

#### Scenario: Player Loading Progress
During player initialization, the system SHALL:
1. Update progress from 60% to 80% during player setup
2. Update progress from 80% to 95% during playback preparation
3. Set loading state to `playerReady` when AVPlayer is ready
4. Continue showing loading overlay until finalization

#### Scenario: Complete Loading Readiness
When both asset and player are ready, the system SHALL:
1. Set loading state to `fullyReady` with 100% progress
2. Hide loading overlay immediately
3. Enable user interaction with trimming controls
4. Begin video playback at trim start position

### Requirement: Coordinated Progress Reporting
The system SHALL calculate and display accurate progress that reflects the actual loading state.

#### Scenario: Multi-Stage Progress Calculation
During loading, progress SHALL be calculated as:
- 0-10%: Initializing video loading system
- 10-40%: Downloading and processing video asset
- 40-60%: Asset validation and preparation
- 60-80%: Initializing AVPlayer and player item
- 80-95%: Preparing for playback (buffering, seeking)
- 95-100%: Finalizing and enabling user interaction

#### Scenario: Progress Synchronization
When loading progresses between stages, the system SHALL:
1. Update progress smoothly without jumps
2. Provide descriptive status messages for each stage
3. Handle rapid state changes gracefully
4. Maintain progress accuracy during network or processing delays

### Requirement: Enhanced SharedVideoPlayer Integration
The SharedVideoPlayer SHALL provide ready-state callbacks for coordinated loading management.

#### Scenario: Player Ready Notification
When the AVPlayer becomes ready, the system SHALL:
1. Invoke the ready callback immediately
2. Update player readiness state in ViewModel
3. Log successful player initialization
4. Handle any errors during player setup

#### Scenario: Player Loading Timeout
If player initialization fails or times out, the system SHALL:
1. Invoke error callback with descriptive message
2. Update loading state to failed with clear error
3. Provide user guidance for recovery
4. Log timeout details for debugging

### Requirement: Synchronized UI State Management
The UI SHALL accurately reflect the synchronized loading state and enable interaction only when appropriate.

#### Scenario: Loading Overlay Behavior
The loading overlay SHALL:
1. Show during all loading stages until `fullyReady`
2. Display accurate progress and status messages
3. Handle state changes smoothly without flickering
4. Provide clear indication when loading is complete

#### Scenario: Navigation Timing
The system SHALL only transition from loading to interaction when:
1. Loading state is `fullyReady`
2. Video player is confirmed ready for playback
3. All error checks have passed
4. User interface elements are properly initialized

## MODIFIED Requirements

### Requirement: LoadingState Enum Enhancement with iCloud Support
The LoadingState enum SHALL be enhanced to support sophisticated iCloud loading stages while maintaining clean MVVM architecture.

#### Scenario: Enhanced LoadingState with iCloud Stages
The system SHALL update LoadingState.swift to include:
1. `LoadingStage` enum with iCloud-specific stages (.requestingDownload, .downloadingFromCloud)
2. Intermediate states (.assetReady, .playerReady, .fullyReady) to fix sync issues
3. Detailed progress calculation that reflects both asset and player loading
4. Maintained backward compatibility with existing ViewModel usage

#### Scenario: Progress Calculation with iCloud Awareness
The enhanced progress system SHALL:
1. Calculate progress based on LoadingStage (0-10% initializing, 10-60% downloading, etc.)
2. Provide smooth transitions between iCloud download stages
3. Account for both AVAsset loading and AVPlayer initialization
4. Maintain existing `progress` computed property behavior

### Requirement: SimpleLoadingView with Official ProgressView
The SimpleLoadingView SHALL be updated to use Apple's official ProgressView APIs while maintaining rich loading feedback.

#### Scenario: Apple ProgressView Integration
The updated SimpleLoadingView SHALL:
1. Use `ProgressView(value:progress, total:1.0)` with official iOS 17+ APIs
2. Apply `LinearProgressViewStyle` and `CircularProgressViewStyle` appropriately
3. Use `.controlSize(.large/.regular)` instead of manual frame sizing
4. Apply `.tint()` for proper color theming
5. Include built-in accessibility support from Apple's ProgressView

#### Scenario: iCloud Loading Feedback
The SimpleLoadingView SHALL provide rich iCloud-specific feedback:
1. Special handling for `.downloadingFromCloud` stage with network info
2. Download speed and percentage display for iCloud operations
3. Retry buttons for recoverable iCloud errors
4. Appropriate icons and animations for each loading stage

### Requirement: Unified Loading Architecture
The system SHALL eliminate duplicate loading state enums and consolidate into a single, unified loading system.

#### Scenario: LoadingState Consolidation
The system SHALL:
1. DELETE VideoLoadingState.swift and consolidate functionality into LoadingState.swift
2. Update all services to use the enhanced LoadingState enum
3. Remove mapping layers and conversion complexity
4. Maintain single source of truth for loading state

#### Scenario: ViewModel Integration
AddMoveViewModel SHALL:
1. Use enhanced LoadingState with iCloud stages
2. Set `assetReady` when AVAsset is loaded (60% progress)
3. Set `playerReady` when SharedVideoPlayer is ready (80% progress)
4. Set `fullyReady` when both asset and player are ready (100% progress)

### Requirement: MinimalTrimmerView Loading Integration with SimpleLoadingView
The MinimalTrimmerView SHALL use SimpleLoadingView instead of basic synchronizedLoadingOverlay.

#### Scenario: Replace Basic Loading Overlay
The MinimalTrimmerView SHALL:
1. DELETE the basic `synchronizedLoadingOverlay` implementation
2. Replace with `SimpleLoadingView(state: viewModel.loadingState, retryAction: retryAction)`
3. Monitor ViewModel loading state instead of direct player state
4. Initialize SharedVideoPlayer when asset is ready

#### Scenario: Rich Loading Feedback
The updated loading experience SHALL provide:
1. Official Apple ProgressView with linear and circular styles
2. iCloud download progress and network information
3. Proper animations and icons for each loading stage
4. Retry functionality for recoverable errors
5. Built-in accessibility support

### Requirement: AddMoveViewModel State Management
The AddMoveViewModel SHALL coordinate between asset loading and player readiness using enhanced states.

#### Scenario: State Transition Logic
When handling video loading, the ViewModel SHALL:
1. Set `loading(progress: 0.6, stage: .creatingAsset, message: "Creating video asset...")` when asset is loaded
2. Set `assetReady(asset)` at 60% progress
3. Set `playerReady(asset)` at 80% progress when SharedVideoPlayer is ready
4. Set `fullyReady(asset)` at 100% progress when both are ready

#### Scenario: Error Handling Enhancement
When loading errors occur, the ViewModel SHALL:
1. Distinguish between asset loading and player initialization errors
2. Set `failed(message, canRetry: true)` for recoverable iCloud errors
3. Set `failed(message, canRetry: false)` for unrecoverable errors
4. Provide specific error messages for iCloud download vs player initialization failures

## REMOVED Requirements

### Requirement: Direct Player State Dependency
The system SHALL remove the dependency on direct SharedVideoPlayer state checking in UI components.

#### Scenario: Eliminated Race Conditions
The system SHALL NO LONGER:
1. Check `videoPlayer.isReady` directly for UI state decisions
2. Have timing gaps between asset and player readiness
3. Show confusing loading states (like stuck at 100%)
4. Experience race conditions between separate loading processes

#### Scenario: Simplified State Management
By removing direct player state dependencies:
1. State management becomes centralized in ViewModels
2. UI components have single source of truth for loading state
3. Race conditions are eliminated through coordinated state transitions
4. Debugging becomes easier with centralized logging

### Requirement: Duplicate Loading State Enums
The system SHALL eliminate the duplicate VideoLoadingState enum and consolidate all loading functionality.

#### Scenario: VideoLoadingState Removal
The system SHALL:
1. DELETE VideoLoadingState.swift file entirely
2. Move all iCloud loading stages to LoadingState.swift LoadingStage enum
3. Remove all mapping layers and conversion complexity
4. Update SimpleLoadingView to use unified LoadingState enum

#### Scenario: Service Layer Consolidation
All video loading services SHALL:
1. Use unified LoadingState enum instead of VideoLoadingState
2. Maintain iCloud download sophistication within new structure
3. Preserve retry logic and error handling capabilities
4. Eliminate unnecessary state conversion overhead