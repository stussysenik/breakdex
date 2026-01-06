# Fix Navigation Flow Proposal

## Why

Users cannot complete the Add Move workflow due to broken navigation between steps. The video trimmer doesn't advance to the naming screen, and the naming screen doesn't return to the move list after saving. This creates a frustrating user experience where the core feature (creating video flashcards) cannot be completed.

## Summary

Fix broken navigation flow in Add Move feature where users cannot progress from video trimming to move naming, and from saving to move list display. The issue stems from missing state observers in the workflow coordinator.

## Problem Statement

**Current Broken Behavior:**
1. User trims video in MinimalTrimmerView and hits "Submit" → No navigation occurs
2. User names move in NameMoveView and saves → No return to Arsenal/moves list

**Root Cause Analysis:**
- AddMoveView only observes `loadingState` (lines 114-128)
- Missing observer for `currentTrimModification` changes
- Save completion doesn't emit observable state for navigation
- Dual state management violates MVVM (NameMoveView uses separate MoveSaver)

## Files Affected

- `Features/AddMove/Views/AddMoveView.swift` - Add missing state observers
- `Features/AddMove/ViewModels/AddMoveViewModel.swift` - Add save state management
- `Features/AddMove/Views/NameMoveView.swift` - Fix MVVM violation

## Implementation Approach

### Phase 1: Add Missing State Observer
Add `.onChange(of: viewModel.currentTrimModification)` in AddMoveView to detect trim completion and transition to naming step.

### Phase 2: Fix MVVM Violation
Move save logic from NameMoveView's MoveSaver into AddMoveViewModel with proper `@Published` state tracking.

### Phase 3: Add Save Completion Observer
Add `.onChange(of: viewModel.saveState)` in AddMoveView to detect save completion and transition to complete state.

## Expected User Experience

1. User trims video, hits "Submit" → automatically navigates to naming screen
2. User enters name, saves → automatically returns to Arsenal tab
3. New move immediately appears in MoveListView

## Validation Criteria

- [ ] Trim submission triggers navigation to NameMoveView
- [ ] NameMoveView displays trimmed/rotated video correctly
- [ ] Save completion triggers return to Arsenal
- [ ] New move appears in MoveListView
- [ ] No MVVM violations remain
- [ ] Diagnostic logging provides insight for future debugging

## Risk Assessment

**Low Risk:**
- Changes are additive (adding missing observers)
- Follows existing MVVM patterns in codebase
- Minimal code changes required

**Rollback:**
- Changes can be easily reverted by removing added observers
- No database schema or API changes required