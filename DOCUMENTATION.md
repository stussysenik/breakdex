# breakdex - Documentation

## 📱 Project Overview

NOTE: purpose of this document is to serve as a quick reference + allow new developers to get up to speed with the breakdex codebase

**breakdex** is an iOS 18.0 video flashcard application designed for learning and reviewing complex physical movements. The app allows users to import videos from their Photos library, trim them with millisecond precision, organize them into combos, and review them using a spaced repetition system.

**Key Features:**
- Video import from Photos library with iCloud support
- Frame-accurate video trimming with custom UI
- Movement organization (moves + combos)
- Spaced repetition learning system
- Core Data persistence with Photos sync
- iOS 18.0 native SwiftUI interface

---

## 🏗️ Architecture Overview

### Core Technologies
- **SwiftUI** - Modern declarative UI framework
- **Core Data** - Local data persistence with migration support
- **Photos Framework** - Video asset management and iCloud integration
- **AVFoundation** - Video processing and playback
- **Swift Concurrency** - async/await patterns throughout

### Architectural Patterns
- **MVVM** - Model-View-ViewModel with SwiftUI
- **Unidirectional Data Flow** - State-driven UI updates
- **Component-Based Architecture** - Modular, reusable components
- **Single Responsibility Principle** - Files limited to ~500 lines

---

## 📁 Project Structure

