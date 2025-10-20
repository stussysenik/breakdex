# Synchronize Video Loading: Single AddMoveViewModel Architecture

## Why
The video loading system successfully completes (logs show 100% progress and SharedVideoPlayer initialization), but the MinimalTrimmerView creates a separate SharedVideoPlayer instance that never receives the loaded AVAsset. This causes the UI to freeze at 10% with the user stuck on "initializing video player" instead of proceeding to video trimming, creating a critical blocker for the core add move workflow.

## Problem
**Root Cause**: MVVM and SRP violations in current architecture. AddMoveViewModel loads the video asset, but MinimalTrimmerView creates its own SharedVideoPlayer instance via unnecessary TrimmerViewModelProtocol abstraction. This creates a player synchronization bottleneck where `waitForPlayerReadiness()` waits indefinitely for a player that never becomes ready.

**Key Issues**:
1. **MVVM Violation**: TrimmerViewModelProtocol creates unnecessary abstraction between View and ViewModel
2. **SRP Violation**: Complex asset transfer logic mixed with UI concerns
3. **Separate Player Instances**: AddMoveViewModel and MinimalTrimmerView use different SharedVideoPlayer instances
4. **Asset Transfer Complexity**: Need to transfer asset between components instead of sharing directly

## Current Behavior
- AddMoveViewModel loads video successfully (logs show 100% completion)
- AddMoveView transitions from `.selecting` to `.trimming` step
- MinimalTrimmerView appears and creates new SharedVideoPlayer instance via TrimmerViewModelProtocol
- `setupTrimmerWithGuard()` calls `waitForPlayerReadiness()` for separate player instance
- User interface freezes at "initializing video player" (10% progress)
- No further state transitions occur, user must force-quit the app

## Desired Behavior
- AddMoveViewModel loads video directly into its own SharedVideoPlayer instance
- AddMoveView transitions from `.selecting` to `.trimming` step
- MinimalTrimmerView immediately uses the existing loaded SharedVideoPlayer
- Video displays instantly in trimming interface
- Smooth transition from loading (10%) to trimming (100%) progress
- No asset transfer needed - single source of truth

## Solution
Implement clean MVVM architecture with single SharedVideoPlayer instance:

### 1. Single AddMoveViewModel Architecture
- Move SharedVideoPlayer instance into AddMoveViewModel
- Remove TrimmerViewModelProtocol abstraction completely
- AddMoveViewModel manages all add move flow state (loading, trimming, naming)
- MinimalTrimmerView directly observes AddMoveViewModel

### 2. Direct Player Sharing
- SharedVideoPlayer loaded once in AddMoveViewModel during video selection
- MinimalTrimmerView uses `viewModel.videoPlayer` directly
- No asset transfer or synchronization needed
- Single source of truth for video playback state

### 3. Clean View Architecture
- SelectClip: "Dumb" view that forwards video selection to AddMoveViewModel
- MinimalTrimmerView: Uses `viewModel.videoPlayer` and binds trim state directly
- NameMoveView: Binds to AddMoveViewModel properties for move details
- All views are simple UI with no business logic

### 4. Enhanced Diagnostic Logging
- Add detailed logging for video loading directly into AddMoveViewModel.player
- Track player state transitions with timestamps
- Log trim range updates and user interactions
- Add performance metrics for initialization timing

## Implementation Details

### Enhanced TrimmerViewModelProtocol
```swift
@MainActor
protocol TrimmerViewModelProtocol: ObservableObject {
    var selectedVideo: AVAsset? { get }
    var videoAssetReady: Bool { get }
    func transferVideoAsset(to player: SharedVideoPlayer) async throws
}
```

### Improved MinimalTrimmerView Initialization
- Add `@State private var assetTransferTask: Task<Void, Never>?`
- Implement `setupVideoPlayerWithAsset()` method with proper error handling
- Add `retryAssetTransfer()` mechanism for failed transfers
- Implement timeout handling with user feedback

### Enhanced Diagnostic Logging
- Log asset transfer start/completion/failure with timestamps
- Track SharedVideoPlayer state transitions in detail
- Add performance metrics (loading time, transfer time, etc.)
- Log user interaction points for debugging

## Impact
- **Critical Fix**: Resolves core blocker preventing users from adding moves
- **User Experience**: Eliminates app freeze and provides smooth workflow
- **Performance**: Removes indefinite wait states and improves perceived speed
- **Reliability**: Adds robust error handling and recovery mechanisms

## Verification
Test with various video formats and loading scenarios:
- Standard MP4 videos from camera roll
- Large iCloud videos requiring download
- Different video lengths (5s to 60s)
- Edge cases: corrupted files, network failures, permission denied
- Performance testing: asset transfer should complete within 2 seconds
- Error recovery: graceful handling of transfer failures with retry options

## Success Metrics
- Video displays in trimming interface within 2 seconds of loading completion
- Zero app freezes or indefinite loading states
- 100% success rate for valid video assets
- Clear error messages for invalid assets
- Smooth user experience from selection to trimming