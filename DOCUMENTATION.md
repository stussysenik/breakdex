# breakdex - Documentation

## 📱 Project Overview

**Purpose:** Comprehensive guide for the breakdex codebase architecture.

**breakdex** is an iOS 18.0 video flashcard application for breaking athletes. It combines video processing, spaced repetition, and intuitive UI to create an effective learning platform.

**Key Features (Updated Jan 2026):**
- **Video Import**: From Photos with 30s timeout guards and progress tracking
- **Video Editor**: Frame-accurate trimming, rotation (filling viewport), speed control (1.0x-2.0x), aspect ratio picker
- **Organization**: Moves (learning states: NEW/LEARNING/MASTERY) + Combos (sequences)
- **Review**: Spaced repetition system
- **Persistence**: Core Data with cloud sync support

**Architecture Status:** ✅ **Production Ready (Jan 2026)** - Clean MVVM architecture with robust error handling and simplified state management.

---

## 🏗️ Architecture Overview

### Core Technologies
- **SwiftUI** - UI Framework
- **Core Data** - Persistence
- **AVFoundation** - Video Processing
- **PhotosUI** - Asset Selection
- **Concurrency** - async/await with Task cancellation

### Architectural Patterns
- **Feature-Modular**: Code organized by feature (`Features/AddMove`, `Features/Arsenal`, etc.)
- **MVVM**: Strict separation of View and ViewModel
- **Services**: Shared logic in `Features/Shared/Services`
- **Dependency Injection**: `AppContainer` for service access

---

## 📁 Project Structure

```
BreakingFlashcards/
├── breakdex/
│   ├── App/                            # Entry points
│   │   ├── breakdex.swift              # App lifecycle
│   │   └── MainView.swift              # Tab coordinator
│   ├── CoreData/                       # Persistence
│   │   ├── Move+*.swift                # Video flashcard entity
│   │   ├── Combo+*.swift               # Sequence entity
│   │   └── ...
│   ├── Features/
│   │   ├── AddMove/                    # Import Workflow
│   │   │   ├── Views/ (SelectClip used here)
│   │   │   └── ViewModels/ (AddMoveViewModel)
│   │   ├── Arsenal/                    # Library Management
│   │   │   ├── Views/ (MoveList, MoveDetail, ComboList)
│   │   │   └── ViewModels/ (ArsenalViewModel)
│   │   ├── Combo/                      # Sequence Creation
│   │   │   └── Views/ (CreateCombo, Timeline)
│   │   ├── Review/                     # Learning System
│   │   │   └── Views/ (ReviewView)
│   │   └── Shared/                     # Reusable Code
│   │       ├── UI/ Components/ (FeedbackToast, BreadcrumbView)
│   │       ├── Video/ (MinimalTrimmerView, VideoPlayer)
│   │       ├── Services/ (RobustVideoLoader, PhotoKitService)
│   │       └── Utils/ (AsyncTimeout, TimecodeFormatter)
│   └── Resources/
└── _Archive/                           # Deprecated code
```

---

## 🔧 Key Components

### 1. Video Pipeline
- **RobustVideoLoader**: Handles video loading with 30s timeout guards and race condition prevention.
- **MinimalTrimmerView**: Editor with:
  - **Rotation**: Automatically scales to fill viewport (no black bars).
  - **Timeline**: Vertical end-cap handles for precision.
  - **Controls**: Playback speed (1.0x-2.0x) and aspect ratio (1:1, 9:16, etc.).
- **AsyncTimeout**: Utility for guarding async operations against hangs (e.g., iCloud downloads).

### 2. Feedback System
- **FeedbackToast**: Non-intrusive notifications for success/error.
- **ToastManager**: Singleton coordinating app-wide toasts.
- **Undo Support**: Delete operations show a toast with an "Undo" action (4.5s grace period).

### 3. State Management
- **AddMoveViewModel**: Manages the multi-step import flow (Select -> Trim -> Name -> Save).
- **ArsenalViewModel**: Handles library CRUD operations, including soft-delete with undo.
- **LoadingState**: Enum-based state machine for video loading (`idle` -> `loading` -> `ready` -> `failed`).

---

## 🛠️ Development Guidelines

### Code Quality
- **Crash Prevention**: Guard all async video operations with timeouts. Verify `AVPlayer` readiness before playback.
- **UI Feedback**: Every destructive action must have an undo. Every long operation must show progress.
- **Design System**: Use `DesignSystem.swift` tokens. Stick to B&W + Apple Blue.
- **Logging**: Use OSLog with category prefixes (e.g., `🎥 VIDEO`, `🏟️ ARSENAL`).

### Build & Test
```bash
# Build
xcodebuild -project breakdex.xcodeproj -scheme breakdex -destination 'platform=iOS Simulator,name=iPhone 16' build

# Test
xcodebuild test -project breakdex.xcodeproj -scheme breakdex -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## 🔄 Version History

### January 2026 (Refinement Phase)
- **Crash Prevention**: Added timeout guards to `RobustVideoLoader`.
- **UX Polish**: Added `FeedbackToast` system, delete-with-undo, and loading progress.
- **Video Editor**: Fixed rotation scaling, added speed control, aspect ratio picker, and technical timeline handles.
- **Navigation**: Wired breadcrumb navigation across the app.
- **Cleanup**: Archived legacy typography and test design files.

### October 2025 (Clean Architecture)
- Reorganized into Feature-based modifications.
- Implemented `MinimalTrimmerView` and `VideoLoadingService`.

---
*Maintained by s3nik. Last updated: Jan 2026.*