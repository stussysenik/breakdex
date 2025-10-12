# breakdex - Documentation

## 📱 Project Overview

**Purpose:** Quick reference guide for new developers to understand the breakdex codebase architecture.

**breakdex** is an iOS 18.0 video flashcard application designed for learning and reviewing complex physical movements. The app allows users to import videos from their Photos library, trim them with millisecond precision, organize them into combos, and review them using a spaced repetition system.

**Key Features:**
- Video import from Photos library with iCloud support
- Frame-accurate video trimming with custom UI
- Movement organization (moves + combos)
- Spaced repetition learning system
- Core Data persistence with Photos sync
- iOS 18.0 native SwiftUI interface

**Architecture Status:** ✅ **Clean Architecture Complete (October 2025)** - Successfully transformed from complex scattered structure to organized feature-based architecture.

---

## 🏗️ Architecture Overview

### Core Technologies
- **SwiftUI** - Modern declarative UI framework
- **Core Data** - Local data persistence with migration support
- **Photos Framework** - Video asset management and iCloud integration
- **AVFoundation** - Video processing and playback
- **Swift Concurrency** - async/await patterns throughout

### Architectural Patterns (Implemented ✅)
- **Feature-Based Architecture** - All code organized by feature under `Features/`
- **MVVM** - Model-View-ViewModel with SwiftUI
- **Shared Components** - Reusable UI, Video, and Utility components
- **Single Responsibility Principle** - Files kept focused and maintainable
- **Dependency Injection** - Clean separation of concerns

---

## 📁 Project Structure (Clean Architecture ✅)

