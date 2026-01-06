# Tasks: Preserve Timeline Node Selection

## Task 1: Add Comprehensive Logging
**Description:** Add detailed logging to ComboTimelineView and ComboDetailView to track selection state changes and view lifecycle events.

**Implementation:**
- Add logging to `ComboTimelineView.handleViewAppear()` to log current selection state
- Add logging to `handleNodeTap()` to log user-initiated selection changes
- Add logging to `handleActiveIndexChange()` to log binding updates
- Add logging to `ComboDetailView.restoreTimelineNodeState()` to log restoration attempts

**Validation:**
- Verify logs appear when timeline nodes are selected
- Verify logs appear when view appears/disappears
- Check log content includes relevant selection details

## Task 2: Implement Enhanced Selection Logic
**Description:** Modify `ComboTimelineView.handleViewAppear()` to preserve existing selections and implement smarter auto-selection.

**Implementation:**
- Update `handleViewAppear()` to check for valid existing selection before auto-selecting
- Add validation to ensure selected index is within `moves.indices`
- Add logging for selection validation results
- Preserve existing auto-selection behavior for truly empty selections

**Code Changes:**
```swift
private func handleViewAppear() {
    logger.info("🎯 COMBO_TIMELINE_VIEW: Timeline view appeared with \(moves.count) moves")

    // Log current selection state
    if let currentIndex = activeIndex {
        logger.info("🎯 COMBO_TIMELINE_VIEW: Existing selection found at index \(currentIndex)")
        if moves.indices.contains(currentIndex) {
            logger.info("🎯 COMBO_TIMELINE_VIEW: Preserving valid selection at index \(currentIndex)")
            return
        } else {
            logger.warning("🎯 COMBO_TIMELINE_VIEW: Invalid selection index \(currentIndex), resetting to 0")
        }
    }

    // Auto-select first move only if no valid selection exists
    if !moves.isEmpty {
        logger.info("🎯 COMBO_TIMELINE_VIEW: Auto-selecting first move")
        activeIndex = 0
    }
}
```

**Validation:**
- Test with existing selection - should preserve selection
- Test with invalid selection - should reset to 0
- Test with empty moves - should handle gracefully
- Test initial load - should auto-select first move

## Task 3: Test Fullscreen Video Transition
**Description:** Test the fix with actual fullscreen video transitions to ensure selection persistence works correctly.

**Test Scenarios:**
1. Select timeline node, enter fullscreen video, exit - selection should persist
2. Select different nodes, repeat fullscreen cycles - selection should persist
3. Test with various move combinations - selection should persist
4. Test edge cases (empty combo, single move) - should handle gracefully

**Validation:**
- Manual testing on device/simulator
- Verify selection remains after fullscreen exit
- Verify video preview shows correct move after fullscreen exit
- Check logs confirm selection persistence

## Task 4: Add Unit Tests
**Description:** Create unit tests for the new selection logic to ensure robustness and prevent regressions.

**Test Cases:**
- `testPreserveExistingSelection()` - existing selection should be preserved
- `testAutoSelectWhenNoSelection()` - should auto-select first move when none exists
- `testHandleInvalidSelection()` - should reset to 0 when selection is invalid
- `testEmptyMovesArray()` - should handle empty moves gracefully
- `testViewAppearMultipleTimes()` - should handle repeated appearances correctly

**Implementation:**
- Create testable version of ComboTimelineView
- Mock moves array and selection binding
- Test various selection scenarios
- Verify logging behavior

## Task 5: Integration Testing
**Description:** Perform end-to-end testing of the complete user workflow to ensure no regressions.

**Test Workflow:**
1. Open combo detail view
2. Select timeline node
3. Verify video preview updates
4. Enter fullscreen video
5. Exit fullscreen video
6. Verify timeline selection persists
7. Verify video preview shows correct move
8. Repeat with different nodes

**Validation:**
- Complete workflow testing on device
- Verify no performance regressions
- Check memory usage during transitions
- Ensure smooth UI transitions

## Task 6: Documentation Update
**Description:** Update code comments and documentation to reflect the new selection behavior.

**Updates:**
- Add comments to `handleViewAppear()` explaining the selection logic
- Update method documentation if needed
- Add inline comments for complex validation logic
- Update any relevant README or documentation files

## Dependencies
- Task 1 must be completed before Task 2 (logging needed for debugging)
- Task 2 must be completed before Task 3 (fix needed before testing)
- Task 4 and Task 5 can be done in parallel after Task 2
- Task 6 should be done after all implementation tasks are complete

## Risk Mitigation
- Keep Task 2 changes minimal and focused
- Test thoroughly before committing changes
- Have rollback plan ready (simple revert of handleViewAppear logic)
- Monitor for any performance impact from additional logging