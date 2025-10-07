# Resilient Video Loader Integration Guide

## Overview

The ResilientVideoLoader provides network-aware video loading with timeout protection, automatic retry, and comprehensive diagnostic logging. This guide explains how to integrate it into the existing AddMove workflow to resolve video loading stalls when network connectivity changes or when the Photos framework hangs on iCloud assets.

## Architecture

### Components

1. **ResilientVideoLoader** - Core network-aware loading service
2. **ResilientVideoLoaderIntegration** - Integration layer with existing architecture
3. **VideoLoadingServiceResilient** - Drop-in replacement for existing VideoLoadingService
4. **UnifiedProgressEngine** - Already enhanced with `waitingForNetwork` state

### Key Features

- **45-second timeout protection** for `PHImageManager.requestAVAsset` calls
- **Automatic retry** with exponential backoff (max 3 attempts)
- **Network path change handling** (Wi-Fi to 5G transitions)
- **Comprehensive diagnostic logging** with correlation IDs
- **Seamless integration** with existing AddMove workflow
- **WCAG AA compliant** UI feedback for network waiting states

## Integration Steps

### Step 1: Replace ImportManager Video Loading

**Before:**
```swift
// ImportManager.swift
private func requestAVAssetWithTimeout(for asset: PHAsset, options: PHVideoRequestOptions, correlationId: String) async throws -> AVAsset {
    return try await withCheckedThrowingContinuation { continuation in
        self.imageManager.requestAVAsset(forVideo: asset, options: options) { avAsset, audioMix, info in
            // Handle response without timeout protection
        }
    }
}
```

**After:**
```swift
// ImportManager.swift
private let resilientVideoService = VideoLoadingServiceResilient.createWithProgressEngine(unifiedProgressEngine)

private func requestAVAssetWithTimeout(for asset: PHAsset, options: PHVideoRequestOptions, correlationId: String) async throws -> AVAsset {
    return try await resilientVideoService.requestAVAssetWithTimeout(
        for: asset,
        options: options,
        correlationId: correlationId
    )
}
```

### Step 2: Replace AddMoveVideoLoader

**Before:**
```swift
// AddMoveVideoLoader.swift
private func performAVAssetRequest(phAsset: PHAsset, options: PHVideoRequestOptions, correlationId: String) async throws -> AVAsset {
    return try await withCheckedThrowingContinuation { continuation in
        self.imageManager.requestAVAsset(forVideo: phAsset, options: options) { avAsset, audioMix, info in
            // Handle response without network resilience
        }
    }
}
```

**After:**
```swift
// AddMoveVideoLoader.swift
private let resilientVideoService = VideoLoadingServiceResilient.createWithProgressEngine(unifiedProgressEngine)

private func performAVAssetRequest(phAsset: PHAsset, options: PHVideoRequestOptions, correlationId: String) async throws -> AVAsset {
    return try await resilientVideoService.loadAVAsset(
        phAsset: phAsset,
        options: options,
        correlationId: correlationId
    )
}
```

### Step 3: Update AddMoveUnifiedState

**Add to AddMoveUnifiedState.swift:**
```swift
// MARK: - Resilient Video Loading
private let resilientVideoService: VideoLoadingServiceResilient

public init() {
    // Initialize resilient video service
    self.resilientVideoService = VideoLoadingServiceResilient.createWithProgressEngine(unifiedProgressEngine)

    // Rest of initialization...
}

// Replace existing video loading calls:
private func loadVideoAsset(phAsset: PHAsset) async throws -> AVAsset {
    return try await resilientVideoService.loadVideoAsset(phAsset: phAsset)
}
```

### Step 4: Update LoadingOverlayView (Already Done)

The LoadingOverlayView already supports the `waitingForNetwork` state with:

- **Network status indicator** with Wi-Fi/cellular icons
- **"Waiting for network connection..."** status message
- **Automatic resume notification** when connection is restored
- **Pulsing animation** for visual feedback
- **WCAG AA compliant** colors and contrast

## State Management

### Loading Phases

The UnifiedProgressEngine already includes the enhanced state flow:

```
initializing → requestingDownload → downloadingFromCloud → [waitingForNetwork] → transferring → validating → creatingAsset → generatingThumbnail → loadingTrimmerDuration → loadingTrimmerTracks → validatingTrimmer → completed
```

### Network State Transitions

1. **Network Lost During Loading:**
   - Automatically transitions to `waitingForNetwork` phase
   - Displays "Waiting for network connection..." in UI
   - Shows network status indicator
   - Pauses current operation for retry

2. **Network Restored:**
   - Automatically resumes from `waitingForNetwork` phase
   - Continues from previous phase with retry logic
   - Maintains progress and correlation IDs

3. **Timeout Handling:**
   - 45-second timeout for `PHImageManager.requestAVAsset`
   - Automatic retry with exponential backoff
   - Detailed error reporting with diagnostics

## Error Handling

### Error Types

```swift
public enum ResilientVideoLoaderError: Error {
    case timeout(operationId: String, duration: TimeInterval)
    case networkLost(operationId: String)
    case maxRetriesExceeded(operationId: String, attempts: Int)
    case assetUnavailable(operationId: String, underlyingError: Error)
    case permissionDenied(operationId: String)
    case corruptedAsset(operationId: String, details: String)
    case cancelled(operationId: String)
    case invalidAsset(operationId: String, reason: String)
}
```

