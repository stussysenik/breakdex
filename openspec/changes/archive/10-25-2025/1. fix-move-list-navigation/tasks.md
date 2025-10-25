# Fix Move List Navigation Tasks

## Tasks (ordered)

1. **Replace List with LazyVStack in MoveListView** ✅
   - [x] Update MoveListView.swift movesList view (lines 162-183)
   - [x] Replace `List(viewModel.filteredMoves)` with `ScrollView { LazyVStack }`
   - [x] Preserve `listRowBackground` and `listRowSeparator` styling
   - [x] Test visual appearance matches current design

2. **Remove investigation logging from BreakingArsenalView** ✅
   - [x] Remove control test logging from Combo NavigationLink (lines 36-50)
   - [x] Restore original clean Combo NavigationLink implementation
   - [x] Verify Combo navigation still works as control test

3. **Remove investigation logging from MoveDetailView** ✅
   - [x] Remove enhanced debug logging from onAppear (lines 47-50)
   - [x] Keep essential MoveDetailView.onAppear logging for production
   - [x] Verify navigation success logging works

4. **Test navigation functionality** ✅
   - [x] Tap on move "yes" and verify MoveDetailView appears
   - [x] Confirm MoveDetailView.onAppear logs execute
   - [x] Test video loading and playback in MoveDetailView
   - [x] Verify back navigation works correctly

5. **Validate scroll and search functionality** ✅
   - [x] Test scroll performance with LazyVStack
   - [x] Verify search filtering works unchanged
   - [x] Test swipe actions for move deletion
   - [x] Confirm selection haptics still trigger

6. **Build verification** ✅
   - [x] Run `xcodebuild -project breakdex.xcodeproj -scheme breakdex build`
   - [x] Verify no compilation errors
   - [x] Test on iOS Simulator (iPhone 16)
   - [x] Confirm no UI flicker or layout issues

## Dependencies

- Must preserve existing visual design exactly
- Must maintain all current functionality
- Must not affect other navigation flows (Add Move, Combos, Review)
- Must keep same performance or better

## Validation

- MoveDetailView appears when tapping any move
- Enhanced logs show navigation chain success
- Visual appearance identical to current List design
- No performance regression in scrolling or search