```
BreakingFlashcards/
├── breakdex/                           # Main app source code
│   ├── AppCore/
│   │   ├── Breakdex.swift     # Main app entry point
│   │   ├── BreakingArsenalView.swift       # Arsenal tab container
│   │   └── FeatureFlag.swift               # Feature flag management
│   ├── CoreData/                         # Data models and persistence
│   │   ├── Persistence.swift               # Core Data stack
│   │   ├── Move+CoreDataClass.swift        # Move entity
│   │   ├── Move+CoreDataProperties.swift   # Move properties
│   │   ├── Combo+CoreDataClass.swift       # Combo entity
│   │   ├── Combo+CoreDataProperties.swift  # Combo properties
│   │   ├── ComboMove+CoreDataClass.swift   # Join entity
│   │   ├── ComboMove+CoreDataProperties.swift # Join properties
│   │   ├── Review+CoreDataClass.swift      # Review entity
│   │   └── Review+CoreDataProperties.swift # Review properties
│   ├── Views/
│   │   ├── Arsenal/                      # Move/combo management
│   │   │   ├── Moves/
│   │   │   │   ├── MoveListView.swift         # List all moves
│   │   │   │   ├── MoveDetailView.swift       # Move detail view
│   │   │   │   ├── AvailableMoveRowView.swift # Move row component
│   │   │   │   └── MovePickerSheet.swift      # Move selection UI
│   │   │   ├── Combos/
│   │   │   │   ├── ComboListView.swift        # List all combos
│   │   │   │   ├── ComboDetailView.swift      # Combo detail view
│   │   │   │   ├── ComboDetailHeaderView.swift # Combo header
│   │   │   │   ├── ComboDetailPlayerView.swift # Combo video player
│   │   │   │   ├── ComboTimelineView.swift    # Combo timeline
│   │   │   │   └── CreateComboView.swift      # Create new combo
│   │   │   └── AddMove/                    # Video import workflow
│   │   │       ├── AddMoveView.swift           # Add move entry point
│   │   │       ├── AddMoveContainer.swift      # State container
│   │   │       ├── AddMoveUnifiedState.swift   # Flow coordinator
│   │   │       ├── State/
│   │   │       │   ├── AddMoveFlowState.swift     # 5-stage state enum
│   │   │       │   └── FlowStateManager.swift     # Flow management
│   │   │       ├── Validation/
│   │   │       │   ├── StateValidator.swift       # State validation
│   │   │       │   └── AddMoveValidationTypes.swift # Validation types
│   │   │       ├── Operations/
│   │   │       │   └── SaveOperationCoordinator.swift # Save operations
│   │   │       ├── Services/
│   │   │       │   ├── TimerManager.swift         # Timer operations
│   │   │       │   ├── ProgressMonitor.swift     # Progress tracking
│   │   │       │   └── AddMoveVideoOrchestrator.swift # Video orchestration
│   │   │       ├── AddMoveSaveCoordinator.swift  # Save coordination
│   │   │       ├── PreTrimViewUnified.swift      # Video preview
│   │   │       └── ImportExportView.swift        # Import/export UI
│   │   ├── Review/                       # Learning system
│   │   │   ├── ReviewView.swift               # Review dashboard
│   │   │   └── FlashcardsReviewView.swift    # Review interface
│   │   └── Video/                        # Video processing UI
│   │       ├── Player/
│   │       │   ├── CustomVideoPlayerView.swift    # Video player UI
│   │       │   ├── AVPlayerViewRepresentable.swift # AVPlayer wrapper
│   │       │   └── VideoPlayerViewModelProtocol.swift # Player protocol
│   │       ├── Trim/
│   │       │   └── TrimmerViewModel.swift         # Trimmer logic
│   │       └── Re-link/
│   │           ├── VideoRelinkView.swift          # Relink UI
│   │           └── VideoRelinkManager.swift       # Relink logic
│   ├── Managers/                           # Business logic services
│   │   ├── AlbumManager.swift                # Photos album management
│   │   ├── AlbumSyncManager.swift            # Album synchronization
│   │   ├── ImportManager.swift               # Video import logic
│   │   ├── MovePersistenceService.swift      # Move CRUD operations
│   │   ├── PhotosPermissionManager.swift     # Photos permissions
│   │   ├── PhotosImportService.swift         # Import orchestration
│   │   ├── VideoAssetPreparer.swift          # Video preparation
│   │   ├── BreakDexAlbumManager.swift        # Album operations
│   │   ├── PhotosAssetLoader.swift           # Asset loading
│   │   ├── PhotosClient.swift                # Photos API client
│   │   ├── SeekScheduler.swift               # Video seeking
│   │   └── NavigationCoordinator.swift       # Navigation logic
│   ├── Services/                           # Supporting services
│   │   ├── PhotoKitService.swift              # PhotoKit integration
│   │   ├── PhotosPersistenceService.swift    # Photos persistence
│   │   ├── ErrorHandlingService.swift        # Error management
│   │   ├── VideoLoadingService.swift         # Video loading
│   │   └── VideoProgressMonitoringService.swift # Progress monitoring
│   ├── Video/                              # Video processing pipeline
│   │   ├── VideoProcessor.swift               # Video processing interface
│   │   ├── VideoProcessorImpl.swift          # Processing implementation
│   │   ├── EnhancedVideoProcessor.swift      # Enhanced processor
│   │   ├── VideoState.swift                  # Video state management
│   │   ├── VideoStateManager.swift           # State coordination
│   │   ├── VideoTransformBuilder.swift       # Video transformations
│   │   ├── VideoSaver.swift                  # Video saving
│   │   ├── VideoAssetValidator.swift         # Asset validation
│   │   ├── VideoHealthMonitor.swift          # Health monitoring
│   │   ├── VideoHealthStatus.swift           # Health status types
│   │   ├── EnhancedVideoErrorHandler.swift   # Error handling
│   │   ├── EnhancedVideoLogger.swift         # Video logging
│   │   ├── MemoryErrorHandler.swift          # Memory error handling
│   │   ├── MemoryManager.swift               # Memory management
│   │   ├── ContinuationManager.swift         # Async continuations
│   │   ├── PlayerInitializer.swift           # Player setup
│   │   ├── PlayerItemStatusMonitor.swift     # Player monitoring
│   │   ├── VideoProcessingError.swift        # Processing errors
│   │   └── AppLogger.swift                   # App-wide logging
│   ├── Utils/                              # Utility components
│   │   ├── TimecodeCalculationService.swift  # Timecode calculations
│   │   ├── TimecodeFormatter.swift           # Time formatting
│   │   ├── Color+Extensions.swift            # Color utilities
│   │   ├── Font+Extensions.swift             # Font utilities
│   │   ├── AVAsset+Extensions.swift          # AVAsset extensions
│   │   ├── Combine+Extensions.swift          # Combine utilities
│   │   ├── EnhancedTabView.swift             # Custom tab view
│   │   ├── StatePillView.swift               # State indicator
│   │   ├── TimelineNodeView.swift            # Timeline component
│   │   ├── ButtonStyles.swift                # Button styling
│   │   ├── MotionCatalog.swift               # Animations/haptics
│   │   ├── AnimationTester.swift             # Animation testing
│   │   ├── PerformanceOptimizer.swift        # Performance tools
│   │   ├── AssetInheritanceCoordinator.swift # Asset coordination
│   │   ├── FrameSynchronizer.swift           # Frame sync
│   │   ├── SharedElementNavigation.swift     # Navigation animations
│   │   ├── VideoReplacementCoordinator.swift # Video replacement
│   │   ├── ReactiveTimeCodeComponent.swift   # Timecode component
│   │   ├── Quantizer.swift                   # Data quantization
│   │   ├── MemoryHelper.swift                # Memory utilities
│   │   ├── DiagnosticLoggingHelper.swift     # Debug logging
│   │   ├── ElapsedTimeTracker.swift          # Time tracking
│   │   ├── PhotosAssetService.swift          # Photos utilities
│   │   ├── VideoReplacementCoordinator.swift # Video replacement
│   │   └── FunctorPathAnalyzer.swift         # Path analysis
│   ├── Models/                             # Data models
│   │   ├── VideoImportTypes.swift            # Import type definitions
│   │   └── PhotosPickerItem.swift            # Photos picker model
│   ├── ViewModels/                         # View models
│   │   └── SaveProgressViewModel.swift       # Save progress UI
│   ├── Coordinators/                       # Coordination logic
│   │   └── StateTransitionCoordinator.swift  # State transitions
│   └── Assets.xcassets/                    # App assets and resources
├── breakdex.xcodeproj                    # Xcode project file
├── breakdexUITests/                      # UI test targets
└── DOCUMENTATION.md                      # This documentation file
```

