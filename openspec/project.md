# Project Context

## Purpose
breakdex is a high-performance iOS video flashcard application designed for learning and reviewing complex physical movements. The app enables users to create video-based flashcards with millisecond-precise trimming capabilities, organize them into combos, and review them through an intuitive interface. Built specifically for iOS 18.0, the app focuses on robust video playback, state management, and Swift Concurrency for optimal performance.

## Tech Stack
- **Platform:** iOS 18.0+ (native Swift/SwiftUI application)
- **Language:** Swift 5.9+ with Swift Concurrency (async/await)
- **UI Framework:** SwiftUI with UIKit integrations for video playback
- **Database:** Core Data for persistent storage
- **Video Processing:** AVFoundation for video playback and trimming
- **Architecture:** Clean Architecture with feature-based organization
- **Logging:** OSLog for comprehensive, categorized debugging
- **Testing:** XCTest (unit tests) and XCUITest (UI tests)
- **Build System:** Xcode project with automated builds
- **Performance:** MainActor isolation and memory management optimization

## Project Conventions

### Code Style
- **File Size:** Maximum 300-500 lines per file following Clean Architecture standards
- **Naming:** Descriptive names following Swift API Design Guidelines
- **Organization:** Feature-based structure under `Features/` directory
- **Comments:** Comprehensive logging and documentation for performance-critical code
- **Dependencies:** Explicit dependency injection between components
- **Error Handling:** Comprehensive error states and recovery mechanisms

### Architecture Patterns
- **Clean Architecture:** Clear separation between Views, ViewModels, and Services
- **Single Responsibility Principle (SRP):** Each component has one clear purpose
- **Dependency Injection:** Clean separation between UI and business logic
- **MVVM Pattern:** Views remain "dumb," forwarding actions to ViewModels
- **Feature-Based Organization:** All code organized under Features/ structure
- **Shared Components:** Use existing shared UI, Video, and Utility components
- **State Management:** Unified state management through UnifiedState and TabState models

### Testing Strategy
- **Unit Tests:** Comprehensive coverage for ViewModels, Services, and Utility functions
- **UI Tests:** Automated testing for critical user flows (video playback, trimming, navigation)
- **Integration Tests:** Feature-to-feature communication testing
- **Memory Management:** Verification of retain cycle prevention and resource cleanup
- **Build Verification:** Pre-commit syntax validation and automated builds
- **Test Location:** Test code within Features/ structure following clean architecture principles

### Git Workflow
- **Main Branch:** `main` for production releases
- **Feature Branches:** Topic branches for new features and bug fixes
- **Commit Style:** Conventional commits with descriptive messages
- **Pre-Commit Checks:** Syntax validation using `swiftc -parse` and build verification
- **Code Review:** All changes reviewed before merging to main

## Domain Context

### Video Processing Domain
- **Video Loading:** Complex video loading system with resiliency and error handling
- **Trimming:** Millisecond-precise video trimming capabilities
- **Playback:** Custom video player with progress monitoring
- **Asset Management:** Photo library integration for video selection

### Flashcard Learning Domain
- **Moves:** Individual video flashcards representing physical movements
- **Combos:** Collections of moves organized for learning sequences
- **Progress Tracking:** User progress monitoring across different learning activities
- **Review System:** Spaced repetition and review mechanisms

### Physical Movement Learning
- **Domain-Specific Concepts:** Understanding of movement terminology and learning patterns
- **Performance Optimization:** Real-time video playback requires careful performance optimization
- **User Experience:** Focus on smooth video interaction and minimal latency

## Important Constraints

### Technical Constraints
- **iOS Version:** Must be compatible with iOS 18.0+
- **Memory Management:** Strict requirements for video playback performance
- **File Size:** Clean architecture limits files to 300-500 lines maximum
- **Async Operations:** All video operations must use Swift Concurrency
- **Main Thread:** UI updates must be properly isolated to MainActor

### Business Constraints
- **Performance:** Video playback must be smooth and responsive
- **Reliability:** Robust error handling for video loading and processing
- **User Privacy:** Photo library access must follow iOS privacy guidelines
- **App Store Guidelines:** Must comply with Apple's app review guidelines

### Development Constraints
- **Feature Flags:** New features must be gated behind FeatureFlag enum
- **File Permissions:** Explicit permission required for Core Data and Info.plist changes
- **Build Requirements:** All changes must pass automated build verification
- **Testing Coverage:** New code must include comprehensive test coverage

## External Dependencies

### iOS Frameworks
- **AVFoundation:** Core video processing and playback capabilities
- **Photos Framework:** Photo library access and asset management
- **Core Data:** Persistent storage for user data and flashcard metadata
- **SwiftUI:** Primary UI framework for modern iOS development
- **Combine:** Reactive programming for state management (where applicable)

### System Services
- **Photo Library:** User's personal video collection for flashcard creation
- **File System:** Local storage for video processing and caching
- **Memory Management:** iOS memory management system for video playback optimization

### Development Tools
- **Xcode:** Primary development environment and build system
- **Instruments:** Performance profiling and memory leak detection
- **Swift Compiler:** Syntax validation and compilation verification