```
BreakingFlashcards/
├── breakdex/                           # Main app source code
│   ├── App/                            # App entry point (2 files)
│   │   ├── breakdex.swift              # Main app entry point
│   │   └── MainView.swift              # Tab navigation container
│   ├── CoreData/                       # Data models and persistence
│   │   ├── Persistence.swift           # Core Data stack
│   │   ├── Move+CoreDataClass.swift    # Move entity
│   │   ├── Move+CoreDataProperties.swift # Move properties
│   │   ├── Combo+CoreDataClass.swift   # Combo entity
│   │   ├── Combo+CoreDataProperties.swift # Combo properties
│   │   ├── ComboMove+CoreDataClass.swift # Join entity
│   │   ├── ComboMove+CoreDataProperties.swift # Join properties
│   │   ├── Review+CoreDataClass.swift  # Review entity
│   │   └── Review+CoreDataProperties.swift # Review properties
│   ├── Features/                       # ALL feature code organized cleanly
│   │   ├── AddMove/                    # Video import workflow
│   │   │   ├── Views/
│   │   │   │   ├── AddMoveView.swift   # Main add move container
│   │   │   │   ├── VideoPickerView.swift # Photos picker interface
│   │   │   │   ├── VideoTrimView.swift # Video trimming interface
│   │   │   │   └── NameMoveView.swift  # Move naming interface
│   │   │   └── Services/
│   │   │       ├── VideoLoader.swift   # Video loading service
│   │   │       ├── VideoProcessor.swift # Video processing service
│   │   │       └── MoveSaver.swift     # Move saving service
│   │   ├── Arsenal/                    # Move/combo management
│   │   │   ├── Views/
│   │   │   │   ├── BreakingArsenalView.swift # Arsenal tab container
│   │   │   │   ├── MoveListView.swift  # List all moves
│   │   │   │   ├── MoveDetailView.swift # Move detail view
│   │   │   │   └── ComboListView.swift # List all combos
│   │   │   └── ViewModels/
│   │   │       └── ArsenalViewModel.swift # Arsenal business logic
│   │   ├── Combo/                      # Combo creation and management
│   │   │   ├── Views/
│   │   │   │   ├── CreateComboView.swift # Create new combo
│   │   │   │   └── ComboTimelineView.swift # Combo timeline
│   │   │   └── ViewModels/
│   │   │       └── ComboViewModel.swift # Combo business logic
│   │   ├── Review/                     # Learning system
│   │   │   ├── Views/
│   │   │   │   └── ReviewView.swift    # Review interface
│   │   │   └── ViewModels/
│   │   │       └── ReviewViewModel.swift # Review business logic
│   │   └── Shared/                     # Shared components across features
│   │       ├── UI/
│   │       │   ├── Components/
│   │       │   │   ├── Button.swift    # Reusable button component
│   │       │   │   ├── LoadingView.swift # Loading states
│   │       │   │   ├── StatePillView.swift # State indicator pills
│   │       │   │   └── TimelineNodeView.swift # Timeline node components
│   │       │   └── Styles/
│   │       │       ├── Colors.swift    # Color system
│   │       │       └── Typography.swift # Typography system
│   │       ├── Video/
│   │       │   ├── VideoPlayer.swift   # Core video player
│   │       │   ├── VideoPlayerView.swift # SwiftUI wrapper
│   │       │   ├── VideoTrimmer.swift  # Video trimming logic
│   │       │   └── VideoExporter.swift # Video export functionality
│   │       ├── Utils/
│   │       │   ├── Color+Extensions.swift # Color utilities
│   │       │   ├── Font+Extensions.swift # Font utilities
│   │       │   ├── AVAsset+Extensions.swift # AVAsset extensions
│   │       │   ├── Combine+Extensions.swift # Combine utilities
│   │       │   ├── DesignSystem.swift # Design system
│   │       │   ├── TimecodeFormatter.swift # Time formatting
│   │       │   ├── ButtonStyles.swift # Button styling
│   │       │   ├── PerformanceOptimizer.swift # Performance tools
│   │       │   ├── MemoryHelper.swift # Memory utilities
│   │       │   └── HapticFeedback.swift # Haptic feedback utilities
│   │       ├── Models/
│   │       │   ├── PhotosPickerItem.swift # Photos picker model
│   │       │   ├── VideoImportTypes.swift # Import type definitions
│   │       │   ├── LoggerTypes.swift # Logging system types
│   │       │   ├── ProgressTypes.swift # Progress tracking types
│   │       │   ├── TabState.swift # Tab state management
│   │       │   ├── UnifiedState.swift # Unified state management
│   │       │   └── VideoProcessingTypes.swift # Video processing types
│   │       ├── Services/
│   │       │   ├── MovePersistenceService.swift # Move CRUD operations
│   │       │   ├── PhotoKitService.swift # PhotoKit integration
│   │       │   ├── PhotosAssetLoader.swift # Asset loading
│   │       │   ├── PhotosPersistenceService.swift # Photos persistence
│   │       │   ├── ResilientVideoLoader.swift # Resilient video loading
│   │       │   ├── ResilientVideoLoaderIntegration.swift # Integration layer
│   │       │   ├── VideoLoadingService.swift # Video loading
│   │       │   ├── VideoLoadingServiceResilient.swift # Enhanced video loading
│   │       │   ├── VideoProgressMonitoringService.swift # Progress monitoring
│   │       │   ├── UnifiedPlayerManager.swift # Unified video player management
│   │       │   ├── UnifiedProgressEngine.swift # Unified progress tracking
│   │       │   ├── PersistenceBridge.swift # Persistence integration bridge
│   │       │   ├── VideoProcessingBridge.swift # Video processing bridge
│   │       │   ├── TimecodeCalculationService.swift # Timecode calculations
│   │       │   ├── VideoSaver.swift # Enhanced video saving
│   │       │   └── AppContainer.swift # Dependency injection container
│   │       ├── ViewModels/
│   │       │   └── SaveProgressViewModel.swift # Save progress UI
│   │       └── FeatureFlag.swift        # Feature flag management
│   └── Resources/
│       └── Assets.xcassets/           # App assets and resources
├── breakdex.xcodeproj                # Xcode project file
├── breakdexTests/                    # Unit tests
├── breakdexUITests/                  # UI test targets
└── DOCUMENTATION.md                  # This documentation file
```

**Architecture Achievement:** From 100+ scattered files → 73+ organized files under clean feature-based structure with advanced unified services

---

## 🔧 Core Components (Clean Architecture)

