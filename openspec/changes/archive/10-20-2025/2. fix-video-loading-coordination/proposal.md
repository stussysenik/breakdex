## Why
The breakdex iOS app gets stuck at 88% video loading and displays a black screen in the trimming interface instead of the loaded video content. This critical bug prevents users from creating flashcards from video content, which is the core functionality of the app.

## What Changes
- Fix missing coordination step between video asset loading and SharedVideoPlayer initialization
- Add proper async/await coordination in SelectClip.fullyReady case to ensure SharedVideoPlayer.loadVideo() is called before transitioning to trimming
- Implement proper error handling and state validation for player initialization
- Add minimal diagnostic logging for future debugging and monitoring
- Ensure single responsibility principle - SelectClip handles coordination, not initialization

**BREAKING**: None - this is a bug fix that restores intended functionality

## Impact
- **Affected specs**: video-loading (new capability for coordination requirements)
- **Affected code**:
  - `Features/AddMove/Views/SelectClip.swift:176` (handleLoadingStateChange fullyReady case)
  - Uses existing `Features/Shared/Video/VideoPlayer.swift:123` (SharedVideoPlayer.loadVideo method)
- **User impact**: Fixes complete blocker for core app functionality
- **Technical impact**: Restores proper async coordination between loading pipeline and video player
- **Risk**: Low - uses existing, well-tested SharedVideoPlayer.loadVideo() method

## Evidence-Based Root Cause Analysis
Based on diagnostic logging evidence (lines 314-320), the issue is a coordination gap:
- LoadingState.fullyReady(AVAsset) ✅ - Video asset successfully loaded
- videoPlayer.state = idle ❌ - SharedVideoPlayer never initialized with asset
- videoPlayer.isReady = false ❌ - Player not ready for playback
- videoPlayer.duration = 0.0s ❌ - No asset loaded in player
- "Has SharedVideoPlayer been initialized with asset? false" ❌

The app incorrectly transitions to trimming before initializing the SharedVideoPlayer with the loaded asset, causing a black screen and non-functional trimming interface.

## Production Practices
- Use MainActor for all AVPlayer operations (existing SharedVideoPlayer already follows this)
- Use async/await pattern for player loading (existing method supports this)
- Handle success/failure states appropriately with proper error propagation
- Prevent duplicate initialization calls through state validation
- Follow single responsibility principle - coordination vs initialization separation