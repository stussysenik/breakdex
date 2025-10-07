
# BreakingFlashcards

A comprehensive video flashcard application for learning and reviewing complex physical movements, built with SwiftUI and iOS 18.0. BreakingFlashcards combines video processing, spaced repetition, and intuitive UI to create an effective learning platform for dancers, martial artists, and movement enthusiasts.

## 🎯 Project Overview

BreakingFlashcards is a native iOS application that allows users to:
- **Create video flashcards** from their personal video library
- **Trim and rotate videos** to focus on specific movements
- **Organize moves** into categories and combos
- **Review with spaced repetition** for optimal learning retention
- **Sync with Photos app** for seamless asset management

## 🚀 Current Status

**✅ STAGE 1 - COMPLETED**
- Working UI with video import and management
- Video trimming and rotation capabilities
- Basic review mechanism with categorization
- Offline support with Core Data persistence
- Photos app integration with dedicated "BreakDex" album

**🔄 STAGE 2 - IN PROGRESS**
- Enhanced spaced repetition algorithm
- Statistics and progress tracking
- Import/export functionality for TestFlight release
- Advanced video processing features
- **Recently completed major architecture refactoring (September 2025)**
- **Progress flow fixes and video loading improvements (October 2025)**

**🔮 STAGE 3 - FUTURE FEATURES**
- Computer vision integration for movement analysis
- AI-powered move suggestions and feedback
- Social features for sharing combos

## 🏗️ Technical Architecture

### Core Technologies
- **iOS 18.0** - Latest iOS APIs and features
- **SwiftUI** - Modern declarative UI framework
- **MVVM Architecture** - Clean separation of concerns
- **Core Data** - Local persistence with CloudKit sync
- **AVFoundation** - Professional video processing
- **Photos Framework** - Seamless library integration

### Key Components
- **Video Import Loading System** - Robust video asset preparation with progress tracking
- **Video Processing Pipeline** - Frame-accurate trimming and rotation
- **Unified State Management** - Single source of truth for app state
- **Custom Video Player** - Optimized for learning scenarios
- **Memory Management** - Proactive monitoring for large video files
- **Error Handling** - Comprehensive recovery mechanisms
- **Modular AddMove Architecture** - Unified state management with comprehensive video loading system

### Video Import Loading Architecture
The app features a sophisticated video import loading state system that handles video asset preparation with comprehensive error handling and progress tracking:

**Core Services:**
- **VideoLoadingService** - Main service for async video loading with iCloud download support
- **VideoAssetPreparer** - High-level coordinator for video asset preparation
- **VideoStateManager** - State machine for video processing transitions
- **ImportManager** - Resilient import manager with retry logic and exponential backoff

**State Management:**
- Comprehensive state machine (.idle, .loading, .loaded, .processing, .ready, .error)
- Progress tracking with detailed percentage reporting (0-70% download, 70-100% metadata)
- Memory-aware operations with thresholds and cleanup
- Health monitoring and race condition prevention

**Key Features:**
- Async/await based operations with timeout protection
- Streaming file copy to prevent memory overload
- iCloud download handling with progress reporting
- Comprehensive diagnostic logging throughout pipeline
- Frame-accurate video processing with millisecond precision

## 📊 Project Statistics

- **120 Swift files** with modern iOS 18.0 patterns
- **45,154 lines of code** with comprehensive functionality
- **Modular architecture** with clear separation of concerns
- **Production-ready** video processing pipeline
- **Robust error handling** and logging system
- **Recent bug fixes** - Progress flow fixes and video loading improvements (October 2025)

## 🎮 Core Features

### 1. Add Move Flow
- **Video Selection**: Import from Photos library with permission handling and robust loading states
- **Video Loading**: Comprehensive video asset preparation with progress tracking (0-70% download, 70-100% metadata)
- **Video Trimming**: Frame-accurate timeline editor with visual feedback
- **Video Rotation**: Quarter-turn rotation controls with live preview
- **Move Naming**: Organize with custom names and tags
- **Asset Management**: Automatic saving to BreakDex album
- **Resilient Video Loading**: Enhanced progress flow with iCloud download handling and deterministic progress tracking

