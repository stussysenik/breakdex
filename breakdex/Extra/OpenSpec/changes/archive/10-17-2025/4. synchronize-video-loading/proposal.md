# Synchronize Video Loading: Single AddMoveViewModel Architecture

## Why
The video loading flow gets stuck at 10% progress due to MVVM and SRP violations that create a critical user experience bottleneck. Users cannot proceed with adding moves because the UI freezes at "initializing video player" due to separate SharedVideoPlayer instances that cannot synchronize the loaded asset.

## Problem Statement

The video loading flow gets stuck at 10% progress due to **MVVM and SRP violations** in the current architecture:

1. **AddMoveViewModel** loads the video asset successfully
2. **MinimalTrimmerView** creates a **separate SharedVideoPlayer instance** via TrimmerViewModelProtocol
3. **Asset transfer bottleneck** occurs where `waitForPlayerReadiness()` waits indefinitely for a player that never becomes ready

The UI freezes at "initializing video player" because two different SharedVideoPlayer instances can't synchronize the loaded asset.

## Root Cause Analysis

The issue stems from **architectural violations** in the current design:

**MVVM Violations:**
- **TrimmerViewModelProtocol** creates unnecessary abstraction between View and ViewModel
- Views are doing too much work (asset detection, transfer logic, error handling)

**SRP Violations:**
- AddMoveViewModel handling both business logic AND asset transfer logistics
- SharedVideoPlayer handling both playback AND transfer management

**Current Flow:**
1. User selects video → AddMoveViewModel loads AVAsset into internal player ✅
2. AddMoveView transitions to trimming step → Shows MinimalTrimmerView ✅
3. MinimalTrimmerView creates NEW SharedVideoPlayer instance ❌
4. `setupTrimmerWithGuard()` tries to transfer asset to new player ❌
5. `waitForPlayerReadiness()` waits indefinitely for separate player ❌

## What Changes

- **Remove TrimmerViewModelProtocol** completely - eliminates unnecessary abstraction
- **Move SharedVideoPlayer to AddMoveViewModel** - single instance eliminates transfer bottleneck
- **Update MinimalTrimmerView** to use AddMoveViewModel directly - no protocol dependency
- **Simplify all Add Move views** to be "dumb" UI components only
- **Add enhanced diagnostic logging** for complete flow tracking

## Proposed Solution

Implement **clean MVVM architecture** with single SharedVideoPlayer instance:

1. **Single AddMoveViewModel Architecture** - Remove TrimmerViewModelProtocol completely
2. **Direct Player Sharing** - SharedVideoPlayer loaded once in AddMoveViewModel
3. **Clean View Architecture** - Views are "dumb" and observe AddMoveViewModel directly
4. **Enhanced Diagnostic Logging** - Track the complete flow with proper logging

## Success Criteria

- ✅ Video displays immediately when transitioning to trimming step (no 10% freeze)
- ✅ Single SharedVideoPlayer instance eliminates asset transfer bottleneck
- ✅ AddMoveViewModel manages entire add move flow (loading, trimming, naming)
- ✅ Views are "dumb" and only handle UI, no business logic
- ✅ Follows MVVM and SRP principles as validated by 2025 SwiftUI best practices
- ✅ No TrimmerViewModelProtocol complexity

## Impact Assessment

**User Experience:**
- Eliminates 10% UI freeze completely
- Smooth transition from video selection to trimming
- Immediate video display in trimming interface
- Clear error handling and recovery

**Technical Impact:**
- Removes complex asset transfer logic
- Single source of truth for video playback state
- Simplified architecture following MVVM principles
- Enhanced diagnostic logging for debugging

**Risk Level: Very Low**
- Architectural simplification (removing complexity)
- No asset transfer needed (eliminates bottleneck)
- Follows established SwiftUI patterns
- Preserves all existing functionality

## Architecture Benefits

**MVVM Compliance:**
- ✅ AddMoveViewModel as single ViewModel for entire flow
- ✅ Views observe AddMoveViewModel directly (no protocols)
- ✅ Clear separation between UI and business logic

**SRP Compliance:**
- ✅ AddMoveViewModel: Manages add move business logic and state
- ✅ MinimalTrimmerView: UI presentation only
- ✅ SharedVideoPlayer: Video playback only
- ✅ No mixed responsibilities