## Claude.md — BreakingFlashcards Video App (iOS 18.0)

# * **Single Responsibility Principle (SRP):** Enforce SRP across all components. Views remain "dumb," containing no business logic and forwarding all user actions to the ViewModel.

### Project Structure
- **Root Path:** `~/Desktop/dev playground/BreakingFlashcards/`
- **Main App:** `BreakingFlashcards/` (100+ Swift files)
- **Tests:** BreakingFlashcardsTests & BreakingFlashcardsUITests
- **Build System:** Xcode project with automated builds
- **Documentation**: Available at /Users/s3nik/Desktop/dev playground/BreakingFlashcards/BreakingFlashcards/DOCUMENTATION.md
- **Save Move Architecture**: Complete documentation in SAVE_MOVE_ARCHITECTURE.md

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
* **Save Move Testing:** Complete test coverage for the 12 core save move files and 8+ supporting files
* **Memory Management Testing:** Verification of retain cycle prevention and proper resource cleanup

### Testing & Compliance
* All new code must include companion unit tests (XCTest) for models and utilities, and UI tests (XCUITest) for video playback, flashcard navigation, and error states.
* The app must be fully functional and compliant with iOS 18.0 APIs.
* Verify builds using the command: `xcodebuild -project BreakingFlashcards.xcodeproj -scheme BreakingFlashcards -destination 'platform=iOS Simulator,name=iPhone 16' build`.
* Retain cycle prevention must be verified through Instruments profiling for all ViewModel lifecycle management.

### Feature Flags
* Use `FeatureFlag` enum for controlled feature rollout and A/B testing capabilities
* All new features should be gated behind feature flags for controlled deployment

### Syntax Validation & Code Quality
* **Pre-Commit Checks:** Always run `swiftc -parse` on modified files before committing
* **Build Verification:** Execute `xcodebuild -project BreakingFlashcards.xcodeproj -scheme BreakingFlashcards build` to verify compilation
* **Scope Management:** Use IDE code folding to verify struct/class/function boundaries - extra closing braces are a common source of "initializers may only be declared within a type" errors
* **Optional Safety:** Only use optional chaining (`?.`) on truly optional types; avoid unnecessary nil-coalescing (`??`) on non-optional values
* **Component Dependencies:** Ensure child components have access to required dependencies through proper property injection
* **Brace Matching:** Pay special attention to computed properties and complex view bodies to prevent premature struct/class termination

### Common Syntax Pitfalls to Avoid
1. **Extra Closing Braces:** Most common cause of "initializers may only be declared within a type" and "extraneous '}' at top level" errors
2. **Missing Function Closures:** Leads to "expressions are not allowed at the top level" errors
3. **Incorrect Optional Chaining:** Using `?.` on non-optional types generates unnecessary warnings
4. **Out-of-Scope References:** Accessing properties/methods not available in current context
5. **Async Function Boundaries:** Ensure proper async/await usage and MainActor isolation

### Retain Cycle Prevention Best Practices
* **Deterministic Teardown:** All ViewModels with long-running tasks must implement comprehensive teardown() methods
* **Task Management:** Explicitly cancel all Task properties in teardown, not just deinit
* **Combine Cleanup:** Remove all cancellables and invalidate observers during teardown
* **Self Reference Management:** Use explicit `self.` in closures when required by capture semantics
* **Logging Requirements:** Include comprehensive diagnostic logging in all cleanup operations
* **Verification:** Test teardown methods with unit tests and verify with Instruments profiling

### Save Move Architecture Guidelines
* **Core Files:** The save move functionality spans 12 core files with 8+ supporting infrastructure files
* **State Management:** Use AddMoveUnifiedState as the single source of truth for save operations
* **Error Handling:** Implement comprehensive error handling throughout the 8-step save pipeline
* **Core Data Integration:** Follow the established pattern in MovePersistenceService for entity creation
* **Video Processing:** Use VideoProcessingPipeline for all video export and processing operations
* **Memory Management:** Ensure proper cleanup of video assets and processing resources

### Error Resolution Protocol
When encountering compilation errors:
1. **Start with the first error** - subsequent errors may be cascading
2. **Check scope boundaries** using IDE tools or manual brace counting
3. **Validate dependency injection** for component communication
4. **Review type annotations** for optional vs non-optional usage
5. **Test incrementally** - fix one error, recompile, repeat

### Build Verification Commands
```bash
# Syntax validation for single file
swiftc -parse BreakingFlashcards/Views/Video/Trim/FeatureRichTrimmerView.swift

# Full project build
xcodebuild -project BreakingFlashcards.xcodeproj -scheme BreakingFlashcards -destination 'platform=iOS Simulator,name=iPhone 16' build

# Clean build verification
xcodebuild clean -project BreakingFlashcards.xcodeproj
xcodebuild -project BreakingFlashcards.xcodeproj -scheme BreakingFlashcards -destination 'platform=iOS Simulator,name=iPhone 16' build
```