### 2. Arsenal Management
- **Move Library**: Browse and search all saved moves
- **Combo Creation**: Combine moves into sequences
- **Timeline View**: Visual representation of combo timing
- **Metadata Management**: Tags, categories, and learning states

### 3. Review System
- **Spaced Repetition**: Algorithm-based review scheduling
- **Video Gallery**: Intuitive flashcard-style review interface
- **Progress Tracking**: Monitor learning advancement
- **Review History**: Track performance over time

## 🛠️ Development Setup

### Prerequisites
- Xcode 16.0 or later
- iOS 18.0 SDK
- macOS 14.0 or later

### Building the Project
```bash
# Clone the repository
cd BreakingFlashcards

# Open in Xcode
open breakdex.xcodeproj

# Build from command line
xcodebuild -project breakdex.xcodeproj -scheme breakdex -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### Running Tests
```bash
# Run unit tests
xcodebuild test -project breakdex.xcodeproj -scheme breakdex -destination 'platform=iOS Simulator,name=iPhone 16'

# Run UI tests
xcodebuild test -project breakdex.xcodeproj -scheme breakdex -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:breakdexUITests
```

## 📱 Device Requirements

- **iOS 18.0 or later**
- **iPhone XS or newer** (for video processing performance)
- **Minimum 1GB free storage** for video operations
- **Camera access** for future video capture features

## 🔧 Feature Requests

### High Priority
1. **Import/Export** - Complete implementation for data portability
2. **Enhanced Statistics** - Detailed learning analytics
3. **Backup/Restore** - CloudKit integration for data safety

### Medium Priority
1. **Random Name Generator** - "Marrson" feature for move naming
2. **Roll the Dice** - Random move/combo selection for practice
3. **Custom Categories** - User-defined organization system

### Future Features
1. **Computer Vision** - Automatic movement analysis
2. **Social Sharing** - Share combos with other users
3. **Apple Watch Support** - Remote control during practice

## 📋 Development Guidelines

### Code Quality
- **Maximum 500 lines per file** - Enforces Single Responsibility Principle
- **Comprehensive logging** - OSLog integration with emoji prefixes
- **Memory management** - Proactive monitoring and cleanup
- **Error handling** - Graceful degradation and recovery

### Architecture Principles
- **MVVM Pattern** - Clear separation of UI and business logic
- **Dependency Injection** - Singleton AppContainer for services
- **State Management** - Unified state system with reactive updates
- **Protocol-Based Design** - Abstraction for testability and flexibility
- **Video Loading Architecture** - Comprehensive video import state management with progress tracking

### Testing Strategy
- **Unit Tests** - Cover all managers, view models, and utilities
- **UI Tests** - Automate critical user flows
- **Integration Tests** - Verify component interactions
- **Performance Tests** - Monitor video processing efficiency

## 📄 Documentation

- **[Technical Architecture](./DOCUMENTATION.md)** - Comprehensive technical documentation (89KB)
- **[Development Guidelines](./CLAUDE.md)** - Claude AI integration guidelines (15KB)
- **[PRD Archives](./PRD/)** - Product requirement documents and development logs
- **[Progress Flow Fix Summary](../PROGRESS_FLOW_FIX_SUMMARY.md)** - Complete implementation details for October 2025 progress fixes
- **Recent Updates**: Documentation reflects September 2025 major refactoring, October 2025 progress flow fixes, and 120-file codebase

## 🤝 Contributing

1. Follow the development guidelines in [CLAUDE.md](./CLAUDE.md)
2. Ensure all tests pass before submitting changes
3. Update documentation for new features
4. Use semantic versioning for releases
5. Follow Swift/SwiftUI best practices

## 📄 License

This project is for educational and personal use. Please contact the project maintainers for commercial use inquiries.

## 🙏 Acknowledgments

- Built with modern iOS 18.0 technologies
- Incorporates best practices from the iOS development community
- Inspired by the need for effective movement learning tools
