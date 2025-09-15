# BreakingFlashcards App Architecture

## Overview
BreakingFlashcards is a video flashcard application for learning and reviewing complex physical movements, built on iOS 18.0 with SwiftUI, following KISS, DRY, and YAGNI principles.

## Core Architecture

### Application Entry Point
- **`BreakingFlashcardsApp.swift`** - Main app entry point, configures Core Data context, initializes managers (VideoRelinkManager, AlbumSyncManager), performs health checks on startup
- **`MainView.swift`** - Root view manager with tab navigation (Arsenal, Add, Create, Review)

### Dependency Injection & State Management
- **`AppContainer.swift`** - Singleton dependency injection container providing:
  - Memory management services
  - Video processing pipeline
  - Logging system
  - Health monitoring
- **`AddMoveState.swift`** - State machine enum for the Add Move flow with strict state transitions
- **`AddMoveContainer.swift`** - State router that manages view transitions based on AddMoveState
- **`AddMoveStateManager.swift`** - Centralized state management for complex Add Move flow transitions
- **`FeatureFlag.swift`** - Feature flag system for controlled feature rollout

## Feature Modules

### 1. Add Move Flow (Core Feature)

#### State Management
- **`AddMoveState.swift`** - Defines all possible states (ready, loading, previewing, trimming, naming, saving, success, error)
- **`AddMoveContainer.swift`** - Routes to appropriate views based on state transitions
- **`AddMoveView.swift`** - Entry point wrapper for the Add Move functionality

#### Video Selection & Processing
- **`AddMoveSelectClipView.swift`** - Initial video selection screen with PhotosPicker integration
- **`AddMoveReadyView.swift`** - Welcome screen with call-to-action
- **`VideoPickerWrapper.swift`** - Safe video picker with error handling