---

## 🔧 Core Components

### App Entry Point
- **breakdex.swift**: Main app initialization, Core Data setup, health checks

### Main Navigation
- **MainView**: Root container with 4-tab navigation (Arsenal, Add, Create, Review)
- **EnhancedTabView**: Custom tab styling and navigation

### Data Models (Core Data)
- **Move**: Individual video flashcard with trimming, rotation, and learning state
- **Combo**: Collections of moves for sequence learning
- **ComboMove**: Many-to-many relationship with sequence ordering
- **Review**: Learning session records with performance ratings

### Key Workflows

#### Add Move Flow (5-Stage Process)
1. **loadingVideo** - Import video from Photos with progress tracking
2. **trimming** - Frame-accurate video trimming interface
3. **loadingTrimmedAsset** - Process trimmed asset with progress
4. **naming** - User names the movement
5. **saving** - Save to Core Data and Photos album

#### Review System
- **Learning States**: NEW → LEARNING → MASTERY
- **Spaced Repetition**: Performance-based scheduling
- **Video Flashcards**: Full-motion learning aids

#### Video Processing
- **Frame-Accurate Trimming**: Millisecond precision using TimecodeCalculationService
- **Rotation Support**: 90°, 180°, 270° video rotation handling
- **iCloud Support**: Automatic download and processing of iCloud assets

---

## 🎯 Key Services

### AlbumManager
- **Purpose**: Thread-safe BreakDex album creation and management
- **Features**: Race condition prevention, retry logic, performance metrics

### ImportManager
- **Purpose**: Resilient video asset importing from iCloud
- **Features**: Network interruption handling, exponential backoff, timeout recovery

### PhotosPermissionManager
- **Purpose**: Photos library permission management
- **Features**: Status checking, permission requests, error handling

### TimecodeCalculationService
- **Purpose**: Frame-accurate timecode calculations and validation
- **Features**: Millisecond precision, range validation, consistent formatting

### VideoProcessor/EnhancedVideoProcessor
- **Purpose**: Video composition, trimming, and export
- **Features**: Transform building, player item creation, progress tracking

---

## 🔍 State Management

### AddMove Flow State (Simplified 5-Stage)
```swift
enum AddMoveFlowState {
    case loadingVideo(SimpleProgress)
    case trimming
    case loadingTrimmedAsset(SimpleProgress)
    case naming
    case saving(SimpleProgress)

    // Terminal states
    case ready
    case success
    case error(Error)
}
```

### Learning States
- **NEW**: Blue state - not yet reviewed
- **LEARNING**: Yellow state - in progress
- **MASTERY**: Green state - mastered

### Data Consistency
- **Photos Sync**: Automatic synchronization on app launch/activation
- **Orphaned Asset Reconciliation**: Cleanup of broken references
- **Migration Support**: Automatic Core Data schema migration

---

## 🛠 Development Guidelines

### Code Quality Standards
- **File Size Limit**: ~500 lines per file (SRP principle)
- **Logging**: Comprehensive OSLog with category-based organization
- **Error Handling**: Graceful degradation with detailed error reporting
- **Memory Management**: Proper teardown of video players and async tasks

