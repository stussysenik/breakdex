## Claude.md — BreakingFlashcards Video App (iOS 18.0)

### Project Structure
- **Root Path:** `~/Desktop/dev playground/BreakingFlashcards/`
- **Main App:** `BreakingFlashcards/` (100+ Swift files)
- **Tests:** BreakingFlashcardsTests & BreakingFlashcardsUITests
- **Build System:** Xcode project with automated builds
- **Documentation**: Available at /Users/s3nik/Desktop/dev playground/BreakingFlashcards/BreakingFlashcards/DOCUMENTATION.md

### Development Guidelines
- **WYSIWYG:** What you see is what you get - maintain the current codebase structure
- **Diagnostic Logging:** Use comprehensive logging at every step for debugging
- **Code Quality:** Write performant, maintainable, scalable code that's easy to debug
- **Principles:** Follow KISS, DRY, and YAGNI development principles
- **File Creation:** Always ask permission before creating new files to avoid "unknown project Target issues"

### Design style
DesignSystem.swift or Color+Extensions.swift

### Maximum lines of code per file
approx. 500 lines if exceeded - means we're not following SRP principle

### App Purpose
Develop a high-performance, iOS 18.0-compliant video flashcard application for learning and reviewing complex physical movements. The project is built on a foundation of robust state management, Swift Concurrency, and a stable, custom video playback engine.

### Core Architectural Principles
* **SwiftUI & State Flow:** Employ a strict unidirectional data flow for all UI. The `AddMoveState` enum serves as the single source of truth, with a state-driven ViewRouter (`AddMoveContainer`) managing view switching.
* **Single Responsibility Principle (SRP):** Enforce SRP across all components. Views remain "dumb," containing no business logic and forwarding all user actions to the ViewModel.

### Logging & Debugging
* **Logging-First Approach:** Adopt a logging-first approach using `OSLog` for detailed, categorized, and traceable logging. Use emojis in log categories for enhanced traceability.
* **Critical Operations:** Log every critical state transition, function entry/exit, and asynchronous boundary to aid in debugging.

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

### Testing & Compliance
* All new code must include companion unit tests (XCTest) for models and utilities, and UI tests (XCUITest) for video playback, flashcard navigation, and error states.
* The app must be fully functional and compliant with iOS 18.0 APIs.
* Verify builds using the command: `xcodebuild -project BreakingFlashcards.xcodeproj -scheme BreakingFlashcards -destination 'platform=iOS Simulator,name=iPhone 16' build`.

### Feature Flags
* Use `FeatureFlag` enum for controlled feature rollout and A/B testing capabilities
* All new features should be gated behind feature flags for controlled deployment