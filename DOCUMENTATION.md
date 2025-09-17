# BreakingFlashcards App Architecture

## Overview
BreakingFlashcards is a video flashcard application for learning and reviewing complex physical movements, built on iOS 18.0 with SwiftUI, following KISS, DRY, and YAGNI principles.

**Current State**: 79 Swift files with modern iOS 18.0 patterns, comprehensive state management, and robust video processing pipeline.

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
- **`AddMoveState.swift`** - Traditional enum-based state machine for Add Move flow (133 lines)
- **`AddMoveAppState.swift`** - Modern iOS 18.0 @Observable state management class (151 lines)
- **`AddMoveContainer.swift`** - State router that manages view transitions based on state
- **`AddMoveStateManager.swift`** - Centralized state management for complex Add Move flow transitions (248 lines)
- **`AddMoveFlowCoordinator.swift`** - Modern flow control coordinator (362 lines)
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
2. **`Pre-TrimView.swift`** - Initial video preview before trimming (located in `/Views/Video/Pre-Trim/`)
3. **`PreTrimContainerView.swift`** - Container for Pre-Trim with loading states (located in `/Views/Video/Pre-Trim/`)
4. **`FeatureRichTrimmerView.swift`** - Video trimming and rotation interface (located in `/Views/Video/Trim/`)
5. **`NameMoveView.swift`** - Move naming and final save confirmation
6. **`AddMoveErrorView.swift`** - Error handling and retry options
7. **`LoadingOverlayView.swift`** - Loading state component

#### Additional Views
8. **`AddMoveView.swift`** - Entry point wrapper for Add Move functionality
9. **`ImportExportView.swift`** - Import/export functionality
10. **`VideoPickerWrapper.swift`** - Safe video picker with error handling

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
- **`UnifiedVideoPlayerViewModel.swift`** - Unified player logic for different contexts
- **`VideoPlayerViewModelProtocol.swift`** - Protocol-based design for video players
- **`AddMovePlayerManager.swift`** - Specialized player manager for Add Move workflow
- **`VideoPlayerCacheManager.swift`** - Video asset caching and memory optimization
- **`VideoRelinkManager.swift`** - Handles video asset re-linking when files are moved/renamed (located in `/Views/Video/Re-link/`)
- **`VideoRelinkView.swift`** - UI for re-linking broken video assets (located in `/Views/Video/Re-link/`)

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
  - **State Managers:** `AddMoveStateManager.swift` (248 lines)
  - **Video Managers:** `VideoPlayerManager.swift`, `VideoPlayerCacheManager.swift`, `AddMovePlayerManager.swift`
  - **Album Managers:** `BreakDexAlbumManager.swift`, `AlbumSyncManager.swift`, `PhotosPermissionManager.swift`
  - **Processing Managers:** (Located in Video/Processing/ directory) `MemoryManager.swift`, `VideoHealthMonitor.swift`, `ContinuationManager.swift`
  - **Component Managers:** (Located in Video/Processing/Components/) `PlayerStateMonitor.swift`, `PlayerItemStatusMonitor.swift`, `ReadinessMonitor.swift`

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
- **Dual State Systems**: Both traditional enum-based (`AddMoveState`) and modern @Observable (`AddMoveAppState`) patterns
- **Progressive Loading**: Loading state includes progress tracking (0.1 → 0.2 → 0.3 → 0.5 → 0.7 → 0.8 → 0.9 → 1.0)
- **Debounced Transitions**: State changes are debounced to prevent rapid UI updates
- **Timeout Protection**: 30-second timeout for video loading operations
- **Enhanced Validation**: Asset validation using iOS 18.0 AVFoundation best practices
- **Permission Checks**: Pre-loading Photos permission validation
- **Pre-Trim Integration**: Video preview with change functionality and state lifecycle management

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

## Current State & Known Issues

