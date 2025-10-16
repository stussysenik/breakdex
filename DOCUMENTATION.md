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

**Architecture Status:** ✅ **Clean Architecture Optimized (October 2025)** - Successfully refined to 63 Swift files with streamlined video trimming and enhanced service integration.

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
│   │   │   │   ├── SelectClip.swift    # Enhanced video selection interface
│   │   │   │   └── NameMoveView.swift  # Move naming interface
│   │   │   └── Services/
│   │   │       ├── MovePersistenceService.swift # Move CRUD operations
│   │   │       ├── MoveSaver.swift     # Enhanced move saving service
│   │   │       └── VideoProcessor.swift # Video processing service
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
│   │       │   │   ├── SharedButton.swift # Enhanced reusable button component
│   │       │   │   ├── LoadingView.swift # Loading states
│   │       │   │   ├── StatePillView.swift # State indicator pills
│   │       │   │   └── TimelineNodeView.swift # Timeline node components
│   │       │   └── Styles/
│   │       │       ├── DesignSystem.swift # Complete design system with colors, fonts, spacing
│   │       │       └── Typography.swift # Typography system
│   │       ├── Video/
│   │       │   ├── VideoPlayer.swift   # Core video player
│   │       │   ├── AVPlayerViewRepresentable.swift # AVFoundation SwiftUI wrapper
│   │       │   ├── MinimalTrimmerView.swift # Streamlined video trimming interface
│   │       │   ├── VideoLoadingState.swift # Video loading state management
│   │       │   └── SimpleLoading.swift # Simple loading component
│   │       ├── Utils/
│   │       │   ├── AVAsset+Extensions.swift # AVAsset extensions
│   │       │   ├── Combine+Extensions.swift # Combine utilities
│   │       │   ├── Font+Extensions.swift # Font utilities
│   │       │   ├── ButtonStyles.swift # Enhanced button styling
│   │       │   ├── TimecodeFormatter.swift # Time formatting
│   │       │   ├── PerformanceOptimizer.swift # Performance optimization tools
│   │       │   ├── MemoryHelper.swift # Memory management utilities
│   │       │   └── HapticFeedback.swift # Haptic feedback utilities
│   │       ├── Models/
│   │       │   ├── PhotosPickerItem.swift # Photos picker model
│   │       │   ├── ProgressTypes.swift # Progress tracking types
│   │       │   ├── LoggerTypes.swift # Logging system types
│   │       │   ├── TabState.swift # Tab state management
│   │       │   ├── UnifiedState.swift # Unified state management
│   │       │   └── TrimModification.swift # Video trim modification model
│   │       ├── Services/
│   │       │   ├── AppContainer.swift # Dependency injection container
│   │       │   ├── PersistenceBridge.swift # Persistence integration bridge
│   │       │   ├── PhotoKitService.swift # PhotoKit integration
│   │       │   ├── PhotosAssetLoader.swift # Asset loading
│   │       │   ├── TimecodeCalculationService.swift # Timecode calculations
│   │       │   ├── VideoInitializationCoordinator.swift # Video initialization coordination
│   │       │   ├── VideoLoadingOperationManager.swift # Video loading operation management
│   │       │   ├── VideoLoadingService.swift # Video loading service
│   │       │   ├── VideoProgressMonitoringService.swift # Progress monitoring
│   │       │   └── VideoSaver.swift # Enhanced video saving
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

**Architecture Achievement:** From 100+ scattered files → 63 optimized files with streamlined video trimming and enhanced service coordination

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

#### AddMove Feature (Streamlined Implementation ✅)
- **Views**: AddMoveView, SelectClip (enhanced video selection), NameMoveView
- **Services**: MovePersistenceService, VideoProcessor, MoveSaver
- **Key Achievement**: Optimized video selection workflow with enhanced loading states and error handling

#### Arsenal Feature
- **Views**: BreakingArsenalView, MoveListView, MoveDetailView, ComboListView
- **ViewModels**: ArsenalViewModel with clean business logic

#### Combo Feature
- **Views**: CreateComboView, ComboTimelineView
- **ViewModels**: ComboViewModel for combo management

#### Review Feature
- **Views**: ReviewView for learning interface
- **ViewModels**: ReviewViewModel for spaced repetition logic

#### Shared Components (Streamlined ✅)
- **Video Components**: VideoPlayer, AVPlayerViewRepresentable, MinimalTrimmerView, VideoLoadingState, SimpleLoading
- **UI Components**: SharedButton, LoadingView, StatePillView, TimelineNodeView, DesignSystem (integrated colors/fonts)
- **Services**: PhotoKitService, VideoLoadingService, VideoInitializationCoordinator, AppContainer
- **Utils**: Performance-optimized extensions and utilities

### Key Workflows

