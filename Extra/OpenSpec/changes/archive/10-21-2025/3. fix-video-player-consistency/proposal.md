## Why

Critical video playback issues are breaking the core user experience:

1. **Video Player Inconsistency**: NameMoveView creates raw AVPlayer instances that ignore rotation metadata, while MoveDetailView uses SharedVideoPlayer. This breaks the video display functor where rotation data should flow consistently from storage to display.

2. **MoveListView Navigation Failure**: Users cannot access MoveDetailView after tapping moves in MoveListView. The NavigationLink fails to trigger, preventing users from viewing move details or playing videos entirely.

3. **AddMoveView Disappears After Save**: The add move workflow creates a dead-end state where the view disappears instead of returning users to the Arsenal tab to see their newly created moves.

Evidence from enhanced logging (logs 7. logs.md) proves:
- Line 809-810: NameMoveView creates `AVPlayer (raw), NOT SharedVideoPlayer - rotation may be ignored`
- Rotation data exists (`Available rotation: 90°`) but is ignored by raw AVPlayer
- Multiple ViewModel recreation cycles causing performance issues

## What Changes

- **BREAKING**: Standardize all video player creation to use SharedVideoPlayer across the entire application
- Fix MoveListView NavigationLink to properly trigger MoveDetailView navigation
- Fix NameMoveView to use SharedVideoPlayer with proper rotation handling instead of raw AVPlayer
- Verify MoveDetailView loads and displays correctly when accessed via NavigationLink
- Fix AddMoveView post-save navigation to properly return to Arsenal tab
- Add navigation flow validation logging to identify NavigationLink failure points
- Implement consistent video player state management across all views

## Impact

- **Affected specs**: video-player-consistency, move-workflow-navigation, rotation-metadata-flow
- **Affected code**: NameMoveView.swift, MoveDetailView.swift, AddMoveView.swift, SharedVideoPlayer.swift
- **User experience**: Videos display with correct rotation, clickable move list items, complete add move workflow
- **Production reliability**: Consistent video playback behavior across all features
- **Architecture improvement**: Single source of truth for video player implementation

## Evidence from Analysis

**Video Player Creation Evidence:**
```
🔄 ROTATION_PROOF: NameMoveView created AVPlayer - Available rotation: 90°
🎬 VIDEO_PLAYER_PROOF: Player type=AVPlayer (raw), NOT SharedVideoPlayer - rotation may be ignored
```

**Navigation Evidence:**
- Tab navigation binding works correctly (proven by logs)
- AddMoveView disappears after save (confirmed by user testing)
- Users tap moves (Lines 38-40: "📋 MOVE_LIST_VIEW: 👆 Tapped move: hello") but MoveDetailView never appears
- No MoveDetailView loading evidence in logs, confirming NavigationLink failure

**Research Validation:**
- Apple docs confirm AVPlayerLayer requires proper transform handling for rotation
- Production best practices favor consistent video player architecture
- SwiftUI + AVFoundation integration works best through unified player management

## Architecture Readiness

**SharedVideoPlayer Infrastructure**: ✅ **Fully Implemented**
- Complete rotation-aware video player with mode management
- Proper AVPlayerLayer integration with transform support
- Clean async/await pattern for video loading

**Core Data Rotation Storage**: ✅ **Fully Implemented**
- Move.rotationQuarterTurns property stores rotation metadata
- Rotation flows from TrimModification through Move entity to display

**Video Loading Pipeline**: ✅ **Fully Implemented**
- RobustVideoLoader and PhotosAssetLoader provide consistent asset loading
- SharedVideoPlayer.loadVideo() handles rotation metadata properly

**Missing Connection**: ❌ **Inconsistent Video Player Usage**
- NameMoveView bypasses SharedVideoPlayer infrastructure
- Raw AVPlayer creation ignores rotation metadata
- Breaks the commutative diagram from storage to display