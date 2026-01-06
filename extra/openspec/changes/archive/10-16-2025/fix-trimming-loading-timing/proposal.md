## Why
The trimming functionality suffers from critical timing issues where the loading indicator gets stuck indefinitely, even after successful video loading. Based on comprehensive log analysis, the root cause is Swift Task Continuation misuse combined with race conditions between video player initialization and UI state transitions. This creates a poor user experience where "The Athlete" persona cannot reliably access the trimming interface regardless of video loading success.

## What Changes
- Fix Swift Task Continuation leaks in VideoPlayer waitForPlayerReady method
- Resolve race conditions between MinimalTrimmerView onAppear and SharedVideoPlayer initialization
- Implement proper state synchronization guards to prevent multiple redundant player setups
- Add loading state coordination between UnifiedState and actual player ready state
- Ensure deterministic transition from loadingVideo to trimming flow state
- Maintain existing performance optimizations and clean architecture principles

## Impact
- Affected specs: `video-loading-state-management` (new capability)
- Affected code:
  - `breakdex/Features/Shared/Video/VideoPlayer.swift` (continuation fixes)
  - `breakdex/Features/Shared/Video/MinimalTrimmerView.swift` (timing guards)
  - `breakdex/Features/Shared/Models/UnifiedState.swift` (state sync)
- User experience: Reliable, deterministic access to trimming interface
- Performance: Eliminates redundant player initialization cycles
- Stability: Prevents task continuation leaks and memory issues