# Breakdex Documentation

Comprehensive technical documentation for the Breakdex iOS application.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Core Features](#core-features)
3. [System Components](#system-components)
4. [UI Components](#ui-components)
5. [Video Components](#video-components)
6. [Services](#services)
7. [Data Models](#data-models)
8. [Version History](#version-history)

---

## Architecture Overview

Breakdex follows a **feature-based MVVM architecture** with shared components:

```
┌─────────────────────────────────────────────────────────┐
│                     App Layer                            │
│  ┌─────────────────────────────────────────────────┐    │
│  │   MainView (Tab Navigation)                      │    │
│  │   ┌─────┬─────┬─────┬─────┬─────┐              │    │
│  │   │Arena│ Add │Combo│Review│Camera│              │    │
│  │   └─────┴─────┴─────┴─────┴─────┘              │    │
│  └─────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────┤
│                   Feature Modules                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │ Arsenal  │ │ AddMove  │ │  Review  │ │  Camera  │  │
│  │ ────────│ │ ────────│ │ ────────│ │ ────────│  │
│  │ ViewModel│ │ViewModel│ │ViewModel│ │ViewModel│  │
│  │ Views    │ │ Views   │ │ Views   │ │ Views   │  │
│  │ Services │ │ Services│ │ Models  │ │         │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘  │
├─────────────────────────────────────────────────────────┤
│                   Shared Layer                           │
│  ┌────────────────┐ ┌────────────────┐ ┌─────────────┐ │
│  │ AccessibilityMgr│ │  MotionSystem  │ │ ThermalGuard│ │
│  └────────────────┘ └────────────────┘ └─────────────┘ │
│  ┌────────────────┐ ┌────────────────┐ ┌─────────────┐ │
│  │ UI Components  │ │Video Components│ │   Services  │ │
│  └────────────────┘ └────────────────┘ └─────────────┘ │
├─────────────────────────────────────────────────────────┤
│                   Data Layer                             │
│  ┌─────────────────────────────────────────────────┐    │
│  │              CoreData (Move, Combo, Review)      │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

---

## Core Features

### Move Arsenal

The main library view for browsing and managing moves.

**Key Files:**
- `ArsenalViewModel.swift` - Fetches and filters moves from CoreData
- `MoveDetailView.swift` - Full move view with video playback
- `VideoThumbnailCard.swift` - Thumbnail card with async loading

### Add Move

Flow for importing videos from Photos library and creating moves.

**Key Files:**
- `AddMoveViewModel.swift` - Coordinates video selection and saving
- `AddMoveView.swift` - Video picker and trimmer interface
- `NameMoveView.swift` - Move naming and tagging
- `VideoProcessor.swift` - Video processing utilities
- `MovePersistenceService.swift` - CoreData persistence

### Camera Capture

Native camera recording for capturing moves directly in the app.

**Key Files:**
- `CameraViewModel.swift` - Camera session management
- `CameraView.swift` - Recording UI with controls

**Features:**
- Front/back camera switching
- Flash toggle
- Real-time duration display
- Video preview before saving
- Direct integration with Add Move flow via `Notification.Name.didRecordVideo`

### Flashcard Review System

Spaced repetition system for practicing moves using the SM-2 algorithm.

**Key Files:**
- `SpacedRepetition.swift` - SM-2 algorithm implementation
- `LearningProgress.swift` - Progress tracking models
- `FlashcardReviewViewModel.swift` - Review session management
- `FlashcardReviewView.swift` - Card flip interface
- `FlashcardCardView.swift` - Individual flashcard view
- `RatingButtonsView.swift` - Rating buttons (Again/Hard/Good/Easy)

#### SM-2 Algorithm Details

The SuperMemo SM-2 algorithm calculates optimal review intervals:

```swift
// Rating levels
enum RecallRating {
    case again  // Quality 0 - Complete blackout, restart
    case hard   // Quality 2 - Significant difficulty
    case good   // Quality 3 - Correct with hesitation
    case easy   // Quality 5 - Perfect recall
}

// Interval calculation
- First success: 1 day
- Second success: 6 days
- Subsequent: interval * easeFactor

// Ease factor adjustment
easeFactor = max(1.3, easeFactor + 0.1 - (5-q) * (0.08 + (5-q) * 0.02))

// Bonuses
- Easy: +50% interval
- Hard: -20% interval
```

**Learning Phases:**
| Phase | Criteria |
|-------|----------|
| NEW | Never reviewed |
| LEARNING | Interval < 1 day |
| REVIEW | Regular spaced repetition |
| MASTERY | Ease > 2.7 AND interval > 30 days |

**Session Statistics:**
- Total cards reviewed
- Accuracy percentage
- Session duration
- Average time per card

### Combo Builder

Create and manage move combinations (combos).

**Key Files:**
- `ComboViewModel.swift` - Combo creation and playback
- `CreateComboView.swift` - Combo assembly interface
- `ComboTimelineView.swift` - Visual timeline of moves
- `ComboDetailView.swift` - Full combo view
- `ComboNamingSheet.swift` - Naming modal

### Settings

App preferences and data management.

**Key Files:**
- `SettingsViewModel.swift` - Settings state management
- `SettingsView.swift` - Settings UI

**Sections:**
- **Accessibility**: Large touch targets, high contrast, reduce motion
- **Data Management**: Cache size display, clear cache, reset to defaults
- **About**: Version info and app description

---

## System Components

### AccessibilityManager

Central manager for accessibility settings, supporting WCAG 2.2 AA compliance.

**Location:** `Features/Shared/Accessibility/AccessibilityManager.swift`

```swift
@MainActor
final class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()

    // User preferences (persisted)
    @AppStorage("largeTouchTargets") var largeTouchTargets = false
    @AppStorage("highContrastMode") var highContrastMode = false
    @AppStorage("slowerAnimations") var slowerAnimations = false
    @AppStorage("enhancedHaptics") var enhancedHaptics = true

    // Computed properties
    var touchTargetSize: CGFloat  // 44pt standard, 56pt accessible
    var effectiveAnimation: Animation
    var isReduceMotionEnabled: Bool
    var isVoiceOverRunning: Bool
}
```

**Features:**
- Larger touch targets (56pt minimum for 65+ users)
- High contrast mode
- Slower animations option
- VoiceOver announcements
- Haptic feedback management

**View Modifiers:**
```swift
.accessibleTouchTarget()      // Apply min touch target size
.accessibleHighContrast()     // Apply high contrast styling
.accessibilityDescribed(label:hint:)  // Add accessibility info
```

### MotionSystem

Animation system providing buttery smooth 60fps animations with accessibility fallbacks.

**Location:** `Features/Shared/Motion/MotionSystem.swift`

```swift
struct MotionSystem {
    // Spring presets
    static let primary = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let secondary = Animation.spring(response: 0.5, dampingFraction: 0.75)
    static let micro = Animation.spring(response: 0.25, dampingFraction: 0.9)
    static let gentle = Animation.spring(response: 0.6, dampingFraction: 0.7)
    static let snappy = Animation.spring(response: 0.2, dampingFraction: 0.95)
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)

    // Interactive springs for gestures
    static let interactive = Animation.interactiveSpring(...)
    static let fluid = Animation.interactiveSpring(...)

    // Accessibility-aware animation
    static func animation(_ base: Animation) -> Animation
}
```

**Usage Guidelines:**
| Animation | Use Case |
|-----------|----------|
| `primary` | Cards, navigation, modals |
| `secondary` | State changes, toggles |
| `micro` | Button presses, micro-interactions |
| `gentle` | Accessibility mode |
| `snappy` | Haptic-paired actions |
| `bouncy` | Success states, achievements |

**Golden Ratio System:**
```swift
struct GoldenRatio {
    static let phi: CGFloat = 1.618033988749895
    static let inverse: CGFloat = 0.618033988749895

    static func major(of total: CGFloat) -> CGFloat  // 61.8%
    static func minor(of total: CGFloat) -> CGFloat  // 38.2%
}
```

### ThermalGuard

Device thermal state monitoring that adjusts video quality to prevent throttling.

**Location:** `Features/Shared/Services/ThermalGuard.swift`

```swift
@MainActor
final class ThermalGuard: ObservableObject {
    static let shared = ThermalGuard()

    @Published var currentState: ProcessInfo.ThermalState
    @Published var qualityLevel: QualityLevel
    @Published var shouldReduceWork: Bool
}
```

**Quality Levels:**

| Level | Thermal State | Video Resolution | Frame Rate | Concurrent Ops |
|-------|---------------|------------------|------------|----------------|
| Full | Nominal | 1920x1080 | 60fps | 4 |
| Reduced | Fair | 1280x720 | 30fps | 3 |
| Minimal | Serious | 854x480 | 24fps | 2 |
| Emergency | Critical | 640x360 | 15fps | 1 |

**Usage:**
```swift
// Check before intensive operations
if ThermalGuard.shared.shouldAllowIntensiveOperation() {
    // Proceed with operation
}

// Get recommended export settings
let preset = ThermalGuard.shared.recommendedExportPreset()

// Execute with thermal consideration
try await ThermalGuard.shared.executeWithThermalGuard {
    // Work that may need throttling
}
```

---

## UI Components

### CardContainer
Generic container with rounded corners and shadow.

### EmptyStateView
Placeholder view for empty states with icon, title, and description.

### ProgressRingView
Circular progress indicator.

### SectionHeaderView
Consistent section headers with title and optional action button.

### TagChipView
Individual tag chip with optional delete action.

### TagFlowLayout
Flowing layout for multiple tags that wraps to new lines.

### TagInputField
Text field for entering and managing tags with suggestions.

### StatePillView
Small pill indicating learning state (NEW, LEARNING, REVIEW, MASTERY).

### FeedbackToast
Temporary toast notification for user feedback.

### BreadcrumbView
Navigation breadcrumb trail.

### LoadingView
Full-screen loading indicator.

---

## Video Components

### VideoPlayer (SharedVideoPlayer)
Core video playback component using AVPlayer.

### LiquidScrubber

Variable-speed scrubbing system where vertical distance controls precision.

**Location:** `Features/Shared/Video/LiquidScrubber.swift`

```swift
struct LiquidScrubberConfig {
    let maxVerticalDistance: CGFloat = 200
    let minScrubRatio: Double = 0.01    // Finest control
    let normalScrubRatio: Double = 1.0   // Normal speed
    var frameRate: Double = 30.0
    var hapticsEnabled: Bool = true
}
```

**How it works:**
- Drag horizontally to scrub through video
- Move finger up/down (away from timeline) for finer precision
- Haptic feedback at frame boundaries
- Snaps to nearest frame on release

**Precision levels:**
| Scrub Ratio | Label | Use Case |
|-------------|-------|----------|
| > 0.5 | Normal | Quick seeking |
| 0.1 - 0.5 | Fine | Accurate positioning |
| < 0.1 | Frame | Frame-by-frame control |

### ThumbnailGenerator

Efficient video thumbnail generator with caching.

**Location:** `Features/Shared/Video/ThumbnailGenerator.swift`

```swift
@MainActor
final class ThumbnailGenerator: ObservableObject {
    static let shared = ThumbnailGenerator()

    // Generate single thumbnail
    func thumbnail(for photosIdentifier: String, at time: Double, size: CGSize) async -> UIImage?

    // Preload for smooth scrolling
    func preloadThumbnails(for moves: [Move], size: CGSize) async

    // Generate timeline strip
    func timelineStrip(for photosIdentifier: String, count: Int, startTime: Double, endTime: Double, size: CGSize) async -> [UIImage]

    // Cache management
    func clearCache()
    func isCached(identifier: String, time: Double, size: CGSize) -> Bool
}
```

**SwiftUI Integration:**
```swift
AsyncThumbnailView(photosIdentifier: "...", time: 0)
// or
AsyncThumbnailView(move: move)
```

### MinimalTrimmerView
Video trimming interface with start/end handles.

### AVPlayerViewRepresentable
UIViewRepresentable wrapper for AVPlayerLayer.

---

## Services

### PhotoKitService / PhotosAssetLoader
Photo library integration for fetching videos.

### RobustVideoLoader
Reliable video loading with retry logic.

### VideoSaver
Saves processed videos to the app sandbox.

### ThemeManager
Color scheme management.

### AppContainer
Dependency injection container.

### PersistenceBridge
Bridge between SwiftUI and CoreData.

---

## Data Models

### Move (CoreData)
```swift
@objc(Move)
public class Move: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var category: String?
    @NSManaged public var tags: Data?           // Encoded [String]
    @NSManaged public var photosIdentifier: String?
    @NSManaged public var trimStartTime: Double
    @NSManaged public var trimEndTime: Double
    @NSManaged public var dateAdded: Date?
    @NSManaged public var lastPracticed: Date?
    @NSManaged public var learningState: String?  // NEW, LEARNING, REVIEW, MASTERY
    @NSManaged public var repetitionData: Data?   // SpacedRepetitionState
    // Relationships
    @NSManaged public var reviews: NSSet?
    @NSManaged public var comboMoves: NSSet?
}
```

### Combo (CoreData)
```swift
@objc(Combo)
public class Combo: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var dateCreated: Date?
    // Relationships
    @NSManaged public var moves: NSOrderedSet?  // ComboMove
}
```

### ComboMove (CoreData)
Junction table for combo-move relationships with ordering.

### Review (CoreData)
Records individual review sessions.

---

## Version History

### January 2026 (Current)

**New Features:**
- Flashcard Review System with SM-2 spaced repetition algorithm
- Camera Capture for recording moves directly
- Settings View for accessibility and data management

**System Improvements:**
- AccessibilityManager for WCAG 2.2 AA compliance
- MotionSystem for consistent, accessible animations
- ThermalGuard for device temperature monitoring

**Video Enhancements:**
- LiquidScrubber for precision video scrubbing
- ThumbnailGenerator with caching and preloading

**UI Components:**
- CardContainer, EmptyStateView, ProgressRingView
- SectionHeaderView, TagChipView, TagFlowLayout, TagInputField
- VideoThumbnailCard

---

## Related Documentation

- [README.md](./README.md) - Quick start guide
- [PROGRESS.md](./PROGRESS.md) - Development timeline and roadmap
