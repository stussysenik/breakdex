# breakdex

> **Video knowledge management for breakdancing athletes.**
> *Make it good. Make it last.* — CW&T

---

## 🎯 What Is This?

**breakdex** is an iOS 18 app for breaking (breakdancing) athletes who want to:

1. **Capture** moves from practice videos
2. **Trim** to the good part with frame-accurate controls
3. **Organize** by learning state: NEW → LEARNING → MASTERY
4. **Review** before sessions using spaced repetition
5. **Combine** moves into combos (sequences)

Think of it as a **video flashcard app for physical movements**.

---

## 🚀 Current Status (January 2026)

| Feature | Status |
|---------|--------|
| Video import from Photos | ✅ Complete |
| Frame-accurate trimming | ✅ Complete |
| Video rotation (fills viewport) | ✅ Complete |
| Speed control (1x–2x) | ✅ Complete |
| Aspect ratio picker | ✅ Complete |
| CRUD feedback (toasts) | ✅ Complete |
| Delete with undo | ✅ Complete |
| Crash prevention (timeout guards) | ✅ Complete |
| Spaced repetition review | 🔄 In Progress |
| Import/export for backup | 🔮 Planned |

---

## 📂 Codebase Navigation

```
breakdex/
├── App/                    # Entry point
│   ├── breakdex.swift      # @main, Core Data setup
│   └── MainView.swift      # 4-tab navigation
│
├── CoreData/               # Persistence
│   ├── Move+*.swift        # Move entity (video, trim, speed, aspect)
│   ├── Combo+*.swift       # Combo entity (sequence)
│   ├── ComboMove+*.swift   # Join table
│   └── Persistence.swift   # Core Data stack
│
├── Features/
│   ├── AddMove/            # Video import flow
│   │   ├── Views/
│   │   │   ├── SelectClip.swift     # PhotosPicker + loading progress
│   │   │   └── NameMoveView.swift   # Name + save
│   │   └── ViewModels/
│   │       └── AddMoveViewModel.swift
│   │
│   ├── Arsenal/            # Move/combo library
│   │   ├── Views/
│   │   │   ├── MoveListView.swift
│   │   │   ├── MoveDetailView.swift  # Edit button → trimmer
│   │   │   └── ComboListView.swift
│   │   └── ViewModels/
│   │       └── ArsenalViewModel.swift  # Delete with undo
│   │
│   ├── Combo/              # Combo creation
│   │   └── Views/
│   │       ├── CreateComboView.swift
│   │       └── ComboTimelineView.swift
│   │
│   └── Shared/             # Reusable components
│       ├── Video/
│       │   ├── MinimalTrimmerView.swift  # Trimmer + speed + aspect
│       │   └── VideoPlayer.swift
│       ├── UI/Components/
│       │   ├── FeedbackToast.swift      # Toast notifications
│       │   └── BreadcrumbView.swift     # Navigation path
│       ├── Services/
│       │   ├── RobustVideoLoader.swift  # 30s timeout guards
│       │   └── PhotoKitService.swift
│       ├── Utils/
│       │   └── AsyncTimeout.swift       # Timeout wrapper
│       └── Models/
│           └── LoadingState.swift       # State machine
```

---

## 🎨 Design Philosophy

Following **CW&T** principles:

| Principle | Implementation |
|-----------|----------------|
| **Legibility** | User always knows what's happening |
| **Transparency** | Show progress %, what failed, why |
| **Longevity** | Guard every async boundary |
| **Thoughtful Subtraction** | Remove anything that doesn't serve the athlete |

### Visual Language
- **Colors**: Pure B&W + Apple Blue (#007AFF) accent only
- **Typography**: IBM Plex Mono — monospace = precision
- **Spacing**: 8pt grid, no decorative negative space
- **Feedback**: Every action has visible confirmation (toast)

---

## 🛠️ Development

### Build
```bash
xcodebuild -project breakdex.xcodeproj -scheme breakdex \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### Requirements
- Xcode 16.0+
- iOS 18.0 SDK
- macOS 14.0+

---

## 📖 More Documentation

- [DOCUMENTATION.md](./DOCUMENTATION.md) — Detailed architecture, services, state management
- [extra/markdown/CLAUDE.md](../extra/markdown/CLAUDE.md) — AI development guidelines

---

## 📋 Recent Changes (January-March 2026)

### Crash Prevention
- 30-second timeout guards on video loading
- Simplified async callbacks in Photos requests

### CRUD Feedback
- `FeedbackToast` component for success/error/info
- Delete with undo (4.5s grace period)
- Toast on move save

### Video Editor
- Rotation fills viewport (no black bars)
- Speed control: 1.0x, 1.25x, 1.5x, 2.0x
- Aspect ratio: Original, 1:1, 9:16, 16:9, 4:3
- Technical timeline handles (vertical bars)

### Core Data
- Added `playbackSpeed` and `aspectRatioMode` to Move entity

### SwiftUI Preview Coverage (March 1, 2026)
- Added missing SwiftUI previews to frontend files so Canvas can be opened quickly during theme checks:
  - `Features/Arsenal/Views/BreakingArsenalView.swift`
  - `Features/Shared/UI/Components/SharedButton.swift`
  - `Features/Shared/Services/ThermalGuard.swift`
  - `Features/Shared/Video/AVPlayerViewRepresentable.swift`
  - `Features/Shared/Video/VideoPlayer.swift`
- Verified project build after preview additions.

---

## 🤝 Who Made This?

A solo project for personal breakdance training. Built to never forget moves and progressions.

---

**Build Status**: ✅ BUILD SUCCEEDED