#### Video Trimming & Rotation
- **`TrimmerViewWrapper.swift`** - Safe wrapper for trimming functionality
- **`TrimmerViewModel.swift`** - Handles video trimming logic, time validation, frame-based seeking
- **FeatureRichTrimmerView.swift`** - Advanced trimming interface with timeline, handles, and rotation controls

#### Video Processing & Saving
- **`AddMoveSaveCoordinator.swift`** - Handles all move saving operations, coordinates between video processing and Core Data
- **`VideoTransformBuilder.swift`** - Utility for video transformations (trimming, rotation)
- **`VideoProcessingPipeline.swift`** - Orchestration of video processing steps
- **`MemoryManager.swift`** - Memory monitoring and cleanup for video operations
- **`VideoStateManager.swift`** - Centralized video state management across all operations
- **`VideoState.swift`** - Comprehensive state enum for video processing lifecycle
- **`ContinuationManager.swift`** - Handles async continuations and state restoration
- **`EnhancedVideoLogger.swift`** - Specialized logging for video operations with metadata

#### Core Data Persistence
- **`MovePersistenceService.swift`** - Service layer for Core Data operations
- **`Move+CoreDataClass.swift`** - Core Data entity for moves
- **`Combo+CoreDataClass.swift`** - Core Data entity for combos
- **`Review+CoreDataClass.swift`** - Core Data entity for reviews

#### Views in Add Move Flow
1. **`AddMoveSelectClipView.swift`** - Video selection from Photos library
2. **`AddMovePreviewingView.swift`** - Initial video preview before trimming
3. **`FeatureRichTrimmerView.swift`** - Video trimming and rotation interface (located in `/Views/Video/Trim/`)
4. **`NameMoveView.swift`** - Move naming and final save confirmation
5. **`AddMoveSavingView.swift`** - Progress indicator during save
6. **`MoveAddedSuccessView.swift`** - Success confirmation
7. **`AddMoveErrorView.swift`** - Error handling and retry options

#### Additional Add Move Views
8. **`AddMoveReadyView.swift`** - Welcome screen with call-to-action
9. **`AddMoveLoadingView.swift`** - Loading state indicator
10. **`AddMoveSelectingVideoView.swift`** - Video selection mode interface
11. **`LoadingOverlayView.swift`** - Loading overlay component

### 2. Arsenal Page
- **`BreakingArsenalView.swift`** - Main arsenal container
- **`MoveListView.swift`** - List of available moves
- **`AvailableMoveRowView.swift`** - Individual move display component
- **`ComboListView.swift`** - List of created combos
- **`ComboDetailView.swift`** - Detailed combo view with timeline
- **`ComboTimelineView.swift`** - Timeline visualization for combo sequences

### 3. Create Combo
- **`CreateComboView.swift`** - Interface for creating move combinations
- **`MovePickerSheet.swift`** - Move selection for combo creation
- **`ComboDetailTimelineView.swift`** - Timeline editing for combos

### 4. Review System
- **`ReviewView.swift`** - Spaced repetition review interface
- **`VideoGalleryView.swift`** - Gallery-style video display for review

### 5. Video Player System
- **`CustomVideoPlayerView.swift`** - Custom video player built on AVPlayerLayer
- **`AVPlayerViewRepresentable.swift`** - UIViewRepresentable wrapper for AVPlayer
- **`VideoPlayerManager.swift`** - Player lifecycle management
- **`MainVideoPlayerViewModel.swift`** - ViewModel for main video player
- **`PreviewVideoPlayerViewModel.swift`** - ViewModel for preview players
- **`UnifiedVideoPlayerViewModel.swift`** - Unified player logic for different contexts
- **`AddMovePlayerManager.swift`** - Specialized player manager for Add Move workflow
- **`VideoPlayerCacheManager.swift`** - Video asset caching and memory optimization
- **`VideoRelinkManager.swift`** - Handles video asset re-linking when files are moved/renamed
- **`VideoRelinkView.swift`** - UI for re-linking broken video assets

## Supporting Systems

### Memory Management
- **`MemoryMonitor.swift`** - System memory monitoring
- **`MemoryErrorHandler.swift`** - Handles memory pressure events
- **`VideoHealthMonitor.swift`** - Monitors video processing health

### Logging & Debugging
- **`AppLogger.swift`** - Centralized logging system with multiple loggers
- **`EnhancedVideoLogger.swift`** - Specialized video operation logging with metadata
- **`OSLog`** integration throughout for detailed debugging
- **PlayerStateMonitor.swift** - Monitors and logs player state changes

### Photo Library Integration
- **`PhotosPermissionManager.swift`** - Handles Photos permissions
- **`AlbumSyncManager.swift`** - Syncs Core Data with Photos library
- **`BreakDexAlbumManager.swift`** - Manages dedicated app album
- **`VideoRelinkManager.swift`** - Handles broken video links

### Manager Architecture
- **`Managers/`** - Centralized service layer with specialized managers:
  - **State Managers:** `AddMoveStateManager.swift`, `VideoStateManager.swift`
  - **Video Managers:** `VideoPlayerManager.swift`, `VideoPlayerCacheManager.swift`, `AddMovePlayerManager.swift`, `VideoRelinkManager.swift`
  - **Album Managers:** `BreakDexAlbumManager.swift`, `AlbumSyncManager.swift`, `PhotosPermissionManager.swift`
  - **Processing Managers:** `MemoryManager.swift`, `VideoHealthMonitor.swift`, `ContinuationManager.swift`
  - **Component Managers:** `UpdatedVideoCoordinator.swift`, `PlayerStateMonitor.swift`

### Design System
- **`DesignSystem.swift`** - App-wide design tokens and styles
- **`Color+Extensions.swift`** - Custom color extensions
- **`Font+Extensions.swift`** - Custom font extensions
- **`ButtonStyles.swift`** - Custom button styles
- **`EnhancedTabView.swift`** - Custom tab bar implementation

## Data Flow

### Add Move Flow
1. **Ready State** → User selects video via PhotosPicker
2. **Loading State** → Video asset loading and validation (with progressive progress updates)
3. **Previewing State** → Initial video preview with option to change
4. **Trimming State** → Set trim points and rotation using FeatureRichTrimmerView
5. **Naming State** → Enter move name and confirm
6. **Saving State** → Process video and save to Photos + Core Data
7. **Success State** → Confirmation and return to ready state

#### Enhanced State Management (iOS 18.0)
- **Progressive Loading**: Loading state includes progress tracking (0.1 → 0.2 → 0.3 → 0.5 → 0.7 → 0.8 → 0.9 → 1.0)
- **Debounced Transitions**: State changes are debounced to prevent rapid UI updates
- **Timeout Protection**: 30-second timeout for video loading operations
- **Enhanced Validation**: Asset validation using iOS 18.0 AVFoundation best practices
- **Permission Checks**: Pre-loading Photos permission validation

### Video Processing Pipeline
1. **Asset Loading** → `VideoAssetLoader` loads and validates video
2. **Memory Check** → `MemoryManager` ensures sufficient resources
3. **Transform Processing** → `VideoTransformBuilder` applies trims/rotations
4. **Export** → Creates final video file
5. **Photos Save** → `MovePersistenceService` saves to BreakDex album
6. **Core Data Persistence** → Creates move entity with metadata

### Error Handling
- Comprehensive error states at each step
- Retry mechanisms for transient failures
- Graceful degradation under memory pressure
- Detailed logging for debugging

## Key Architectural Principles

1. **Single Responsibility** - Each component has a clear, focused purpose
2. **State-Driven UI** - All view transitions are state-managed
3. **Dependency Injection** - Services are injected, not instantiated directly
4. **Memory Safety** - Proactive memory monitoring and cleanup
5. **Concurrency Safety** - MainActor isolation for UI, async/await for operations
6. **Error Resilience** - Comprehensive error handling and recovery paths

## File Organization

```
BreakingFlashcards/
├── AppCore/
│   ├── BreakingFlashcardsApp.swift
│   ├── MainView.swift
│   └── FeatureFlag.swift
├── Views/
│   ├── Arsenal/
│   │   ├── AddMove/          # Complete Add Move flow
│   │   ├── Moves/           # Move display and management
│   │   └── Combos/          # Combo creation and display
│   └── Video/
│       ├── Player/          # Video player components
│       ├── Trim/            # Video trimming interface
│       ├── Re-link/         # Video re-linking functionality
│       └── Review/          # Review system
├── Video/
│   └── Processing/          # Video processing pipeline
│       ├── Components/      # Video processing components
│       ├── VideoState.swift
│       ├── VideoStateManager.swift
│       └── VideoTransformBuilder.swift
├── Managers/                # Service layer managers
│   ├── AddMoveStateManager.swift
│   ├── VideoPlayerManager.swift
│   ├── VideoPlayerCacheManager.swift
│   ├── AddMovePlayerManager.swift
│   ├── VideoRelinkManager.swift
│   ├── BreakDexAlbumManager.swift
│   ├── AlbumSyncManager.swift
│   ├── PhotosPermissionManager.swift
│   └── MemoryManager.swift
├── CoreData/               # Data models and persistence
└── Utils/                   # Utility functions and extensions
```

Additional:

Complete Video Loading Flow

  Phase 1: Video Data Loading

  // Lines 382-419: Load video data with timeout
  1. Start two competing tasks:
    - Loading task: item.loadTransferable(type: Data.self)
    - Timeout task: 30-second countdown
  2. First task wins - either gets video data or timeout error
  3. Progress: Loading 0.3 → (waiting)

  Phase 2: Temporary File Creation

  // Lines 421-432: Create temp file from video data
  4. Create temp file URL with unique UUID
  5. Write video data to temporary location
  6. Progress: Loading 0.3 → 0.7 ("Analyzing video format...")

  Phase 3: Video Asset Validation

  // Lines 441-471: Validate the video asset
  7. Create AVURLAsset from temp file
  8. Check if playable: asset.isPlayable
  9. Load video tracks: Verify visual tracks exist
  10. Check duration: Must be > 0 seconds
  11. Validate file size: Must not be empty
  12. Progress: Loading 0.7 → (validation complete)

  Phase 4: Video Player Creation

  // Lines 478-489: Create video player view model
  13. Create MainVideoPlayerViewModel:
  - Passes the validated AVAsset
  - Sets rotation to 0 (no rotation initially)
  - Injects AppContainer for dependencies
  14. Progress: Loading 0.7 → 0.8 ("Preparing video player...")

  Phase 5: Player Initialization

  // Lines 491-515: Wait for player to be ready
  15. Wait for player readiness: playerViewModel.waitForReady()
  16. Another timeout race: Player ready vs 30-second timeout
  17. Progress: Loading 0.8 → 0.9 ("Initializing player...")

  Phase 6: Transition to Preview State

  // Lines 519-531: Final state transition
  18. Store player reference: currentVideoPlayerViewModel = playerViewModel
  19. Generate temporary ID: currentPhotosIdentifier = "temp-..."
  20. Transition to .previewing state with:
  - playerViewModel: Ready-to-use video player
  - asset: Validated AVAsset
  - photosIdentifier: Temporary ID
  - rotationQuarterTurns: 0
  21. Success! → User sees video preview

  What Happens Next:

  In AddMoveContainer.swift, the .previewing state maps to:
  case .previewing(let playerViewModel, let asset, let photosIdentifier, let rotationQuarterTurns):
      PreTrimView(
          viewModel: viewModel,
          playerViewModel: playerViewModel,
          asset: asset,
          photosIdentifier: photosIdentifier,
          rotationQuarterTurns: rotationQuarterTurns,
          selectedTab: $selectedTab
      )

  User can now:
  - Watch the video preview
  - Start trimming the video
  - Change video selection
  - Proceed to naming phase

  Error Handling:

  At any phase, if something fails:
  - Error state transition: state = .error(message, underlyingError)
  - User sees: Error view with retry options
  - No hanging: Timeout mechanism prevents infinite waiting

  This flow ensures robust video loading with proper validation, timeout protection, and clear user feedback at each step.