## Why

Video loading gets stuck at 94% because SharedVideoPlayer has two separate execution paths that both set `state = .ready` within the same UI frame, causing SwiftUI's change detection system to throttle subsequent state updates and break the state propagation chain to the UI.

## Problem Statement

**ROOT CAUSE**: Two separate code paths execute simultaneously during video loading:
1. `loadVideo()` → `finalizeVideoLoad()` → sets `state = .ready`
2. `loadVideo()` → `setupPlayerObservers()` → `handlePlayerItemStatusChange(.readyToPlay)` → `finalizePlayerReadyState()` → sets `state = .ready`

**EVIDENCE FROM LOGS**:
- Line 69: `"onChange(of: LoadingState) action tried to update multiple times per frame"`
- Lines 95-96: Two separate `state = .ready` updates within 0.088ms
- Lines 105-111: AddMoveViewModel's 95% → 99% → 100% updates are ignored by SwiftUI due to the collision

**ARCHITECTURAL ISSUE**: The dual execution paths violate the single responsibility principle. Both `finalizeVideoLoad()` and `finalizePlayerReadyState()` attempt to set the same final state, creating a race condition that cascades to other ViewModels and breaks SwiftUI's observation system.

## What Changes

- **MODIFIED**: `SharedVideoPlayer.swift:finalizeVideoLoad()` - Add atomic state guard to prevent dual execution
- **MODIFIED**: `SharedVideoPlayer.swift:finalizePlayerReadyState()` - Add atomic state guard to prevent dual execution
- **ADDED**: Centralized state coordination to ensure only one path sets final state
- **ADDED**: Enhanced diagnostic logging with atomic timing verification
- **MAINTAINED**: All existing VideoPlayer API contracts and behavior
- **MAINTAINED**: iOS 18 @MainActor compliance for atomic state updates

## Impact

- **Affected specs**: video-player (state update timing, dual execution prevention)
- **Affected code**:
  - `breakdex/Features/Shared/Video/VideoPlayer.swift:finalizeVideoLoad()`
  - `breakdex/Features/Shared/Video/VideoPlayer.swift:finalizePlayerReadyState()`
  - `breakdex/Features/Shared/Video/VideoPlayer.swift:handlePlayerItemStatusChange()`
- **Breaking changes**: None - preserves existing VideoPlayer interface
- **User impact**: Video loading reliably completes to 100% without freezing at 94%
- **Performance impact**: Eliminates redundant state setting and SwiftUI throttling overhead