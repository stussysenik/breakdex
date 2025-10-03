## Claude.md — BreakingFlashcards Video App (iOS 18.0)

# * **Single Responsibility Principle (SRP):** Enforce SRP across all components. Views remain "dumb," containing no business logic and forwarding all user actions to the ViewModel.

### Project Structure
- **Root Path:** `~/Desktop/dev playground/BreakingFlashcards/`
- **Main App:** `BreakingFlashcards/` (100+ Swift files)
- **Tests:** BreakingFlashcardsTests & BreakingFlashcardsUITests
- **Build System:** Xcode project with automated builds
- **Documentation**: Available at /Users/s3nik/Desktop/dev playground/BreakingFlashcards/BreakingFlashcards/DOCUMENTATION.md
- **Save Move Architecture**: Complete documentation in SAVE_MOVE_ARCHITECTURE.md

### 🚀 Recent Refactoring (September 2025)
**Major AddMoveUnifiedState Refactoring**: Successfully reduced the 3,349-line monolithic file by 93% through systematic component extraction:
- **AddMoveUnifiedState.swift**: 227 lines (was 3,349 lines)
- **New Components**: TimerManager, ProgressMonitor, StateValidator, SaveOperationCoordinator
- **Type Safety**: Fixed ambiguous type annotation errors through separation of concerns
- **Maintainability**: All files now comply with 500-line SRP limit

### Development Guidelines
- **WYSIWYG:** What you see is what you get - maintain the current codebase structure
- **Diagnostic Logging:** Use comprehensive logging at every step for debugging
- **Code Quality:** Write performant, maintainable, scalable code that's easy to debug
- **Principles:** Follow KISS, DRY, and YAGNI development principles
- **File Creation:** Always ask permission before creating new files to avoid "unknown project Target issues"

### Code Formatting Configuration

The project uses Prettier for consistent code formatting with the following configuration in `.prettierrc`:

```json
{
  "tabWidth": 2,
  "useTabs": false,
  "printWidth": 80,
  "trailingComma": "es5",
  "semi": true,
  "singleQuote": false,
  "bracketSpacing": true,
  "bracketSameLine": false,
  "arrowParens": "always",
  "endOfLine": "lf",
  "quoteProps": "as-needed",
  "jsxSingleQuote": false,
  "proseWrap": "preserve",
  "htmlWhitespaceSensitivity": "css",
  "embeddedLanguageFormatting": "auto"
}
```

**Markdown Support:** The `.prettierrc` configuration includes `proseWrap: "preserve"` and `embeddedLanguageFormatting: "auto"` to ensure proper formatting of markdown files while preserving code blocks and embedded syntax highlighting.

### Design style
DesignSystem.swift or Color+Extensions.swift

### Maximum lines of code per file
approx. 500 lines if exceeded - means we're not following SRP principle

### App Purpose
Develop a high-performance, iOS 18.0-compliant video flashcard application for learning and reviewing complex physical movements. The project is built on a foundation of robust state management, Swift Concurrency, and a stable, custom video playback engine with millisecond-precise video trimming capabilities.

### Core Architectural Principles
* **SwiftUI & State Flow:** Employ a strict unidirectional data flow for all UI. The `AddMoveFlowState` enum serves as the single source of truth, with a state-driven ViewRouter (`AddMoveContainer`) managing view switching.
* **Millisecond Precision:** All video trimming operations maintain frame-accurate precision through the TimecodeCalculationService, ensuring WYSIWYG video editing from preview to final asset.
* **Component-Based Architecture:** The AddMoveUnifiedState now coordinates through specialized services (TimerManager, ProgressMonitor, StateValidator, SaveOperationCoordinator) with comprehensive error handling and state validation.

### 🏗️ AddMove Component Architecture
```
Views/Arsenal/AddMove/
├── AddMoveUnifiedState.swift (227 lines) - Main coordinator
├── State/
│   ├── AddMoveFlowState.swift (162 lines) - Simplified 5-stage state enum
│   └── SimpleProgress struct - Progress tracking
├── Services/
│   ├── TimerManager.swift (114 lines) - Timer operations
│   ├── ProgressMonitor.swift (166 lines) - Progress tracking
│   └── FlowStateManager.swift (352 lines) - 5-stage flow management
├── Validation/
│   ├── AddMoveValidationTypes.swift (254 lines) - Validation types
│   └── StateValidator.swift (372 lines) - Validation logic
└── Operations/
    └── SaveOperationCoordinator.swift (310 lines) - Save operations
```

### 🔄 Simplified 5-Stage State Machine
The AddMove flow now uses a simplified 5-stage state machine following KISS principles:
1. **loadingVideo** - Loads video from Photos library with progress tracking
2. **trimming** - Direct transition to trimmer UI (no preview stage)
3. **loadingTrimmedAsset** - Prepares trimmed asset for naming with progress
4. **naming** - User names the move (NameMoveView)
5. **saving** - Saves the move to Core Data

**Terminal States**: `ready`, `success`, `error`

This eliminates the complex `previewing` and `trimming_setup` states that caused 99% stuck issues.

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

### Video Precision Architecture
* **TimecodeCalculationService:** Centralized service for all timecode calculations, validation, and frame-accurate operations
* **Millisecond Precision:** End-to-end ms precision from trimmer UI to final video asset processing
* **Frame-Accurate Snapping:** All time conversions use frame-based calculations for precise video editing
* **Unified Time Formatting:** Consistent ms-precise time display across all UI components
* **Comprehensive Validation:** Timecode range validation with detailed error reporting and minimum duration enforcement

