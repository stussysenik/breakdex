# Video Asset Transfer Specification

## Overview
This specification defines the enhanced video asset transfer mechanism between AddMoveViewModel and MinimalTrimmerView to resolve the critical bottleneck where users get stuck at 10% progress during the add move workflow.

## Components

### Enhanced TrimmerViewModelProtocol

```swift
@MainActor
protocol TrimmerViewModelProtocol: ObservableObject {
    // Existing properties
    var selectedVideo: AVAsset? { get }
    var trimStartTime: TimeInterval { get set }
    var trimEndTime: TimeInterval { get set }
    var videoDuration: TimeInterval { get }
    var videoRotation: VideoRotation { get set }
    var errorMessage: String? { get }

    // Enhanced asset transfer properties
    var videoAssetReady: Bool { get }
    var assetTransferProgress: Double { get }
    var lastAssetTransferError: Error? { get }

    // Enhanced methods
    func transferVideoAsset(to player: SharedVideoPlayer) async throws
    func validateVideoAsset() -> AssetValidationResult
    func prepareAssetForTransfer() async -> AVAsset?
}
```

### Asset Transfer State Management

```swift
enum AssetTransferState {
    case idle                    // No transfer in progress
    case preparing              // Preparing asset for transfer
    case transferring(progress: Double)  // Active transfer with progress
    case completed              // Transfer successful
    case failed(error: Error)   // Transfer failed
}
```

### Enhanced SharedVideoPlayer Integration

```swift
extension SharedVideoPlayer {
    /// Load video with enhanced transfer support and diagnostics
    func loadVideoWithTransfer(
        _ asset: AVAsset,
        transferId: UUID,
        onProgress: @escaping (Double) -> Void,
        onCompletion: @escaping (Result<Void, Error>) -> Void
    ) async

    /// Validate asset compatibility before loading
    func validateAssetForLoading(_ asset: AVAsset) async -> AssetValidationResult

    /// Get detailed loading diagnostics
    var loadingDiagnostics: LoadingDiagnostics { get }
}
```

## Data Flow

### 1. Asset Detection Phase
- MinimalTrimmerView detects AddMoveViewModel.selectedVideo availability
- Validates asset compatibility and readiness
- Logs asset detection with diagnostic information

### 2. Transfer Preparation Phase
- AddMoveViewModel prepares asset for transfer (validation, optimization)
- Creates transfer session with unique ID
- Sets up progress tracking and error handling

### 3. Asset Transfer Phase
- Transfer video asset from AddMoveViewModel to SharedVideoPlayer
- Monitor transfer progress with detailed logging
- Handle transfer errors with retry mechanisms

### 4. Player Initialization Phase
- SharedVideoPlayer loads transferred asset
- Validate player state and readiness
- Notify MinimalTrimmerView of completion

### 5. UI Synchronization Phase
- MinimalTrimmerView responds to player readiness
- Hide loading overlays and show trimming interface
- Initialize trim range and controls

## Error Handling

### Transfer Errors
```swift
enum AssetTransferError: LocalizedError {
    case assetNotAvailable
    case assetValidationFailed(AssetValidationResult)
    case playerInitializationFailed(String)
    case transferTimeout(TimeInterval)
    case incompatibleAssetFormat(String)

    var errorDescription: String? {
        switch self {
        case .assetNotAvailable:
            return "Video asset is not available for transfer"
        case .assetValidationFailed(let result):
            return "Asset validation failed: \(result.error ?? "Unknown error")"
        case .playerInitializationFailed(let reason):
            return "Failed to initialize video player: \(reason)"
        case .transferTimeout(let duration):
            return "Asset transfer timed out after \(duration) seconds"
        case .incompatibleAssetFormat(let format):
            return "Video format '\(format)' is not supported"
        }
    }
}
```

### Recovery Strategies
1. **Retry Mechanism**: Automatic retry with exponential backoff
2. **Fallback Loading**: Alternative asset loading method
3. **User Guidance**: Clear error messages with action suggestions
4. **State Reset**: Clean recovery to previous valid state

## Diagnostic Logging

### Transfer Events
```swift
enum TransferLogEvent {
    case assetDetected(assetId: String, duration: Double)
    case transferStarted(transferId: UUID, assetSize: Int64)
    case transferProgress(transferId: UUID, progress: Double, bytesTransferred: Int64)
    case transferCompleted(transferId: UUID, duration: TimeInterval)
    case transferFailed(transferId: UUID, error: Error)
    case playerInitialized(transferId: UUID, state: PlayerState)
    case playerReady(transferId: UUID, isReady: Bool)
    case uiSynchronized(transferId: UUID, trimRange: ClosedRange<TimeInterval>)
}
```

### Logging Categories
- `🎬 AssetTransfer`: Core transfer operations
- `🔄 PlayerSync`: Player initialization and synchronization
- `📊 TransferMetrics`: Performance and progress metrics
- `🔍 Diagnostics`: Detailed debugging information
- `⚠️ TransferErrors`: Error conditions and recovery attempts

## Performance Requirements

### Transfer Timing
- **Asset Detection**: < 100ms
- **Transfer Preparation**: < 500ms
- **Asset Transfer**: < 2 seconds for videos < 100MB
- **Player Initialization**: < 3 seconds total
- **UI Synchronization**: < 100ms

### Memory Management
- **Asset Copy**: Optimize to avoid duplicate asset loading
- **Memory Peaks**: < 200MB additional memory during transfer
- **Cleanup**: Immediate cleanup of temporary transfer resources

### Error Recovery
- **First Retry**: 1 second delay
- **Second Retry**: 2 second delay
- **Final Retry**: 4 second delay
- **Total Timeout**: 30 seconds maximum transfer time

## State Validation

### Transfer Validation Checks
1. **Asset Availability**: Verify selectedVideo exists and is accessible
2. **Asset Compatibility**: Validate format, duration, and size constraints
3. **Player Readiness**: Ensure SharedVideoPlayer can accept new asset
4. **State Consistency**: Verify all components are in expected states
5. **UI Synchronization**: Confirm UI reflects transfer progress

### Validation Results
```swift
struct TransferValidationResult {
    let isValid: Bool
    let warnings: [String]
    let errors: [String]
    let recommendations: [String]

    var canProceed: Bool {
        isValid && errors.isEmpty
    }
}
```

## Integration Points

### AddMoveViewModel Integration
- Implement enhanced TrimmerViewModelProtocol
- Add asset preparation and validation methods
- Provide transfer progress reporting
- Handle transfer state management

### MinimalTrimmerView Integration
- Add asset transfer detection and initiation
- Implement enhanced loading state management
- Add progress visualization for transfer
- Handle transfer completion and error states

### SharedVideoPlayer Integration
- Add transfer-aware loading methods
- Implement enhanced error handling
- Provide detailed loading diagnostics
- Support transfer progress reporting

## Testing Requirements

### Unit Tests
- Asset validation logic
- Transfer state management
- Error handling and recovery
- Performance measurement

### Integration Tests
- AddMoveViewModel to MinimalTrimmerView transfer
- SharedVideoPlayer loading with transferred assets
- Error recovery scenarios
- Memory management during transfer

### UI Tests
- Transfer progress visualization
- Error message display
- User interaction during transfer
- Recovery option availability

## Success Criteria
1. **Functional**: All valid video assets transfer successfully
2. **Performance**: Transfer completes within specified time limits
3. **Reliability**: Graceful handling of all error conditions
4. **User Experience**: Clear progress indication and error feedback
5. **Maintainability**: Comprehensive logging and debugging support