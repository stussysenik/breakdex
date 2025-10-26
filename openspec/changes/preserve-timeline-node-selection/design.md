# Design: Preserve Timeline Node Selection

## Architecture Overview

### Current State Management Flow
1. **ComboDetailView** maintains `selectedMoveIndex` state
2. **ComboTimelineView** receives `activeIndex` binding
3. On view appearance, `ComboTimelineView.handleViewAppear()` auto-selects first move if `activeIndex == nil`
4. **ComboDetailView.restoreTimelineNodeState()** attempts to restore preserved selection

### Problem Flow
1. User selects timeline node → `selectedMoveIndex` updated
2. User enters fullscreen video → view lifecycle events trigger
3. User exits fullscreen video → `ComboTimelineView.onAppear` called again
4. `handleViewAppear()` auto-selects first move, overriding preserved selection
5. User sees incorrect selection (first node instead of original)

### Solution Design

#### Enhanced Selection State Logic
Modify `ComboTimelineView.handleViewAppear()` to implement smarter selection logic:

1. **Preserve Existing Selection**: If `activeIndex` has a valid value, keep it
2. **Smart Auto-Selection**: Only auto-select first move when truly needed
3. **Validation**: Ensure selected index is within valid bounds
4. **Logging**: Add detailed logging for debugging selection state

#### State Validation
- Check if `activeIndex` exists and is valid
- Verify `moves.count > 0` before attempting selection
- Validate index bounds before setting selection

#### View Lifecycle Coordination
- Ensure `ComboDetailView` restoration logic runs before `ComboTimelineView` appearance logic
- Add proper sequencing to prevent race conditions
- Maintain backward compatibility with existing behavior

## Implementation Strategy

### Phase 1: Analysis & Logging
- Add comprehensive logging to understand current state flow
- Identify exact timing of view lifecycle events
- Validate root cause hypothesis

### Phase 2: Core Fix
- Modify `ComboTimelineView.handleViewAppear()` logic
- Add selection validation and preservation
- Implement smarter auto-selection criteria

### Phase 3: Testing & Validation
- Test selection persistence across fullscreen transitions
- Verify edge cases (empty moves, invalid indices)
- Ensure no regressions in existing functionality

## Technical Considerations

### State Synchronization
- `@Binding` mechanism ensures state consistency between views
- View appearance timing may vary based on iOS version
- Need to handle both initial load and subsequent appearances

### Edge Cases
- Empty moves array should not cause crashes
- Invalid indices should be handled gracefully
- Concurrent state updates should be atomic

### Performance Impact
- Minimal performance overhead from additional validation
- Logging can be controlled via log levels
- No additional memory allocations required

## Risk Mitigation

### Backward Compatibility
- Existing auto-selection behavior preserved for new combos
- No breaking changes to public API
- Maintains current user experience for unaffected flows

### Testing Strategy
- Unit tests for selection logic edge cases
- Integration tests for fullscreen video transitions
- UI tests for complete user workflows

### Rollback Plan
- Simple one-line change that can be easily reverted
- No architectural changes required
- Clear before/after behavior for validation