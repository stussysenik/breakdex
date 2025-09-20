# BreakingFlashcards App Architecture

## Overview
BreakingFlashcards is a video flashcard application for learning and reviewing complex physical movements, built on iOS 18.0 with SwiftUI, following KISS, DRY, YAGNI and WYSIWYG principles.

**Current State**: 96 Swift files with modern iOS 18.0 patterns, comprehensive state management, and robust video processing pipeline.

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
- **`AddMoveState.swift`** - Traditional enum-based state machine for Add Move flow
- **`AddMoveAppState.swift`** - Modern iOS 18.0 @Observable state management class
- **`AddMoveContainer.swift`** - State router that manages view transitions (includes inline VideoPickerWrapper and TrimmerViewWrapper)
- **`AddMoveStateManager.swift`** - Centralized state management for complex Add Move flow transitions (248 lines)
- **`AddMoveFlowCoordinator.swift`** - Modern flow control coordinator (362 lines)
- **`AddMoveViewModel.swift`** - View model logic for Add Move flow
- **`AddMoveVideoLoader.swift`** - Video loading orchestration
- **`AddMoveVideoOrchestrator.swift`** - Video processing coordination
- **`AddMovePlayerManager.swift`** - Specialized player management for Add Move workflow
- **`AddMoveSaveCoordinator.swift`** - Handles all move saving operations, coordinates between video processing and Core Data

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
1. **`AddMoveView.swift`** - Entry point wrapper for Add Move functionality
2. **`AddMoveSelectClipView.swift`** - Video selection from Photos library
3. **`AddMoveContainer.swift`** - State routing container with inline wrappers
4. **`Pre-TrimView.swift`** - Initial video preview before trimming (located in `/Views/Video/Pre-Trim/`)
5. **`PreTrimContainerView.swift`** - Container for Pre-Trim with loading states (located in `/Views/Video/Pre-Trim/`)
6. **`FeatureRichTrimmerView.swift`** - Video trimming and rotation interface (located in `/Views/Video/Trim/`)
7. **`TrimmerViewModel.swift`** - Handles video trimming logic, time validation, frame-based seeking
8. **`NameMoveView.swift`** - Move naming and final save confirmation
9. **`AddMoveErrorView.swift`** - Error handling and retry options
10. **`LoadingOverlayView.swift`** - Loading state component
11. **`ImportExportView.swift`** - Import/export functionality
12. **`AddMoveVideoLoader.swift`** - Video loading orchestration
13. **`AddMoveVideoOrchestrator.swift`** - Video processing coordination
14. **`AddMovePlayerManager.swift`** - Specialized player management
15. **`AddMoveSaveCoordinator.swift`** - Save operation coordination

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
- **`UnifiedVideoPlayerViewModel.swift`** - Unified player logic for different contexts
- **`VideoPlayerManager.swift`** - Player lifecycle management
- **`VideoPlayerViewModelProtocol.swift`** - Protocol-based design for video players
- **`AddMovePlayerManager.swift`** - Specialized player manager for Add Move workflow
- **`VideoPlayerCacheManager.swift`** - Video asset caching and memory optimization
- **`UnifiedPlayerManager.swift`** - Unified player management system
- **`VideoRelinkManager.swift`** - Handles video asset re-linking when files are moved/renamed (located in `/Views/Video/Re-link/`)
- **`VideoRelinkView.swift`** - UI for re-linking broken video assets (located in `/Views/Video/Re-link/`)
- **`SeekScheduler.swift`** - Video seek operations and latency monitoring

## Supporting Systems

### Memory Management
- **`MemoryManager.swift`** - Memory monitoring and cleanup for video operations
- **`MemoryErrorHandler.swift`** - Handles memory pressure events
- **`VideoHealthMonitor.swift`** - Monitors video processing health
- **`VideoHealthStatus.swift`** - Health status tracking for video operations

### Logging & Debugging
- **`AppLogger.swift`** - Centralized logging system with multiple loggers
- **`EnhancedVideoLogger.swift`** - Specialized video operation logging with metadata
- **`OSLog`** integration throughout for detailed debugging
- **PlayerStateMonitor.swift** - Monitors and logs player state changes

### Photo Library Integration
- **`PhotosPermissionManager.swift`** - Handles Photos permissions
- **`AlbumSyncManager.swift`** - Syncs Core Data with Photos library
- **`BreakDexAlbumManager.swift`** - Manages dedicated app album
- **`PhotosImportService.swift`** - Photo import functionality
- **`PhotosClient.swift`** - Photos API client abstraction
- **`VideoRelinkManager.swift`** - Handles broken video links

### Manager Architecture
- **`Managers/`** - Centralized service layer with 11 specialized managers:
  - **State Managers:** `AddMoveStateManager.swift` (248 lines)
  - **Video Managers:** `VideoPlayerManager.swift`, `VideoPlayerCacheManager.swift`, `AddMovePlayerManager.swift`, `UnifiedPlayerManager.swift`
  - **Album Managers:** `BreakDexAlbumManager.swift`, `AlbumSyncManager.swift`, `PhotosPermissionManager.swift`, `PhotosImportService.swift`
  - **Processing Managers:** `MemoryManager.swift`, `VideoHealthMonitor.swift`, `ContinuationManager.swift`
  - **Utility Managers:** `MovePersistenceService.swift`, `PhotosClient.swift`, `VideoAssetPreparer.swift`, `SeekScheduler.swift`