### App Entry Point
- **breakdex.swift**: Main app initialization, Core Data setup, health checks
- **MainView.swift**: Root container with 4-tab navigation (Arsenal, Add, Create, Review)

### Data Models (Core Data)
- **Move**: Individual video flashcard with trimming, rotation, and learning state
- **Combo**: Collections of moves for sequence learning
- **ComboMove**: Many-to-many relationship with sequence ordering
- **Review**: Learning session records with performance ratings

### Feature Architecture

#### AddMove Feature (Clean Implementation ✅)
- **Views**: VideoPickerView, VideoTrimView, NameMoveView, AddMoveView
- **Services**: VideoLoader, VideoProcessor, MoveSaver
- **Key Achievement**: 84% code reduction from 7k LOC to ~1.1k LOC

#### Arsenal Feature
- **Views**: BreakingArsenalView, MoveListView, MoveDetailView, ComboListView
- **ViewModels**: ArsenalViewModel with clean business logic

#### Combo Feature
- **Views**: CreateComboView, ComboTimelineView
- **ViewModels**: ComboViewModel for combo management

#### Review Feature
- **Views**: ReviewView for learning interface
- **ViewModels**: ReviewViewModel for spaced repetition logic

#### Shared Components (Reusable ✅)
- **Video Components**: VideoPlayer, VideoPlayerView, VideoTrimmer, VideoExporter
- **UI Components**: Button, LoadingView, Colors, Typography
- **Services**: Photos, Video Loading, Persistence services
- **Utils**: Extensions, Design System, Performance tools

### Key Workflows

#### Add Move Flow (Simplified & Clean)
1. **Video Selection** - Photos picker interface
2. **Video Trimming** - Frame-accurate trimming with shared VideoTrimmer
3. **Move Naming** - Clean naming interface
4. **Save Processing** - Background processing with progress tracking

#### Review System
- **Learning States**: NEW → LEARNING → MASTERY
- **Spaced Repetition**: Performance-based scheduling
- **Video Flashcards**: Full-motion learning aids

#### Video Processing (Shared Components ✅)
- **VideoPlayer**: Unified video playback across all features
- **VideoTrimmer**: Reusable trimming with rotation support
- **VideoExporter**: High-quality export with multiple presets
- **iCloud Support**: Automatic download and processing of iCloud assets

---

## 🎯 Key Services (Advanced Unified Architecture)

### Unified Management Services
- **UnifiedPlayerManager**: Centralized video player management across all features
- **UnifiedProgressEngine**: Unified progress tracking for all async operations
- **AppContainer**: Dependency injection container for service management

### Shared Video Services
- **VideoLoader**: Unified video loading from Photos with iCloud support
- **VideoProcessor**: Video composition, trimming, and export operations
- **VideoPlayer**: Consistent video playback across all features
- **VideoTrimmer**: Frame-accurate trimming with rotation support
- **VideoExporter**: High-quality export with multiple quality presets
- **VideoSaver**: Enhanced video saving with resilience
- **VideoLoadingServiceResilient**: Advanced resilient video loading
- **ResilientVideoLoaderIntegration**: Integration layer for resilient loading

### Bridge Services
- **PersistenceBridge**: Integration between persistence layers
- **VideoProcessingBridge**: Bridge for video processing operations
- **TimecodeCalculationService**: Precise timecode calculations

### Photos Services
- **PhotoKitService**: PhotoKit integration and asset management
- **PhotosAssetLoader**: Resilient asset loading from iCloud
- **PhotosPersistenceService**: Photos library synchronization

### Data Services
- **MovePersistenceService**: Move CRUD operations with Core Data
- **VideoLoadingService**: Background video loading with progress
- **VideoProgressMonitoringService**: Progress tracking for operations

### UI Services
- **Colors & Typography**: Consistent design system across features
- **Button & LoadingView**: Reusable UI components
- **DesignSystem**: Centralized styling and theming
- **StatePillView & TimelineNodeView**: Advanced UI components

---

## 🔍 State Management (Advanced Unified Architecture)

