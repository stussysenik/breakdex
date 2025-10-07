# BreakingFlashcards Save Move Architecture

## 📋 Overview

This document provides a comprehensive architectural overview of the save move functionality in the BreakingFlashcards iOS application. The save move system implements a sophisticated, multi-layered architecture that handles video processing, Core Data persistence, and comprehensive error handling.

### Current Status

**Architecture Maturity**: Production-ready with comprehensive error handling and memory management
**File Count**: 20+ files involved in complete save workflow
**Testing**: Comprehensive unit, integration, and performance testing implemented
**Performance**: Optimized for large video files with background processing and progress tracking
**Latest Update**: October 5, 2025 - Critical video playback fixes implemented
**Build Status**: ✅ All compilation errors resolved, successful build validation achieved
**Recent Fixes**: MoveDetailView flicker elimination, "Change Video" deadlock resolution

---

## 🏗️ Complete Save Move Pipeline

### 8-Step Save Workflow

```
User Action → State Validation → Save Coordination → Video Processing →
File Management → Core Data Persistence → State Updates → Flow Transition
```

### Detailed Pipeline Steps

#### Step 1: User Action (UI Trigger)
- **File**: `Views/Arsenal/AddMove/NameMoveViewUnified.swift`
- **Function**: `handleSave()` (lines 273-287)
- **Process**:
  - Validates user input (move name, video selection)
  - Triggers save process through state management
  - Shows loading state and progress indicators

#### Step 2: State Validation
- **File**: `Views/Arsenal/AddMove/AddMoveUnifiedState.swift`
- **Function**: `saveMove()` - Central orchestrator
- **Process**:
  - Validates save readiness (video selected, name provided)
  - Initiates save coordination
  - Manages loading states and error handling
  - Provides progress tracking throughout save operation

#### Step 3: Save Coordination
- **File**: `Views/Arsenal/AddMove/AddMoveSaveCoordinator.swift`
- **Key Functions**:
  - `saveMove()` (lines 38-86) - Main save orchestration
  - `processSaveOperation()` (lines 194-284) - Detailed save pipeline
- **Process**:
  - Coordinates between video processing and Core Data
  - Manages error handling and recovery
  - Provides detailed progress updates
  - Handles save operation lifecycle

#### Step 4: Video Processing
- **File**: `Video/VideoProcessingPipeline.swift`
- **Key Functions**: `saveVideo()` (lines 323-393)
- **Process**:
  - Processes video asset with trim and rotation
  - Exports video using AVAssetExportSession
  - Handles video compression and quality optimization
  - Manages export progress and cancellation

#### Step 5: File Management
- **File**: `Video/VideoSaver.swift`
- **Key Functions**:
  - `saveVideo()` (lines 19-61) - App storage saving
  - `saveToPhotosLibrary()` (lines 63-128) - Photos library integration
- **Process**:
  - Saves processed video to app storage
  - Optionally saves to Photos library
  - Manages file URLs and permissions
  - Handles file storage optimization

#### Step 6: Core Data Persistence
- **File**: `Managers/MovePersistenceService.swift`
- **Key Functions**:
  - `saveCompleteMove()` (lines 111-144) - Complete save operation
  - `createMoveEntity()` (lines 61-108) - Core Data entity creation
- **Process**:
  - Creates Move entity in Core Data
  - Stores video reference and metadata
  - Handles relationships and validation
  - Manages Core Data context and saving

#### Step 7: State Updates
- **File**: `Views/Arsenal/AddMove/AddMoveUnifiedState.swift`
- **Process**:
  - Updates state to reflect save completion
  - Manages success/error state transitions
  - Triggers UI updates for completion status
  - Handles post-save cleanup and navigation

#### Step 8: Flow Transition
- **File**: `Views/Arsenal/AddMove/AddMoveContainer.swift`
- **Process**:
  - Transitions to appropriate next view
  - Manages navigation stack and user flow
  - Handles success celebration or error recovery
  - Resets flow state for next operation

---

## 📁 Core Save Files Inventory

### Primary Save Files (12 files)

