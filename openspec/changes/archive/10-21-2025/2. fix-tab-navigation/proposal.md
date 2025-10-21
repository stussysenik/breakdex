## Why

The add move workflow is completing successfully but cannot navigate back to the Arsenal tab after saving a move. The navigation binding between MainView and AddMoveView is broken, creating a dead-end state where users remain stuck on the complete screen instead of returning to the main move collection.

Additionally, the Arsenal tab currently shows only an "ADD MOVE" button and doesn't display the actual move list, creating a disconnected user experience where newly added moves are not immediately visible.

## What Changes

- **BREAKING**: Replace immutable TabView binding with mutable binding in MainView
- Fix MainView.AddMoveView to pass `$selectedTab` instead of `.constant(.add)`
- Update AddMoveView to use Int binding instead of TabSelection enum
- **CRITICAL**: Integrate MoveListView into BreakingArsenalView for immediate move visibility
- Add NameMoveView .light color scheme support
- Ensure rotation inheritance from trimming to naming view
- Add minimal diagnostic logging for navigation debugging
- Update BreakingArsenalView navigation architecture to show moves directly

## Impact

- **Affected specs**: tab-navigation, add-move-workflow, arsenal-view-integration
- **Affected code**: MainView.swift, AddMoveView.swift, BreakingArsenalView.swift, NameMoveView.swift
- **User experience**: Complete add move workflow with automatic return to Arsenal tab showing new move immediately
- **Production reliability**: Eliminates navigation dead-end states and provides immediate feedback
- **Architecture improvement**: Proper MVVM integration with Arsenal components

## Evidence from Logs

Comprehensive diagnostic logging has proven:
1. Video loading and player coordination works perfectly (reaches ready state successfully)
2. Trimming workflow functions correctly (transitions ready → trimming → naming)
3. Move saving completes successfully (Core Data persistence works - Line 825: "✅ Move saved successfully: Yess")
4. **Root cause**: `selectedTab` binding is immutable (terminal object) preventing navigation back to Arsenal tab
5. **Critical gap**: BreakingArsenalView only shows "MOVE" button, no move list integration

The logs show explicit proof of the navigation binding failure:
- MainView passes `.constant(.add)` (immutable binding) to AddMoveView (Line 883)
- AddMoveView expects mutable binding but cannot modify `selectedTab = 0` to return to Arsenal tab
- This creates a "terminal object" in the navigation flow - a black hole where information enters but cannot exit
- User manually navigates tabs (Lines 886, 895) but automatic navigation fails

## Arsenal Infrastructure Readiness

**MoveListView.swift**: ✅ **Fully implemented**
- Complete list display with search functionality
- NavigationLink to MoveDetailView (Line 202)
- Integration with ArsenalViewModel for Core Data fetching

**MoveDetailView.swift**: ✅ **Fully implemented**
- Complete video playback with SharedVideoPlayer
- Proper video loading pipeline (Lines 165-217)
- Handles rotation, trimming, errors gracefully

**BreakingArsenalView.swift**: ❌ **Incomplete integration**
- Only shows "MOVE" button (Lines 21-28)
- Missing MoveListView integration
- Creates disconnected user experience