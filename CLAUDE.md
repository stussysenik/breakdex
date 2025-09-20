## Claude.md — BreakingFlashcards Video App (iOS 18.0)

### what you see is what you get

### Project Structure
- **Root Path:** `~/Desktop/dev playground/BreakingFlashcards/`
- **Main App:** `BreakingFlashcards/` (100+ Swift files)
- **Tests:** BreakingFlashcardsTests & BreakingFlashcardsUITests
- **Build System:** Xcode project with automated builds

### make sure to make use of diagnostic logging at every step

### Make sure to write performant, maintainable, scalable code that's easy to debug!

### Follow KISS, DRY and YAGNI development principles

### Make sure to always ask me first to create a new file, in order to avoid "unknown project Target issues". If it's created via terminal, we may bump to this kind of error.

### Design style
DesignSystem.swift or Color+Extensions.swift

### Maximum lines of code per file
approx. 500 lines if exceeded - means we're not following SRP principle

### App Purpose
Develop a high-performance, iOS 18.0-compliant video flashcard application for learning and reviewing complex physical movements. The project is built on a foundation of robust state management, Swift Concurrency, and a stable, custom video playback engine.

### Core Architectural Principles
* **SwiftUI & State Flow:** Employ a strict unidirectional data flow for all UI. The `AddMoveState` enum serves as the single source of truth, with a state-driven ViewRouter (`AddMoveContainer`) managing view switching.
* **Single Responsibility Principle (SRP):** Enforce SRP across all components. Views remain "dumb," containing no business logic and forwarding all user actions to the ViewModel.
* **Dependency Injection (DI):** Utilize the singleton `AppContainer` for centralized dependency injection of all major services (e.g., `MemoryManager`, `VideoProcessingPipeline`, `AppLogger`).
* **Concurrency:**
    * Enforce strict concurrency with `async/await` for all asynchronous operations.
    * Isolate all mutable UI state and ViewModels with `@MainActor` to guarantee UI safety.
    * Use `actors` for thread-safe access to shared resources where appropriate (e.g., `VideoLoader`).

### Manager Architecture
* **State Management:** `AddMoveStateManager` manages complex state transitions for the add move flow
* **Video Management:** Multiple specialized managers for video operations:
  - `VideoPlayerManager`: Core video playback logic
  - `VideoPlayerCacheManager`: Video asset caching and memory management
  - `AddMovePlayerManager`: Specialized player for add move workflow
  - `VideoRelinkManager`: Handles video asset re-linking when files are moved/renamed
* **Album Management:** 
  - `BreakDexAlbumManager`: Core album operations and data management
  - `AlbumSyncManager`: Synchronization between local and remote album data
  - `PhotosPermissionManager`: Handles photo library permissions and access
* **Processing Managers:**
  - `VideoStateManager`: Centralized video state management
  - `MemoryManager`: Memory monitoring and optimization
  - `VideoHealthMonitor`: Video file health checking and validation
  - `ContinuationManager`: Handles async continuations and state restoration

### Video Handling & Playback
* **Custom Player Engine:** Use the custom `CustomVideoPlayerView`, which is built on a `UIViewRepresentable` wrapper around `AVPlayerLayer`, for all video playback. This is mandated to ensure stability and avoid native SwiftUI `VideoPlayer` limitations.
* **Video Transformations:** Handle all video transformations (trimming, rotation) non-destructively using the `VideoTransformBuilder` utility. This abstracts AVFoundation complexities and ensures predictable outcomes.
* **Video Ingestion:** Leverage the dedicated `VideoProcessingPipeline` for robust, state-managed ingestion of new video assets, which includes proactive memory checks and error handling.
* **Permissions:** Gracefully handle `PhotosPicker` results and all `PHPhotoLibrary` permissions and potential errors.
* **Video State Management:** Comprehensive state management through `VideoState` enum and associated managers for tracking video processing, playback, and health status.

### Logging & Debugging
* **Logging-First Approach:** Adopt a logging-first approach using `OSLog` for detailed, categorized, and traceable logging. Use emojis in log categories for enhanced traceability.
* **Critical Operations:** Log every critical state transition, function entry/exit, and asynchronous boundary to aid in debugging.
* **Enhanced Logging:** `EnhancedVideoLogger` provides specialized logging for video operations with detailed metadata.

### Claude Code Integration
* Claude agent should be limited to generating/refactoring Swift or SwiftUI code, with explicit permission required for data or asset directories.
* Request permission before altering Core Data models, `Info.plist`, or App Sandbox settings.
* Generate thorough comments for any code affecting app performance, privacy, or video playback edge cases.

### Logging
- The AppLogger protocol requires a metadata parameter
- Never delete logs unless, we're discarding the entire file/functionality.
- Be super cautious about when we need explicit self. references

### Testing Strategy
* **Unit Tests:** Comprehensive test coverage for all managers, view models, and utility functions
* **UI Tests:** Automated UI testing for critical user flows including video playback, trimmer operations, and add move workflow
* **Test Files:** 
  - `AddMoveFlowTests.swift`: Add move workflow testing
  - `TrimmerViewModelTests.swift`: Video trimmer functionality testing
  - `AddMoveFlowUITests.swift`: UI automation for add move flow

### Testing & Compliance
* All new code must include companion unit tests (XCTest) for models and utilities, and UI tests (XCUITest) for video playback, flashcard navigation, and error states.
* The app must be fully functional and compliant with iOS 18.0 APIs.
* Verify builds using the command: `xcodebuild -project BreakingFlashcards.xcodeproj -scheme BreakingFlashcards -destination 'platform=iOS Simulator,name=iPhone 16' build`.

### Feature Flags
* Use `FeatureFlag` enum for controlled feature rollout and A/B testing capabilities
* All new features should be gated behind feature flags for controlled deployment