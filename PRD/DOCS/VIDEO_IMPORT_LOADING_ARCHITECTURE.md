# Video Import Loading Architecture

## Overview

BreakingFlashcards implements a sophisticated video import loading state system that handles video asset preparation with comprehensive error handling, progress tracking, and memory management. This architecture ensures robust video processing from initial import through final asset readiness.

## Core Architecture

### Services Layer

#### VideoLoadingService
- **File:** `Video/VideoLoadingService.swift`
- **Purpose:** Main service for async video loading with iCloud download support
- **Key Features:**
  - Async/await based video loading with timeout support
  - Progress reporting during iCloud downloads (0-70% for download, 70-100% for metadata)
  - Memory management with thresholds and cleanup
  - Support for PHAsset, URL, and pre-loaded AVAsset sources
  - Comprehensive error handling for various failure scenarios

#### VideoAssetPreparer
- **File:** `Managers/VideoAssetPreparer.swift`
- **Purpose:** High-level coordinator for video asset preparation
- **Key Features:**
  - Prepares videos from PhotosPickerItem or direct assets
  - Creates UnifiedVideoPlayerViewModel instances
  - Implements retry logic with exponential backoff
  - Comprehensive diagnostic logging and memory tracking
  - Handles player readiness monitoring

#### VideoStateManager
- **File:** `Video/VideoStateManager.swift`
- **Purpose:** Manages video processing states with transitions
- **Key Features:**
  - State machine for video processing (.idle, .loading, .loaded, .processing, .ready, etc.)
  - Memory-aware state transitions
  - State validation and error handling

#### ImportManager
- **File:** `Managers/ImportManager.swift`
- **Purpose:** Resilient import manager with retry logic
- **Key Features:**
  - Exponential backoff for network failures
  - Timeout protection for all operations
  - iCloud download handling
  - Batch import capabilities

### State Management

#### VideoState
- **File:** `Video/VideoState.swift`
- **Purpose:** Defines video state enums and transition rules
- **Key Features:**
  - Comprehensive state definitions
  - State transition validation
  - Progress tracking capabilities

#### State Machine Flow
```
.idle → .loading → .loaded → .processing → .ready
                     ↓         ↓           ↓
                   .error ← .error ← .error
```

### Import Components

#### AddMoveVideoLoader
- **File:** `Views/Arsenal/AddMove/AddMoveVideoLoader.swift`
- **Purpose:** Primary video loader for the Add Move flow
- **Key Features:**
  - Handles both Photos library and direct file loading
  - Streaming file copy to prevent memory overload
  - Detailed asset metadata extraction
  - Comprehensive error handling and logging

#### PhotosImportService
- **File:** `Managers/PhotosImportService.swift`
- **Purpose:** Photos import service with state management
- **Key Features:**
  - Import state tracking (.idle, .importing, .ready, .error)
  - Streaming file copy approach
  - Temporary artifact cleanup

### Data Models

#### VideoImportTypes
- **File:** `Models/VideoImportTypes.swift`
- **Purpose:** Core video import data types
- **Key Features:**
  - Movie transferable type with iCloud download tracking
  - Streaming file copy implementation
  - Comprehensive error handling for import operations

#### AddMoveUnifiedState
- **File:** `Views/Arsenal/AddMove/AddMoveUnifiedState.swift`
- **Purpose:** Unified state management for Add Move flow
- **Key Features:**
  - Flow state management with progress tracking
  - Player state coordination
  - Timeout protection for async operations

## Key Features

### Progress Tracking System
- **Two-phase progress reporting:** 0-70% for iCloud download, 70-100% for metadata processing
- **Real-time updates:** Live progress feedback during video loading
- **Granular reporting:** Frame-accurate progress for video processing operations

### Memory Management
- **Proactive monitoring:** Memory usage tracking with configurable thresholds
- **Automatic cleanup:** Resource cleanup when memory limits approached
- **Streaming processing:** File streaming to prevent memory overload with large videos

### Error Handling
- **Comprehensive recovery:** Automatic retry with exponential backoff
- **Graceful degradation:** Non-critical failures logged without interrupting operations
- **Detailed diagnostics:** Enhanced logging with frame-precision information

### iCloud Integration
- **Seamless downloading:** Automatic iCloud download with progress tracking
- **Network resilience:** Handles network interruptions gracefully
- **Asset verification:** Ensures downloaded assets are valid and accessible

## Performance Optimizations

### Async/Await Pattern
- Modern Swift concurrency throughout the pipeline
- Non-blocking operations for responsive UI
- Proper cancellation support for long-running operations

### Caching Strategy
- Intelligent caching of loaded assets
- Memory-aware cache eviction
- Persistent cache for frequently accessed assets

### Batch Processing
- Efficient batch import capabilities
- Parallel processing when appropriate
- Resource-conscious batch size management

## Integration Points

### Video Processing Pipeline
- Seamless handoff from import to processing
- Shared state management across pipeline stages
- Consistent error handling throughout

### Player Management
- Direct integration with UnifiedVideoPlayerViewModel
- Health monitoring integration
- Memory management for preview mode

### Photos Framework
- Deep integration with Photos library
- Proper authorization handling
- Album management through AlbumManager

## Error Recovery

### Automatic Retry Logic
- Exponential backoff for transient failures
- Configurable retry limits
- Smart retry based on error type

### State Recovery
- Automatic state restoration after failures
- Context preservation across retry attempts
- User-friendly error messages

### Diagnostics
- Comprehensive logging with OSLog integration
- Memory tracking and performance monitoring
- Detailed error reporting with suggestions

## Usage Examples

### Basic Video Loading
```swift
let preparer = VideoAssetPreparer()
let result = await preparer.prepareVideo(from: photosPickerItem) { progress in
    // Update UI with progress (0.0 to 1.0)
    print("Loading progress: \(progress * 100)%")
}
```

### Advanced Import with Retry
```swift
let importManager = ImportManager()
do {
    let asset = try await importManager.importVideo(
        from: url,
        withRetry: true,
        maxRetries: 3
    )
} catch {
    // Handle import error
}
```

### State Monitoring
```swift
let stateManager = VideoStateManager()
stateManager.statePublisher
    .sink { state in
        switch state {
        case .loading(let progress):
            print("Loading: \(progress * 100)%")
        case .ready:
            print("Video ready for use")
        case .error(let error):
            print("Error: \(error)")
        default:
            break
        }
    }
    .store(in: &cancellables)
```

## Testing Considerations

### Unit Testing
- Test individual service components in isolation
- Mock external dependencies (Photos framework, network)
- Verify error handling and recovery scenarios
- Test memory management and cleanup

### Integration Testing
- Test complete import pipeline end-to-end
- Verify state transitions across components
- Test with various video formats and sizes
- Validate iCloud download scenarios

### Performance Testing
- Monitor memory usage during large video imports
- Measure import time for different scenarios
- Test with limited network conditions
- Verify concurrent import performance

## Future Enhancements

### Planned Improvements
- **Background processing:** Support for background video imports
- **Compression options:** User-selectable compression settings
- **Metadata extraction:** Enhanced metadata analysis
- **Batch optimization:** Improved batch import performance

### Extension Opportunities
- **Cloud processing:** Cloud-based video processing for large files
- **AI integration:** Automatic move detection and classification
- **Social features:** Video sharing with import state preservation
- **Cross-platform:** Unified import architecture across platforms

## Conclusion

The Video Import Loading Architecture provides a robust, scalable foundation for video processing in BreakingFlashcards. With comprehensive error handling, memory management, and state coordination, the system ensures reliable video imports from various sources while providing excellent user feedback throughout the process.