### Key Services and Managers
* **PhotosAssetLoader:** Async service for loading video assets from Photos library with proper authorization handling
* **TimecodeCalculationService:** Provides frame-accurate timecode calculations, validation, and formatting
* **VideoProcessingPipeline:** Handles video export, trimming, and transformation operations
* **DiagnosticLoggingHelper:** Comprehensive logging with memory tracking and performance monitoring
* **TimecodeFormatter:** Utility for consistent ms-precise time string formatting across the application

### Error Resolution Protocol
When encountering compilation errors:
1. **Start with the first error** - subsequent errors may be cascading
2. **Check scope boundaries** using IDE tools or manual brace counting
3. **Validate dependency injection** for component communication
4. **Review type annotations** for optional vs non-optional usage
5. **Test incrementally** - fix one error, recompile, repeat

### Build Verification Commands
```bash
# Syntax validation for main refactored file
swiftc -parse BreakingFlashcards/Views/Arsenal/AddMove/AddMoveUnifiedState.swift

# Syntax validation for extracted components
swiftc -parse BreakingFlashcards/Views/Arsenal/AddMove/State/AddMoveFlowState.swift
swiftc -parse BreakingFlashcards/Views/Arsenal/AddMove/Services/TimerManager.swift
swiftc -parse BreakingFlashcards/Views/Arsenal/AddMove/Services/ProgressMonitor.swift
swiftc -parse BreakingFlashcards/Views/Arsenal/AddMove/Validation/StateValidator.swift
swiftc -parse BreakingFlashcards/Views/Arsenal/AddMove/Operations/SaveOperationCoordinator.swift

# Full project build
xcodebuild -project BreakingFlashcards.xcodeproj -scheme BreakingFlashcards -destination 'platform=iOS Simulator,name=iPhone 16' build

# Clean build verification
xcodebuild clean -project BreakingFlashcards.xcodeproj
xcodebuild -project BreakingFlashcards.xcodeproj -scheme BreakingFlashcards -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build with specific simulator (useful when multiple simulators available)
xcodebuild -project BreakingFlashcards.xcodeproj -scheme BreakingFlashcards -destination 'platform=iOS Simulator,id=86FFC075-5BA3-4125-9534-C9F8B525E72A' build
```

### Recent Improvements (September 2025)
* **🔄 State Machine Simplification (September 30, 2025):** Simplified the complex state machine to fix 99% stuck issues:
  - **5-Stage Flow**: Eliminated `previewing` and `trimming_setup` states, implemented direct flow: loadingVideo → trimming → loadingTrimmedAsset → naming → saving
  - **99% Bug Fix**: Fixed the core issue where video loading got stuck at `validatingTrimmer` (99%) by using proper completion criteria (1.0 instead of 0.99)
  - **KISS Principles**: Removed complex natural transformation logic causing race conditions
  - **FlowStateManager**: Added dedicated flow management service with proper closure capture semantics
  - **Progress Tracking**: Simplified with new SimpleProgress struct and direct state transitions

* **🚀 Major Architecture Refactoring (September 28, 2025):** Successfully refactored the 3,349-line AddMoveUnifiedState monolith into focused, SRP-compliant components:
  - **93% Size Reduction**: Main coordinator reduced from 3,349 to 227 lines
  - **Type Safety Fix**: Resolved "Type of expression is ambiguous without a type annotation" compilation error
  - **Component Extraction**: Created TimerManager, ProgressMonitor, StateValidator, and SaveOperationCoordinator
  - **Maintainability**: All components now under 500 lines per CLAUDE.md guidelines
  - **Documentation**: Updated architecture documentation with clear component boundaries

* **Comprehensive WIP Feature Debugging:** Completed systematic analysis and debugging of all core architectural components using category theory principles and step-by-step debugging methodology
* **Core Data Schema Cleanup:** Successfully removed deprecated `videoReference` field from Move entity and updated all references across the codebase to use `photosIdentifier` for Photos library integration
* **Enhanced Video Rotation Handling:** Improved VideoTransformBuilder with advanced coordinate system alignment and proper translation calculations for 90°, 180°, and 270° rotations
* **PhotosAssetLoader Integration:** Fixed API usage across all view components (ComboDetailPlayerView, CreateComboView) with proper async/sync compatibility for UI components
* **Complete TimecodeCalculationService Integration:** Fully integrated frame-accurate timecode calculations across TrimmerViewModel, AddMoveUnifiedState, and all video processing components
* **Comprehensive Diagnostic Logging:** Added detailed logging throughout video processing pipeline with OSLog categories, memory tracking, and performance monitoring for transparent debugging
* **Memory Management Verification:** Confirmed proper retain cycle prevention in TrimmerViewModel and established robust teardown patterns across all ViewModels
* **Build System Optimization:** Resolved all compilation errors and achieved successful build validation with proper dependency injection and component communication
* **API Compatibility Updates:** Updated deprecated AVAsset usage patterns and ensured iOS 18.0 compliance across all video processing components
* **Error Handling Enhancement:** Improved error propagation and state management throughout the video processing pipeline with detailed error reporting
* **🎉 Critical Bug Fixes (September 26, 2025):** Successfully resolved duplicate album creation race condition and save ETA timer issues:
  - **AlbumManager Singleton:** Created atomic album creation system preventing duplicate "BreakDex" albums
  - **State Management Unification:** Moved timer logic from ephemeral views to persistent AddMoveUnifiedState
  - **Memory Leak Resolution:** Eliminated ElapsedTimeTracker retain cycles and implemented proper cleanup
  - **Error Resilience:** Added comprehensive error handling for haptic engine and other non-critical failures
  - **Build Verification**: Achieved clean build with 0 compilation errors and all systems operational