| File | Role | Key Functions | Lines |
|------|------|---------------|-------|
| **NameMoveViewUnified.swift** | UI Trigger | `handleSave()`, input validation | 350+ |
| **AddMoveUnifiedState.swift** | State Management | `saveMove()`, progress tracking | 1004 |
| **AddMoveSaveCoordinator.swift** | Save Coordination | `saveMove()`, `processSaveOperation()` | 300+ |
| **MovePersistenceService.swift** | Core Data Operations | `saveCompleteMove()`, `createMoveEntity()` | 150+ |
| **VideoProcessingPipeline.swift** | Video Processing | `saveVideo()`, export operations | 400+ |
| **VideoSaver.swift** | File Management | `saveVideo()`, `saveToPhotosLibrary()` | 130+ |
| **Persistence.swift** | Core Data Stack | Context management, stack setup | 200+ |
| **Move+CoreDataClass.swift** | Entity Definition | Move entity class definition | 50+ |
| **Move+CoreDataProperties.swift** | Entity Properties | Move entity properties and relationships | 100+ |
| **AppContainer.swift** | Dependency Injection | Service management, DI container | 150+ |
| **AddMoveContainer.swift** | Flow Management | State routing, view transitions | 200+ |
| **VideoProcessingError.swift** | Error Handling | Save move error types and handling | 80+ |

### Supporting Infrastructure Files (8+ files)

| File | Role | Key Functions |
|------|------|---------------|
| **UnifiedPlayerManager.swift** | Video Player Management | Player lifecycle, cleanup |
| **MemoryManager.swift** | Memory Optimization | Memory monitoring, pressure handling |
| **VideoStateManager.swift** | Video State Management | Video state coordination |
| **VideoHealthMonitor.swift** | Health Monitoring | Video processing health checks |
| **VideoProcessor.swift** | Video Processing | Core video processing logic |
| **VideoTransformBuilder.swift** | Video Transformation | Video rotation and trimming |
| **DiagnosticLoggingHelper.swift** | Logging Infrastructure | Structured logging and diagnostics |
| **Core Data Related Files** | Data Layer | Various Core Data utilities and extensions |

---

## 🗄️ Core Data Model Structure

### Move Entity Schema

```swift
// Core Data Entity: Move (Updated September 2025)
public class Move: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var photosIdentifier: String?  // 🎯 UPDATED: Now primary video reference
    @NSManaged public var trimStartTime: Double
    @NSManaged public var trimEndTime: Double
    @NSManaged public var rotationQuarterTurns: Int16
    @NSManaged public var createdAt: Date?
    @NSManaged public var learningState: String?
    @NSManaged public var tags: String?

    // Relationships
    @NSManaged public var combos: NSSet?
    @NSManaged public var reviews: NSSet?
}
```

### Entity Relationships

```
Move (Entity) (Updated September 2025)
├── combos → Combo (Many-to-Many)
├── reviews → Review (One-to-Many)
└── photosIdentifier → String (Primary Photos library reference)
```

### Data Storage Strategy (Updated)

#### Video Storage
- **Primary Storage**: Video files stored in Photos library with identifiers
- **Core Data Reference**: Photos library local identifiers stored as strings
- **Photos Integration**: First-class Photos library integration via PhotosAssetLoader
- **Asset Loading**: Async asset loading with proper authorization handling
- **Migration**: Migrated from binary videoReference storage to Photos identifier approach

### Data Storage Strategy

#### Video Storage
- **Primary Storage**: Video files saved to app sandbox directory
- **Core Data Reference**: Video file path/stored as Data reference
- **Photos Integration**: Optional backup to Photos library
- **Compression**: H.264 with optimized quality settings

#### Metadata Storage
- **User Metadata**: Name, tags, creation date
- **Video Metadata**: Trim times, rotation, duration
- **Learning Data**: Learning state, progress tracking
- **External References**: Photos library identifiers

---

## 🚨 Error Handling Architecture

### Error Types Hierarchy

```swift
enum SaveMoveError: LocalizedError {
    case validationFailed(String)
    case videoProcessingFailed(VideoProcessingError)
    case coreDataPersistenceFailed(Error)
    case fileManagementFailed(Error)
    case insufficientStorage
    case permissionDenied
    case networkRequired
    case unknown(Error)
}
```

### Error Handling Strategy

#### 1. **Validation Errors**
- **Pre-save Validation**: Input validation before processing begins
- **Progress Validation**: Validation during save operation
- **Post-save Validation**: Verification of successful save

#### 2. **Video Processing Errors**
- **Export Failures**: AVFoundation export session failures
- **Processing Timeouts**: Long-running operation timeouts
- **Memory Pressure**: System memory pressure handling
- **Format Errors**: Unsupported video formats or codecs

#### 3. **Core Data Errors**
- **Validation Errors**: Core Data model validation failures
- **Context Errors**: Managed object context issues
- **Persistence Errors**: Save to persistent store failures
- **Migration Errors**: Schema migration issues