### Error Recovery

1. **Network Lost:** Automatic retry when connection restored
2. **Timeout:** Retry with exponential backoff (max 3 attempts)
3. **Permission Denied:** User intervention required
4. **Corrupted Asset:** Report error and require user action

## Diagnostic Logging

### Correlation ID Tracking

All operations include correlation IDs for end-to-end tracking:

```
RVL-A1B2C3D4: ResilientVideoLoader operation
RVI-E5F6G7H8: ResilientVideoLoaderIntegration
VLS-I9J0K1L2: VideoLoadingServiceResilient
```

### Log Categories

- `🛡️ RESILIENT_VIDEO_LOADER` - Core loading service
- `🔗 RESILIENT_INTEGRATION` - Integration layer
- `🚀 RESILIENT_VIDEO_SERVICE` - Service layer
- `🎯 DeterministicProgressEngine` - Progress tracking

### Diagnostic Information

```swift
let diagnostics = resilientVideoService.diagnosticInfo
// Returns:
// [
//   "isLoading": true,
//   "isWaitingForNetwork": false,
//   "loadingProgress": 0.65,
//   "loadingStatus": "Downloading from iCloud...",
//   "networkConnectionType": "wifi",
//   "networkQuality": "excellent",
//   "currentAttempt": 1,
//   "correlationId": "RVL-A1B2C3D4"
// ]
```

## Performance Considerations

### Memory Management

- **Automatic cleanup** of cancelled operations
- **Task cancellation** on timeout
- **Resource cleanup** in deinit
- **Weak references** to prevent retain cycles

### Network Efficiency

- **Exponential backoff** reduces server load
- **Network monitoring** with efficient path updates
- **Progressive download** support for large assets
- **Connection type awareness** for optimal settings

### Battery Optimization

- **Background task management** for long operations
- **Network quality assessment** for efficient loading
- **Timeout protection** prevents indefinite loading
- **Automatic retry** only when beneficial

## Testing

### Unit Tests

```swift
func testNetworkLossRecovery() async throws {
    let resilientService = VideoLoadingServiceResilient.createStandalone()

    // Simulate network loss during loading
    // Verify transition to waitingForNetwork
    // Verify automatic recovery when network restored
}

func testTimeoutProtection() async throws {
    let resilientService = VideoLoadingServiceResilient.createStandalone()

    // Simulate slow network response
    // Verify 45-second timeout
    // Verify automatic retry
}
```

### Integration Tests

```swift
func testAddMoveWorkflowResilience() async throws {
    let addMoveState = AddMoveUnifiedState()

    // Test complete workflow with network interruptions
    // Verify state transitions
    // Verify UI updates
    // Verify final success
}
```

## Migration Checklist

- [ ] Replace ImportManager `requestAVAssetWithTimeout` calls
- [ ] Replace AddMoveVideoLoader `performAVAssetRequest` calls
- [ ] Update AddMoveUnifiedState to use resilient service
- [ ] Verify LoadingOverlayView displays network waiting state
- [ ] Test network loss and recovery scenarios
- [ ] Verify timeout protection works
- [ ] Check diagnostic logging output
- [ ] Update unit tests for new architecture
- [ ] Verify WCAG AA compliance for network waiting UI

## Troubleshooting

### Common Issues

1. **Stuck at 99% Progress:**
   - Ensure `validatingTrimmer` phase maps to 1.0 progress
   - Check UnifiedProgressEngine terminal state handling
   - Verify ResilientVideoLoader completion logic

2. **Network Recovery Not Working:**
   - Verify network monitoring setup
   - Check `waitingForNetwork` phase handling
   - Ensure correlation IDs are maintained across retries

3. **Timeout Not Triggering:**
   - Verify 45-second timeout configuration
   - Check task cancellation logic
   - Ensure timeout task is properly created

4. **UI Not Updating:**
   - Verify LoadingOverlayView bindings
   - Check unified progress engine state
   - Ensure @MainActor isolation for UI updates

### Debug Information

```swift
// Enable comprehensive logging
resilientVideoService.logDiagnostics()

// Check network state
let networkInfo = resilientVideoService.diagnosticInfo
print("Network Available: \(networkInfo["isNetworkAvailable"] ?? false)")
print("Connection Type: \(networkInfo["networkConnectionType"] ?? "unknown")")

// Monitor progress engine state
let progressInfo = unifiedProgressEngine.diagnosticInfo
print("Current Phase: \(progressInfo["currentPhase"] ?? "none")")
print("Progress: \(progressInfo["deterministicProgress"] ?? 0.0)")
```

## Conclusion

The ResilientVideoLoader integration provides comprehensive network resilience for video loading operations while maintaining compatibility with the existing AddMove architecture. The implementation follows iOS 18 best practices, includes comprehensive error handling, and provides excellent user experience during network interruptions.

Key benefits:
- **Eliminates 99% stuck issues** with timeout protection
- **Handles network transitions** gracefully (Wi-Fi to 5G)
- **Provides clear user feedback** during network waiting
- **Maintains diagnostic visibility** with correlation IDs
- **Follows accessibility guidelines** for UI feedback
- **Preserves existing architecture** with minimal changes