### ✅ Strengths
- **Modern iOS 18.0 Patterns**: @Observable, async/await, PhotosPicker integration
- **Robust Video Processing**: Comprehensive pipeline with timeout protection
- **Comprehensive Logging**: OSLog integration with emoji prefixes for debugging
- **Protocol-Based Design**: Video player system with proper abstraction
- **Memory Management**: Proactive monitoring and cleanup
- **Error Handling**: Comprehensive error states and recovery paths

### ⚠️ Known Issues
1. **Dual State Management**: Both `AddMoveState` and `AddMoveAppState` exist simultaneously
2. **Pre-Trim State Lifecycle**: Multiple routes to Pre-Trim create inconsistent state contexts
3. **File Organization**: Some files are in different locations than documented
4. **Test Coverage**: Gaps in unit test coverage for new architecture components

### 🔧 Active Development Areas
- **Pre-Trim Controls**: Back button, change video, and "Use Original" functionality
- **State Transition Validation**: Ensuring proper cleanup between state changes
- **Video Player Resource Management**: Proper cleanup during video replacement

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
│   │   ├── AddMove/          # Add Move flow (11 files)
│   │   ├── Moves/           # Move display and management
│   │   └── Combos/          # Combo creation and display
│   └── Video/
│       ├── Player/          # Video player components (5 files)
│       ├── Pre-Trim/        # Video preview before trimming (2 files)
│       ├── Trim/            # Video trimming interface (2 files)
│       ├── Re-link/         # Video re-linking functionality (2 files)
│       └── Review/          # Review system (2 files)
├── Video/
│   └── Processing/          # Video processing pipeline
│       ├── Components/      # Video processing components (multiple monitors)
│       ├── VideoState.swift
│       ├── VideoStateManager.swift
│       ├── VideoTransformBuilder.swift
│       ├── MemoryManager.swift
│       ├── VideoHealthMonitor.swift
│       └── ContinuationManager.swift
├── Managers/                # Service layer managers (4 main managers)
│   ├── AddMoveStateManager.swift
│   ├── VideoPlayerManager.swift
│   ├── VideoPlayerCacheManager.swift
│   ├── AddMovePlayerManager.swift
│   ├── BreakDexAlbumManager.swift
│   ├── AlbumSyncManager.swift
│   └── PhotosPermissionManager.swift
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

  ### EXTRA
    Core Real-Time Files:

  Video Health Monitoring:
  - Video/Processing/VideoHealthMonitor.swift - 2-second interval health monitoring

  Memory Management:
  - Video/Processing/MemoryManager.swift - 5-second interval memory monitoring
  - Utils/MemoryMonitor.swift - Memory pressure utilities

  Player State Monitoring:
  - Video/Processing/Components/PlayerStateMonitor.swift - AVPlayer status monitoring
  - Video/Processing/Components/PlayerItemStatusMonitor.swift - AVPlayerItem status tracking
  - Video/Processing/Components/ReadinessMonitor.swift - Player readiness with timeouts

  Video Loading:
  - Video/Processing/VideoLoadingService.swift - 30 Hz progress updates for iCloud downloads
  - Views/Video/Player/UnifiedVideoPlayerViewModel.swift - Real-time player state management

  Data Synchronization:
  - Managers/Album/AlbumSyncManager.swift - 5-minute periodic sync timer

  Performance & Caching:
  - Managers/VideoPlayerCacheManager.swift - Real-time LRU cache management
  - Managers/SeekScheduler.swift - Seek latency monitoring

  Async Operations:
  - Video/Processing/Components/ContinuationManager.swift - Task continuation management

  State Management:
  - Managers/AddMoveStateManager.swift - Real-time state transitions
  - Managers/VideoStateManager.swift - Video state synchronization

  Video Processing:
  - Video/Processing/Components/UpdatedVideoCoordinator.swift - Processing coordination
  - Video/Processing/Components/UpdatedVideoAssetLoader.swift - Asset loading management