#### 4. **File Management Errors**
- **Storage Issues**: Insufficient disk space
- **Permission Errors**: File access permission denied
- **IO Errors**: File read/write failures
- **URL Errors**: Invalid or inaccessible file URLs

### Error Recovery Patterns

#### 1. **Retry Mechanisms**
- **Automatic Retry**: For transient failures (network, temporary storage)
- **User-Initiated Retry**: For user-correctable errors
- **Exponential Backoff**: For retryable failures

#### 2. **Graceful Degradation**
- **Quality Reduction**: Lower video quality for storage constraints
- **Feature Disabling**: Disable optional features for resource constraints
- **Alternative Storage**: Fallback storage locations

#### 3. **User Communication**
- **Clear Error Messages**: User-friendly error descriptions
- **Recovery Suggestions**: Actionable recovery steps
- **Progress Feedback**: Real-time progress during retry attempts

---

## 🧠 Memory Management

### Retain Cycle Prevention

#### Deterministic Teardown Pattern
```swift
// Implemented in all ViewModels
public func teardown() {
    // Cancel all long-running tasks
    healthMonitorTask?.cancel()
    healthMonitorTask = nil

    // Cleanup Combine subscriptions
    cancellables.removeAll()

    // Release resources
    player.pause()
    player.replaceCurrentItem(with: nil)

    // Reset state
    state = .idle
}
```

#### Memory Management Best Practices
- **Weak References**: For delegate patterns and closures
- **Unowned References**: For known lifecycle relationships
- **Explicit Cleanup**: All resources explicitly released
- **Memory Monitoring**: Real-time memory usage tracking

### Performance Optimizations

#### 1. **Background Processing**
- **Async/Await**: Modern concurrency for all operations
- **Background Queues**: Video processing on background threads
- **MainActor Isolation**: UI updates on main thread only

#### 2. **Resource Management**
- **Lazy Loading**: Resources loaded only when needed
- **Early Release**: Resources released immediately after use
- **Pool Management**: Reusable resource pools for expensive objects

#### 3. **Memory Pressure Handling**
- **System Notifications**: Respond to memory pressure warnings
- **Resource Cleanup**: Aggressive cleanup under memory pressure
- **Quality Reduction**: Reduce processing quality under constraints

---

## 🧪 Testing Strategy

### Unit Testing

#### ViewModel Testing
```swift
// Test Save Move ViewModels
func testSaveMoveViewModel_Success() {
    let viewModel = SaveMoveViewModel()
    let expectation = XCTestExpectation()

    viewModel.saveMove(name: "Test Move", asset: testAsset) { result in
        switch result {
        case .success:
            expectation.fulfill()
        case .failure:
            XCTFail()
        }
    }

    wait(for: [expectation], timeout: 10.0)
}
```

#### Service Testing
- **MovePersistenceService Tests**: Core Data operation testing
- **VideoProcessingPipeline Tests**: Video processing logic testing
- **VideoSaver Tests**: File management testing

### Integration Testing

#### End-to-End Save Flow
```swift
func testCompleteSaveFlow_Success() {
    // 1. Setup test video asset
    let testAsset = createTestVideoAsset()

    // 2. Execute complete save flow
    let result = try await saveMoveCoordinator.saveMove(
        name: "Integration Test Move",
        asset: testAsset
    )

    // 3. Verify Core Data persistence
    let savedMove = try context.fetch(Move.self, id: result.moveId)
    XCTAssertNotNil(savedMove)

    // 4. Verify file storage
    XCTAssertTrue(FileManager.default.fileExists(atPath: savedMove.videoURL))
}
```

#### Performance Testing
- **Memory Profiling**: Instruments for memory leak detection
- **Performance Benchmarks**: Save operation timing metrics
- **Stress Testing**: Multiple concurrent save operations

### Test Coverage Requirements

| Component | Target Coverage | Critical Tests |
|-----------|----------------|----------------|
| **ViewModels** | 90%+ | Save logic, error handling |
| **Services** | 85%+ | Core Data, video processing |
| **Utilities** | 80%+ | File management, logging |
| **Integration** | 75%+ | End-to-end workflows |

---

## 📊 Performance Metrics

### Timing Benchmarks

| Operation | Target Time | Optimizations |
|-----------|-------------|---------------|
| **Small Video (<10MB)** | < 5 seconds | Fast export settings |
| **Medium Video (10-50MB)** | < 15 seconds | Progressive processing |
| **Large Video (>50MB)** | < 30 seconds | Background processing |
| **Core Data Save** | < 1 second | Batch operations |

### Memory Usage

