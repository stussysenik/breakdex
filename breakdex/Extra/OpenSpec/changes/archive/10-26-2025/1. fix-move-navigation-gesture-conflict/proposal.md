## Why
Move instances in the move list are not navigable after implementing swipe-to-delete functionality due to a gesture priority conflict where onTapGesture intercepts taps before NavigationLink can process them.

## What Changes
- Remove conflicting onTapGesture modifier from MoveRowView that blocks navigation
- Restore native NavigationLink tap handling for move row navigation
- Maintain haptic feedback by moving it to the navigation destination
- Preserve swipe-to-delete functionality

## Impact
- Affected specs: move-list-navigation (new capability needed)
- Affected code: MoveListView.swift (MoveRowView), BreakingArsenalView.swift
- User impact: Moves will be tappable and navigate to MoveDetailView again
- Technical impact: Removes gesture conflict, simplifies interaction model