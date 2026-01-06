# Preserve Timeline Node Selection

## Why
Timeline node selection persistence is critical for user experience in the combo learning workflow. When users select a specific move to study, they expect that selection to remain consistent throughout their interaction with the app, including when they use fullscreen video playback. The current behavior of resetting selection to the first node disrupts the user's learning flow and creates confusion, forcing users to manually re-select their intended move after every fullscreen video interaction. This breaks the principle of state consistency and degrades the overall user experience.

## Problem Summary
Timeline node selection in ComboDetailView is not persisted across fullscreen video player transitions. When a user selects a timeline node, enters fullscreen video, and exits, the selection resets to the first node instead of preserving the originally selected node.

## Current Behavior
- User selects timeline node (e.g., first node)
- User enters fullscreen video player
- User exits fullscreen video player
- Timeline selection incorrectly resets to first node regardless of original selection

## Desired Behavior
- Timeline node selection should persist across all UI state transitions
- Selecting a node should maintain that selection until user explicitly changes it
- Fullscreen video transitions should not affect timeline selection state

## Root Cause Analysis
The issue occurs because `ComboTimelineView.handleViewAppear()` auto-selects the first move when `activeIndex == nil`, overriding the preserved selection from `ComboDetailView.restoreTimelineNodeState()`. When returning from fullscreen video, the view appears again and triggers this auto-selection logic.

## Proposed Solution
Modify `ComboTimelineView.handleViewAppear()` to respect existing selections and only auto-select when no valid selection exists, preventing override of user's intentional choices during view transitions.

## Scope
- Fix timeline node selection persistence in `ComboTimelineView`
- Ensure selection survives fullscreen video transitions
- Maintain existing auto-selection behavior for initial load
- Add logging for debugging selection state changes

## Impact
- Improved user experience with persistent timeline selections
- Better state management across view lifecycle events
- Enhanced debugging visibility for selection state changes