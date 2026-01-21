# Breakdex

**Your personal breaking move library and practice companion.**

Breakdex is an iOS app for breakdancers to catalog their moves, practice with spaced repetition flashcards, and build combos. Built with SwiftUI and CoreData.

## Quick Start

1. Open `breakdex.xcodeproj` in Xcode 15+
2. Select your target device (iOS 17+)
3. Build and run

## Features at a Glance

| Feature | Status | Description |
|---------|--------|-------------|
| **Move Arsenal** | Complete | Browse and manage your move library |
| **Add Move** | Complete | Import videos from Photos, trim, and tag |
| **Camera Capture** | Complete | Record moves directly in-app |
| **Flashcard Review** | Complete | SM-2 spaced repetition for practice |
| **Combo Builder** | Complete | Chain moves into combos |
| **Settings** | Complete | Accessibility and data management |

## Codebase Navigation

```
breakdex/
├── App/
│   ├── breakdex.swift          # App entry point
│   └── MainView.swift          # Tab-based navigation
│
├── Features/
│   ├── Arsenal/                # Move library browsing
│   │   ├── ViewModels/
│   │   │   └── ArsenalViewModel.swift
│   │   └── Views/
│   │       ├── MoveDetailView.swift
│   │       └── Components/
│   │           └── VideoThumbnailCard.swift
│   │
│   ├── AddMove/                # Video import & move creation
│   │   ├── ViewModels/
│   │   │   ├── AddMoveViewModel.swift
│   │   │   └── TagSuggestionsProvider.swift
│   │   ├── Views/
│   │   │   ├── AddMoveView.swift
│   │   │   └── NameMoveView.swift
│   │   └── Services/
│   │       ├── VideoProcessor.swift
│   │       ├── MovePersistenceService.swift
│   │       └── MoveSaver.swift
│   │
│   ├── Camera/                 # Direct video recording
│   │   ├── ViewModels/
│   │   │   └── CameraViewModel.swift
│   │   └── Views/
│   │       └── CameraView.swift
│   │
│   ├── Review/                 # Flashcard spaced repetition
│   │   ├── Models/
│   │   │   ├── SpacedRepetition.swift   # SM-2 algorithm
│   │   │   └── LearningProgress.swift
│   │   ├── ViewModels/
│   │   │   └── FlashcardReviewViewModel.swift
│   │   └── Views/
│   │       ├── FlashcardReviewView.swift
│   │       ├── FlashcardCardView.swift
│   │       └── RatingButtonsView.swift
│   │
│   ├── Combo/                  # Combo creation & playback
│   │   ├── ViewModels/
│   │   │   └── ComboViewModel.swift
│   │   └── Views/
│   │       ├── CreateComboView.swift
│   │       ├── ComboTimelineView.swift
│   │       ├── ComboDetailView.swift
│   │       └── ComboNamingSheet.swift
│   │
│   ├── Settings/               # App settings
│   │   ├── ViewModels/
│   │   │   └── SettingsViewModel.swift
│   │   └── Views/
│   │       └── SettingsView.swift
│   │
│   └── Shared/                 # Shared components
│       ├── Accessibility/
│       │   └── AccessibilityManager.swift
│       ├── Motion/
│       │   └── MotionSystem.swift
│       ├── UI/
│       │   ├── Styles/
│       │   │   └── DesignSystem.swift
│       │   └── Components/
│       │       ├── CardContainer.swift
│       │       ├── EmptyStateView.swift
│       │       ├── ProgressRingView.swift
│       │       ├── SectionHeaderView.swift
│       │       ├── TagChipView.swift
│       │       ├── TagFlowLayout.swift
│       │       ├── TagInputField.swift
│       │       └── ...
│       ├── Video/
│       │   ├── VideoPlayer.swift
│       │   ├── LiquidScrubber.swift
│       │   ├── ThumbnailGenerator.swift
│       │   ├── MinimalTrimmerView.swift
│       │   └── AVPlayerViewRepresentable.swift
│       ├── Services/
│       │   ├── ThermalGuard.swift
│       │   ├── ThemeManager.swift
│       │   ├── PhotoKitService.swift
│       │   ├── RobustVideoLoader.swift
│       │   └── AppContainer.swift
│       ├── Utils/
│       │   ├── HapticFeedback.swift
│       │   ├── TimecodeFormatter.swift
│       │   ├── PerformanceOptimizer.swift
│       │   └── ...
│       └── Models/
│           ├── LoadingState.swift
│           ├── TabState.swift
│           └── ...
│
├── CoreData/
│   ├── Move+CoreDataClass.swift
│   ├── Move+CoreDataProperties.swift
│   ├── Combo+CoreDataClass.swift
│   ├── Combo+CoreDataProperties.swift
│   ├── ComboMove+CoreDataClass.swift
│   ├── ComboMove+CoreDataProperties.swift
│   ├── Review+CoreDataClass.swift
│   └── Review+CoreDataProperties.swift
│
└── Tests/
    └── breakdexUITests/        # UI tests
```

## Key Technologies

- **SwiftUI** - Declarative UI framework
- **CoreData** - Local persistence for moves, combos, reviews
- **AVFoundation** - Video playback and processing
- **PhotoKit** - Photo library integration
- **SM-2 Algorithm** - Spaced repetition scheduling

## Recent Changes

### January 2026
- Added **Flashcard Review System** with SM-2 spaced repetition
- Added **Camera Capture** for recording moves directly
- Added **Settings View** for accessibility preferences
- Implemented **ThermalGuard** for device temperature monitoring
- Added **AccessibilityManager** for VoiceOver and Dynamic Type support
- New **LiquidScrubber** for precise video scrubbing

## Related Documentation

- [DOCUMENTATION.md](./DOCUMENTATION.md) - Detailed architecture and component reference
- [PROGRESS.md](./PROGRESS.md) - Version history and roadmap

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