| Component | Target Usage | Monitoring |
|-----------|-------------|------------|
| **Video Processing** | < 100MB peak | Real-time tracking |
| **Core Data** | < 50MB | Context management |
| **Overall App** | < 200MB | System pressure handling |

### Success Rate Metrics

- **Save Success Rate**: > 99% under normal conditions
- **Error Recovery Rate**: > 95% for recoverable errors
- **Memory Safety**: 100% leak-free operation
- **Crash-Free Sessions**: > 99.9% for save operations

---

## 🔧 Configuration and Deployment

### Feature Flags

```swift
enum SaveMoveFeatureFlag: String, CaseIterable {
    case enhancedCompression = "enhanced_compression"
    case backgroundProcessing = "background_processing"
    case cloudSync = "cloud_sync"
    case advancedErrorRecovery = "advanced_error_recovery"
}
```

### Environment Configuration

```swift
struct SaveMoveConfiguration {
    let maxVideoSize: Int64 // 500MB default
    let compressionQuality: Float // 0.8 default
    let enableBackgroundProcessing: Bool // true default
    let enableCloudSync: Bool // false default
    let retryAttempts: Int // 3 default
    let timeoutInterval: TimeInterval // 300 seconds default
}
```

### Monitoring and Analytics

#### Key Metrics
- **Save Operation Success Rate**
- **Average Save Duration**
- **Memory Usage During Save**
- **Error Type Distribution**
- **User Abandonment Rate**

#### Logging Strategy
- **Structured Logging**: JSON-formatted logs for analysis
- **Performance Metrics**: Timing and memory usage tracking
- **Error Tracking**: Comprehensive error logging with context
- **User Analytics**: Save operation patterns and success rates

---

## 🎯 Future Enhancements

### Near-term Improvements

#### 1. **Cloud Synchronization**
- **iCloud Sync**: Move synchronization across devices
- **Backup/Restore**: Cloud backup for user data
- **Sharing**: Move sharing between users

#### 2. **Advanced Video Processing**
- **AI Enhancement**: Automatic video quality improvement
- **Smart Trimming**: AI-powered video trimming suggestions
- **Format Optimization**: Adaptive format selection

#### 3. **Performance Optimizations**
- **Cached Processing**: Reuse processed video segments
- **Progressive Save**: Save while processing continues
- **Batch Operations**: Multiple move save optimization

### Long-term Vision

#### 1. **Machine Learning Integration**
- **Movement Recognition**: Automatic move classification
- **Quality Assessment**: AI-powered video quality scoring
- **Personalization**: Adaptive compression based on user patterns

#### 2. **Advanced Analytics**
- **Usage Patterns**: Detailed user behavior analysis
- **Performance Insights**: Automated performance optimization
- **Predictive Modeling**: Predictive error prevention

#### 3. **Ecosystem Expansion**
- **Multi-platform**: macOS, watchOS extensions
- **API Integration**: Third-party app integrations
- **Collaborative Features**: Multi-user collaboration

---

## 📚 Related Documentation

### Core Documentation
- **DOCUMENTATION.md**: Main technical architecture documentation
- **CLAUDE.md**: Development guidelines and best practices
- **fix-EXC_BAD_ACCESS.md**: Retain cycle resolution case study

### Feature Documentation
- **PRD/09-24-25/64. saveMove-list.md**: File inventory analysis
- **PRD/09-24-25/62. compilationErrors.md**: Build error resolution
- **Various PRD entries**: Development progress and challenges

### Testing and Quality
- **Test Plans**: Comprehensive testing strategy
- **Performance Benchmarks**: Performance requirements and metrics
- **Error Handling**: Error types and recovery strategies

---

**Document Status**: ✅ Complete - Production-ready architecture documentation
**Last Updated**: September 25, 2025
**Maintainers**: Development Team
**Review Cycle**: Quarterly or as needed
**Recent Changes**:
- ✅ **October 5, 2025**: Critical video playback fixes - MoveDetailView flicker elimination and "Change Video" deadlock resolution
- ✅ **October 5, 2025**: Added comprehensive OSLog diagnostics throughout video processing pipeline
- ✅ **October 5, 2025**: Implemented atomic state update patterns to prevent UI race conditions
- ✅ Removed deprecated videoReference field from Core Data schema
- ✅ Updated all video asset loading to use PhotosAssetLoader
- ✅ Enhanced video rotation handling in VideoTransformBuilder
- ✅ Integrated TimecodeCalculationService across all components
- ✅ Added comprehensive diagnostic logging throughout pipeline
- ✅ Resolved all compilation errors and achieved successful build validation