#### Add Move Flow (Streamlined & Enhanced)
1. **Video Selection** - Enhanced SelectClip interface with loading states and error handling
2. **Video Trimming** - Streamlined MinimalTrimmerView with frame-accurate trimming and rotation
3. **Move Naming** - Clean naming interface
4. **Save Processing** - Background processing with progress tracking via VideoInitializationCoordinator

#### Review System
- **Learning States**: NEW → LEARNING → MASTERY
- **Spaced Repetition**: Performance-based scheduling
- **Video Flashcards**: Full-motion learning aids

#### Video Processing (Streamlined Components ✅)
- **VideoPlayer**: Unified video playback across all features
- **MinimalTrimmerView**: Streamlined trimming interface with rotation support and optimized performance
- **VideoLoadingState**: Enhanced loading state management
- **SimpleLoading**: Reusable loading component with error handling
- **iCloud Support**: Automatic download and processing via VideoInitializationCoordinator

---

## 🎯 Key Services (Streamlined Architecture)

### Core Services
- **AppContainer**: Dependency injection container for service management
- **PersistenceBridge**: Integration between persistence layers
- **PhotoKitService**: PhotoKit integration and asset management

### Video Services (Streamlined)
- **VideoLoadingService**: Background video loading with progress monitoring
- **VideoInitializationCoordinator**: Enhanced video initialization and coordination
- **VideoLoadingOperationManager**: Advanced video loading operation management
- **VideoProgressMonitoringService**: Progress tracking for all video operations
- **VideoSaver**: Enhanced video saving with resilience

### Support Services
- **PhotosAssetLoader**: Asset loading from Photos library
- **TimecodeCalculationService**: Precise timecode calculations
- **MovePersistenceService**: Move CRUD operations with Core Data

### UI Components & Design System
- **DesignSystem**: Complete design system with integrated colors, fonts, spacing, and styling
- **SharedButton**: Enhanced reusable button component
- **LoadingView**: Comprehensive loading states with error handling
- **StatePillView**: State indicator pills for learning progression
- **TimelineNodeView**: Timeline node components for combo creation

---

## 🔍 State Management (Streamlined Architecture)

### Unified State Management
- **UnifiedState**: Centralized state management across all features
- **TabState**: Unified tab navigation state
- **ProgressTypes**: Standardized progress tracking types
- **LoggerTypes**: Comprehensive logging system types
- **TrimModification**: Video trim modification state management

### Feature-Based State Management
- **AddMove**: Enhanced state flow through SelectClip → MinimalTrimmerView → NameMoveView
- **Arsenal**: ViewModel-driven state with @Published properties
- **Combo**: Centralized combo creation and management state
- **Review**: Learning state progression with spaced repetition

### Video State Management
- **VideoLoadingState**: Enhanced video loading state with progress tracking
- **SimpleLoading**: Reusable loading component with error states
- **VideoInitializationCoordinator**: Streamlined video initialization state
- **Performance Monitoring**: Optimized performance with PerformanceOptimizer

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

## 🛠 Development Guidelines (Clean Architecture)

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

## 📊 Project Statistics (Streamlined Architecture)

- **Total Swift Files**: 63 (optimized, down from 100+ scattered)
- **Main Architecture Components**: Features-based (AddMove, Arsenal, Combo, Review, Shared)
- **Core Data Entities**: 4 (Move, Combo, ComboMove, Review)
- **Shared Components**: Streamlined (Video, UI, Utils, Services, Models)
- **Key Improvements**: Streamlined video trimming workflow, enhanced loading states, integrated design system
- **Architecture Achievement**: Optimized from scattered to streamlined with enhanced service coordination
- **Supported iOS Version**: iOS 18.0+
- **Primary Frameworks**: SwiftUI, Core Data, Photos, AVFoundation

---

## 🔄 Version History

### October 2025 - Streamlined Architecture Complete ✅
- **Week 1**: Video Selection Enhancement - Replaced complex picker with streamlined SelectClip interface
- **Week 2**: Trimming Optimization - Implemented MinimalTrimmerView replacing complex trimming UI
- **Week 3**: Service Coordination - Enhanced VideoInitializationCoordinator and VideoLoadingOperationManager
- **Week 4**: Design System Integration - Consolidated colors, fonts, and styling into unified DesignSystem
- **Final State**: 63 optimized Swift files with streamlined architecture
- **Key Result**: Enhanced user experience with simplified video workflow and robust error handling
- **Latest Milestone**: Production-ready architecture with optimized video processing and enhanced service coordination

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

**Architecture Status: ✅ STREAMLINED ARCHITECTURE COMPLETE**

*This documentation now accurately reflects the current streamlined architecture state of the codebase with 63 optimized Swift files, enhanced video processing workflow, and integrated design system. It serves as a comprehensive reference for ongoing development and maintenance.*