### Build Verification
```bash
# Full project build
xcodebuild -project breakdex.xcodeproj -scheme breakdex -destination 'platform=iOS Simulator,name=iPhone 16' build

# Syntax validation
swiftc -parse [filename].swift

# Clean build
xcodebuild clean -project breakdex.xcodeproj
```

### Testing Strategy
- **Unit Tests**: All managers, view models, and utilities
- **UI Tests**: Critical user flows (video playback, trimming, add move)
- **Memory Testing**: Retain cycle prevention verification

---

## 📝 Documentation Maintenance

### How to Update This Documentation

This documentation is designed to be **self-maintaining**. When making changes to the codebase:

#### 1. **Before Making Changes**
- Read the relevant section to understand the current architecture
- Note which files/components will be affected by your changes

#### 2. **When Adding New Files**
- Add the file to the appropriate section in the Project Structure
- Update the file count if adding multiple files
- Include a brief description of the file's purpose
- Update any relevant component descriptions

#### 3. **When Modifying Existing Components**
- Update the component description if functionality changes significantly
- Add new sub-sections if the component grows substantially
- Update any cross-references to other components

#### 4. **When Removing Files**
- Remove the file from the Project Structure section
- Update any component descriptions that referenced the removed file
- Check for any dependency information that needs updating

#### 5. **Quarterly Reviews**
- Perform a comprehensive audit of this documentation against the current codebase
- Use the following command to verify all documented files exist:
  ```bash
  find breakdex -name "*.swift" | wc -l  # Count actual Swift files
  ```
- Update the file count and structure based on current state
- Verify all major components are accurately described

### Documentation Update Checklist

When updating this documentation, ensure:

- [ ] File paths are correct and match the actual project structure
- [ ] Component descriptions accurately reflect current functionality
- [ ] Cross-references between components are accurate
- [ ] Code examples and commands are tested and working
- [ ] Architecture diagrams reflect current state
- [ ] File counts and statistics are up-to-date

### Automated Verification (Future Enhancement)

To keep this documentation automatically synchronized, consider implementing:

```bash
# Script to verify documentation accuracy
#!/bin/bash
echo "🔍 Verifying documentation accuracy..."

# Count Swift files in project
actual_files=$(find breakdex -name "*.swift" | wc -l)
echo "📊 Actual Swift files: $actual_files"

# Extract files mentioned in documentation
doc_files=$(grep -o "\w*\.swift" DOCUMENTATION.md | wc -l)
echo "📄 Documented files: $doc_files"

# Compare and report
if [ $actual_files -ne $doc_files ]; then
    echo "⚠️  Documentation may be outdated"
    echo "Consider updating DOCUMENTATION.md"
else
    echo "✅ Documentation appears up-to-date"
fi
```

---

## 🐛 Common Issues & Solutions

### Build Issues
- **"initializers may only be declared within a type"**: Check for extra closing braces
- **"Type of expression is ambiguous"**: Add explicit type annotations
- **Missing dependencies**: Verify proper import statements and target membership

### Runtime Issues
- **Video loading stuck at 99%**: Use completion criteria of 1.0 instead of 0.99
- **Memory warnings**: Implement proper teardown in ViewModels
- **Photos permission issues**: Check permission status before album operations

### Performance Issues
- **Video playback flicker**: Use atomic state updates in loadVideoAsset()
- **Sync deadlocks**: Remove blocking waitForVideoReady() calls
- **Memory leaks**: Verify proper Task cancellation in teardown methods

---

## 📊 Project Statistics

- **Total Swift Files**: 100+ (as of October 2025)
- **Main Architectural Components**: 7 (AppCore, Views, Managers, Services, Video, Utils, Models)
- **Core Data Entities**: 4 (Move, Combo, ComboMove, Review)
- **Key Managers**: 10+ (Album, Import, Photos, Video, etc.)
- **Supported iOS Version**: iOS 18.0+
- **Primary Frameworks**: SwiftUI, Core Data, Photos, AVFoundation

---

## 🔄 Version History

### October 2025
- Critical video playback fixes (flicker, deadlock resolution)
- Enhanced diagnostic logging throughout video pipeline
- Improved state management architecture

### September 2025
- Major AddMove refactoring (3,349 → 227 lines, 93% reduction)
- Simplified 5-stage state machine implementation
- Enhanced album synchronization and data consistency

### August 2025
- Initial architecture establishment
- Core Data schema implementation
- Video processing pipeline development

---

*This documentation should be updated whenever significant architectural changes are made to ensure it remains an accurate reflection of the codebase.*