### Design System
- **`DesignSystem.swift`** - App-wide design tokens and styles
- **`Color+Extensions.swift`** - Custom color extensions
- **`Font+Extensions.swift`** - Custom font extensions
- **`ButtonStyles.swift`** - Custom button styles
- **`EnhancedTabView.swift`** - Custom tab bar implementation
- **`AnimationTester.swift`** - Animation utilities
- **`MotionCatalog.swift`** - Motion effects catalog
- **`StatePillView.swift`** - State display component
- **`TimelineNodeView.swift`** - Timeline visualization component

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
- **Robust Video Processing**: Comprehensive pipeline with timeout protection and memory management
- **Comprehensive Logging**: OSLog integration with emoji prefixes for debugging
- **Protocol-Based Design**: Video player system with proper abstraction
- **Memory Management**: Proactive monitoring and cleanup with 5-second intervals
- **Error Handling**: Comprehensive error states and recovery paths
- **Modular Architecture**: Well-organized feature-based structure with clear separation of concerns
- **Dependency Injection**: Singleton AppContainer for centralized service management

### ⚠️ Known Issues
1. **Dual State Management**: Both `AddMoveState` (traditional enum) and `AddMoveAppState` (@Observable class) exist simultaneously
2. **Pre-Trim State Lifecycle**: Multiple routes to Pre-Trim create inconsistent state contexts
3. **File Organization**: Several empty directories suggest incomplete refactoring
4. **Missing Components**: Some referenced files don't exist (`AddMoveReadyView.swift`, `MemoryMonitor.swift`, `PlayerStateMonitor.swift`, `ReadinessMonitor.swift`)
5. **Inline vs Separate Files**: `VideoPickerWrapper` and `TrimmerViewWrapper` are inline within `AddMoveContainer.swift`

### 🔧 Active Development Areas
- **Pre-Trim Controls**: Back button, change video, and "Use Original" functionality
- **State Transition Validation**: Ensuring proper cleanup between state changes
- **Video Player Resource Management**: Proper cleanup during video replacement
- **Import/Export**: Complete implementation for TestFlight release
- **Enhanced Spaced Repetition**: Improved algorithm and statistics tracking

### 📊 Codebase Statistics
- **Total Swift Files**: 96 files
- **Views**: 39 files (40.6%)
- **Managers**: 11 files (11.5%)
- **Video Processing**: 19 files (19.8%)
- **CoreData**: 9 files (9.4%)
- **Utils**: 13 files (13.5%)
- **Other**: 5 files (5.2%)

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
├── AppCore/                 # Application entry and main views (4 files)
│   ├── BreakingFlashcardsApp.swift
│   ├── MainView.swift
│   ├── BreakingArsenalView.swift
│   └── FeatureFlag.swift
├── Views/                   # UI components organized by feature (39 files)
│   ├── Arsenal/AddMove/     # Add Move flow (15 files)
│   ├── Arsenal/Combos/      # Combo creation and display (7 files)
│   ├── Arsenal/Moves/       # Move display and management (4 files)
│   ├── Video/Player/        # Video player components (5 files)
│   ├── Video/Pre-Trim/      # Video preview before trimming (2 files)
│   ├── Video/Trim/          # Video trimming interface (2 files)
│   ├── Video/Re-link/       # Video re-linking functionality (2 files)
│   └── Video/Review/        # Review system (2 files)
├── Video/                   # Video processing pipeline (19 files)
│   ├── VideoState.swift
│   ├── VideoStateManager.swift
│   ├── VideoProcessor.swift
│   ├── VideoProcessingPipeline.swift
│   ├── VideoTransformBuilder.swift
│   ├── VideoSaver.swift
│   ├── MemoryManager.swift
│   ├── VideoHealthMonitor.swift
│   ├── VideoLoadingService.swift
│   ├── AppContainer.swift
│   ├── AppLogger.swift
│   ├── EnhancedVideoLogger.swift
│   ├── EnhancedVideoErrorHandler.swift
│   ├── MemoryErrorHandler.swift
│   ├── PlayerInitializer.swift
│   ├── PlayerItemStatusMonitor.swift
│   ├── ContinuationManager.swift
│   └── Processing/          # (Empty directory - components moved to root)
├── Managers/                # Service layer managers (11 files)
│   ├── AddMoveStateManager.swift
│   ├── VideoPlayerManager.swift
│   ├── VideoPlayerCacheManager.swift
│   ├── AddMovePlayerManager.swift
│   ├── UnifiedPlayerManager.swift
│   ├── BreakDexAlbumManager.swift
│   ├── AlbumSyncManager.swift
│   ├── PhotosPermissionManager.swift
│   ├── MovePersistenceService.swift
│   ├── PhotosImportService.swift
│   ├── PhotosClient.swift
│   ├── VideoAssetPreparer.swift
│   └── SeekScheduler.swift
├── CoreData/                # Data models and persistence (9 files)
│   ├── Persistence.swift
│   ├── Move+CoreDataClass.swift
│   ├── Move+CoreDataProperties.swift
│   ├── Combo+CoreDataClass.swift
│   ├── Combo+CoreDataProperties.swift
│   ├── ComboMove+CoreDataClass.swift
│   ├── ComboMove+CoreDataProperties.swift
│   ├── Review+CoreDataClass.swift
│   └── Review+CoreDataProperties.swift
├── Utils/                   # Utility functions and extensions (13 files)
│   ├── DesignSystem.swift
│   ├── Color+Extensions.swift
│   ├── Font+Extensions.swift
│   ├── ButtonStyles.swift
│   ├── AVAsset+Extensions.swift
│   ├── Combine+Extensions.swift
│   ├── EnhancedTabView.swift
│   ├── AnimationTester.swift
│   ├── MotionCatalog.swift
│   ├── Quantizer.swift
│   ├── SharedElementNavigation.swift
│   ├── StatePillView.swift
│   └── TimelineNodeView.swift
└── Models/                  # Data type definitions (1 file)
    └── VideoImportTypes.swift
```