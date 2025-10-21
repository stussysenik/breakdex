# Video Player Consistency Design

## Category Theory Analysis

### Current Broken Functor
```
Move.rotationQuarterTurns ──► NameMoveView.AVPlayer ──X─► Display
                                  │
                                  ▼
                            (rotation ignored)
```

### Fixed Functor
```
Move.rotationQuarterTurns ──► SharedVideoPlayer ──► RotatedDisplay
```

## Video Player Architecture

### SharedVideoPlayer Advantages
1. **Rotation Awareness**: Handles AVPlayerLayer transforms automatically
2. **State Management**: Consistent loading, playing, and error states
3. **Memory Management**: Proper cleanup and resource management
4. **Testing**: Unified interface for unit testing
5. **Performance**: Optimized asset loading and caching

### Raw AVPlayer Problems
1. **Rotation Blind**: No awareness of rotation metadata
2. **State Fragmentation**: Inconsistent loading and error handling
3. **Memory Leaks**: Improper cleanup patterns
4. **Testing Complexity**: Different implementations require separate test paths
5. **User Experience**: Videos display incorrectly or are unclickable

## Implementation Strategy

### Phase 1: Fix NameMoveView Video Player
- Replace raw AVPlayer creation with SharedVideoPlayer
- Pass rotation metadata from AddMoveViewModel to SharedVideoPlayer
- Maintain existing video preview functionality

### Phase 2: Verify MoveDetailView Consistency
- Ensure MoveDetailView uses SharedVideoPlayer properly
- Add rotation metadata validation logging
- Test video clickability and playback

### Phase 3: Fix Navigation Flow
- Resolve AddMoveView disappearing after save
- Ensure proper return to Arsenal tab with new move visible
- Add navigation state validation

## Technical Details

### Rotation Metadata Flow
1. **TrimModification** → rotation property
2. **AddMoveViewModel** → updateTrimModification() sets rotation
3. **NameMoveView** → passes rotation to SharedVideoPlayer
4. **SharedVideoPlayer** → applies AVPlayerLayer transform
5. **Display** → correctly rotated video

### Video Player Creation Pattern
```swift
// ❌ Current (Broken)
let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
AVPlayerViewRepresentable(player: player)

// ✅ Fixed
let sharedPlayer = SharedVideoPlayer(mode: .preview)
await sharedPlayer.loadVideo(asset)
// Apply rotation metadata if available
```

### Navigation Fix Pattern
```swift
// Ensure proper state management after save
if saveState.isSaved && currentStep == .naming {
    currentStep = .complete
    selectedTab = 0  // Return to Arsenal
    // Reset view state for next use
}
```

## Validation Strategy

### Evidence Collection
- Enhanced logging proves video player creation paths
- Rotation metadata flow validation
- User interaction tracking for video clicks
- Navigation state confirmation

### Success Criteria
1. All videos display with correct rotation
2. All videos are clickable and playable
3. Add move workflow completes successfully
4. Users return to Arsenal tab after saving moves
5. New moves appear immediately in Arsenal list