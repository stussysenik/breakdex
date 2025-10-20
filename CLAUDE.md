<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

## Claude.md — breakdex Video App (iOS 18.0)

# * **Single Responsibility Principle (SRP):** Enforce SRP across all components. Views remain "dumb," containing no business logic and forwarding all user actions to the ViewModel.
# **Essentialism**
# **Avoid Over-engineering**
# Make sure to avoid adding .md, or any extra files to the copy bundle resources in the build phases except for fonts and .xcassets files
# **Pay special attention to state synchronization**

### Project Structure (Clean Architecture ✅)
- **Root Path:** `~/Desktop/dev playground/BreakingFlashcards/` -> make sure to always be using the
- **Main App:** `breakdex/` (40+ organized Swift files under clean Features/ structure)
- **Architecture Status:** ✅ **Clean Architecture Complete (October 2025)**
- **Tests:** BreakingFlashcardsTests & BreakingFlashcardsUITests
- **Build System:** Xcode project with automated builds
- **Documentation**: Available at /Users/s3nik/Desktop/dev playground/BreakingFlashcards/breakdex/DOCUMENTATION.md

### Clean Architecture Structure
```
breakdex/
├── App/ (2 files: breakdex.swift, MainView.swift)
├── CoreData/ (8 Core Data files)
├── Features/ (ALL feature code organized cleanly)
│   ├── AddMove/ (Views/, Services/)
│   ├── Arsenal/ (Views/, ViewModels/)
│   ├── Combo/ (Views/, ViewModels/)
│   ├── Review/ (Views/, ViewModels/)
│   └── Shared/ (UI/, Video/, Utils/, Services/, Models/, ViewModels/)
└── Resources/ (assets)
```

### Development Guidelines (Clean Architecture)
- **SRP:** Single Responsibility Principle - each file has one clear purpose
- **Dependency Injection:** Clean separation between Views, ViewModels, and Services
- **Feature-Based Organization:** All code organized under Features/ structure
- **Shared Components:** Use existing shared UI, Video, and Utility components
- **WYSIWYG:** What you see is what you get - maintain the current clean codebase structure
- **Diagnostic Logging:** Use comprehensive logging at every step for debugging
- **Code Quality:** Write performant, maintainable, scalable code that's easy to debug
- **Principles:** Follow KISS, DRY, and YAGNI development principles
- **File Creation:** Always ask permission before creating new files to avoid "unknown project Target issues"

### Design style
DesignSystem.swift or Color+Extensions.swift

### Maximum lines of code per file (Clean Architecture Standard)
approx. 300-500 lines per file - Clean architecture achieved with focused, single-purpose files

### App Purpose
Develop a high-performance, iOS 18.0-compliant video flashcard application called breakdex for learning and reviewing complex physical movements. The project is built on a foundation of robust state management, Swift Concurrency, and a stable, custom video playback engine with millisecond-precise video trimming capabilities.

### Logging & Debugging
* **Logging-First Approach:** Adopt a logging-first approach using `OSLog` for detailed, categorized, and traceable logging. Use emojis in log categories for enhanced traceability.
* **Critical Operations:** Log every critical state transition, function entry/exit, and asynchronous boundary to aid in debugging.

### Claude Code Integration (Clean Architecture)
* Claude agent should be limited to generating/refactoring Swift or SwiftUI code, with explicit permission required for data or asset directories.
* Follow the established Features/ structure when creating or modifying code
* Use existing shared components (Video, UI, Utils, Services) whenever possible
* Request permission before altering Core Data models, `Info.plist`, or App Sandbox settings.
* Generate thorough comments for any code affecting app performance, privacy, or video playback edge cases.

### Logging
- The AppLogger protocol requires a metadata parameter
- Never delete logs unless, we're discarding the entire file/functionality.
- Be super cautious about when we need explicit self. references

### Testing Strategy (Clean Architecture)
* **Unit Tests:** Comprehensive test coverage for all ViewModels, Services, and Utility functions
* **UI Tests:** Automated UI testing for critical user flows including video playback, trimmer operations, and add move workflow
* **Integration Tests:** Feature-to-feature communication testing
* **Memory Management Testing:** Verification of retain cycle prevention and proper resource cleanup

### Testing & Compliance (Clean Architecture)
* All new code must include companion unit tests (XCTest) for models and utilities, and UI tests (XCUITest) for video playback, flashcard navigation, and error states.
* Test code within the Features/ structure following the same clean architecture principles
* The app must be fully functional and compliant with iOS 18.0 APIs.
* Verify builds using the command: `xcodebuild -project breakdex.xcodeproj -scheme breakdex -destination 'platform=iOS Simulator,name=iPhone 16' build`.
* Retain cycle prevention must be verified through Instruments profiling for all ViewModel lifecycle management.

### Feature Flags (Clean Architecture)
* Use `FeatureFlag` enum (located in Features/Shared/) for controlled feature rollout and A/B testing capabilities
* All new features should be gated behind feature flags for controlled deployment
* Feature flags are shared across all features through the Features/Shared/ directory

### Syntax Validation & Code Quality (Clean Architecture)
* **Pre-Commit Checks:** Always run `swiftc -parse` on modified files before committing
* **Build Verification:** Execute `xcodebuild -project breakdex.xcodeproj -scheme breakdex build` to verify compilation
* **Feature Structure:** Ensure new code follows Features/ organization pattern
* **Shared Component Usage:** Use existing shared components before creating new ones
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

### Error Resolution Protocol
When encountering compilation errors:
1. **Start with the first error** - subsequent errors may be cascading
2. **Check scope boundaries** using IDE tools or manual brace counting
3. **Validate dependency injection** for component communication
4. **Review type annotations** for optional vs non-optional usage
5. **Test incrementally** - fix one error, recompile, repeat

### Build Verification Commands (Clean Architecture)
```bash
# Full project build
xcodebuild -project breakdex.xcodeproj -scheme breakdex -destination 'platform=iOS Simulator,name=iPhone 16' build

# Syntax validation for feature files
swiftc -parse breakdex/Features/AddMove/Views/AddMoveView.swift
swiftc -parse breakdex/Features/Arsenal/ViewModels/ArsenalViewModel.swift
swiftc -parse breakdex/Features/Shared/Video/VideoPlayer.swift
swiftc -parse breakdex/Features/Shared/UI/Components/Button.swift

# Clean build verification
xcodebuild clean -project breakdex.xcodeproj
xcodebuild -project breakdex.xcodeproj -scheme breakdex -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build with specific simulator (useful when multiple simulators available)
xcodebuild -project breakdex.xcodeproj -scheme breakdex -destination 'platform=iOS Simulator,id=86FFC075-5BA3-4125-9534-C9F8B525E72A' build
```