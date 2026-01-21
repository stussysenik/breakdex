## Why
Combo list items are not navigable due to gesture priority conflict where `onTapGesture` intercepts taps before NavigationLink can process them, replicating the exact issue that was fixed for move list items.

## Root Cause Evidence
1. **ComboListView.swift:176** creates NavigationLink(value: combo) for navigation
2. **ComboListView.swift:201-211** adds conflicting onTapGesture modifier that intercepts taps
3. **BreakingArsenalView.swift:88-99** has proper navigationDestination for Combo.self
4. **RESULT**: onTapGesture consumes tap events, preventing NavigationLink navigation

## What Changes
- Remove conflicting onTapGesture modifier from ComboRowView that blocks navigation
- Restore native NavigationLink tap handling for combo row navigation
- Move haptic feedback to NavigationLink's tap gesture or maintain via buttonStyle
- Preserve swipe-to-delete functionality and existing logging
- Add navigation success logging for verification

## Impact
- Affected specs: combo-list-navigation (new capability needed)
- Affected code: ComboListView.swift (ComboRowView)
- User impact: Combos will be tappable and navigate to ComboDetailView again
- Technical impact: Removes gesture conflict, aligns with working move list pattern