### Unified State Management
- **UnifiedState**: Centralized state management across all features
- **TabState**: Unified tab navigation state
- **ProgressTypes**: Standardized progress tracking types
- **LoggerTypes**: Comprehensive logging system types

### Feature-Based State Management
- **AddMove**: Clean state flow through Views → Services → Core Data
- **Arsenal**: ViewModel-driven state with @Published properties
- **Combo**: Centralized combo creation and management state
- **Review**: Learning state progression with spaced repetition

### Shared State Components
- **VideoPlayer State**: Unified player state across all features via UnifiedPlayerManager
- **Progress Tracking**: Unified progress monitoring via UnifiedProgressEngine
- **Error Handling**: Centralized error states and user feedback
- **Performance Monitoring**: Advanced performance optimization with PerformanceOptimizer

### Learning States
- **NEW**: Blue state - not yet reviewed
- **LEARNING**: Yellow state - in progress
- **MASTERY**: Green state - mastered

### Data Consistency
- **Photos Sync**: Automatic synchronization on app launch/activation
- **Orphaned Asset Reconciliation**: Cleanup of broken references
- **Migration Support**: Automatic Core Data schema migration

---

## 🛠 Development Guidelines (Clean Architecture)

### Code Quality Standards (Achieved ✅)
- **Feature-Based Organization**: All code organized under Features/ structure
- **Single Responsibility**: Each file has one clear purpose
- **Shared Components**: Reusable UI, Video, and Utility components
- **Consistent Patterns**: MVVM with SwiftUI across all features
- **Clean Dependencies**: Proper separation between Views, ViewModels, and Services

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
- **Unit Tests**: All ViewModels, Services, and Utilities
- **UI Tests**: Critical user flows (video playback, trimming, add move)
- **Integration Tests**: Feature-to-feature communication
- **Memory Testing**: Retain cycle prevention verification

### Architecture Benefits Achieved
- **Maintainability**: Easy to locate and modify code by feature
- **Reusability**: Shared components reduce code duplication
- **Testability**: Clean separation enables focused testing
- **Onboarding**: New developers can understand structure quickly

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

## 📊 Project Statistics (Clean Architecture)

- **Total Swift Files**: 73+ (organized, down from 100+ scattered)
- **Main Architecture Components**: Features-based (AddMove, Arsenal, Combo, Review, Shared)
- **Core Data Entities**: 4 (Move, Combo, ComboMove, Review)
- **Shared Components**: Comprehensive (Video, UI, Utils, Services, Models)
- **Code Reduction**: 84% reduction in AddMove feature (7k LOC → 1.1k LOC)
- **Architecture Achievement**: Complete transformation from scattered to organized with advanced unified service architecture
- **Supported iOS Version**: iOS 18.0+
- **Primary Frameworks**: SwiftUI, Core Data, Photos, AVFoundation

---

## 🔄 Version History

### October 2025 - Advanced Unified Architecture Complete ✅
- **Week 1**: Clean AddMove Feature - Replaced 7k LOC monolith with ~1.1k LOC (84% reduction)
- **Week 2**: Shared Video Components - Created reusable Video, UI, and Utility components
- **Week 3**: Advanced Service Integration - Unified Player Manager, Progress Engine, and Bridge Services
- **Week 4**: Enhanced Architecture - Resilient loading, performance optimization, and advanced state management
- **Final State**: 73+ Swift files with advanced unified architecture
- **Key Result**: Production-ready, maintainable architecture with sophisticated service integration
- **Latest Milestone**: Functional build achieved with all advanced components integrated

### September 2025
- Critical video playback fixes (flicker, deadlock resolution)
- Enhanced diagnostic logging throughout video pipeline
- Improved state management architecture
- Major AddMove refactoring (3,349 → 227 lines, 93% reduction)

### August 2025
- Initial architecture establishment
- Core Data schema implementation
- Video processing pipeline development

---

**Architecture Status: ✅ ADVANCED UNIFIED ARCHITECTURE COMPLETE**

*This documentation now accurately reflects the current advanced unified architecture state of the codebase with 73+ organized Swift files, sophisticated service integration, and production-ready components. It serves as a comprehensive reference for ongoing development and maintenance.*