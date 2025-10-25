## Why

The MoveDetailView navigation is broken when users tap on move items in the MoveListView. Enhanced logging analysis reveals that NavigationLink taps are detected and NavigationLink triggering is attempted, but MoveDetailView.onAppear never executes, indicating a SwiftUI navigation composition failure.

The root cause is a known SwiftUI navigation interference pattern where List components inside NavigationStack can interfere with NavigationLink navigation, creating a navigation deadlock that prevents the destination view from appearing.

## What Changes

- Replace List with LazyVStack in MoveListView to eliminate navigation interference
- Preserve exact visual appearance and scroll behavior
- Maintain all existing functionality (search, swipe actions, selection haptics)
- Add enhanced logging to verify navigation success
- Remove debug logging added for investigation

## Impact

- Affected specs: move-list-navigation
- Affected code:
  - MoveListView.swift:162-183 (List → LazyVStack replacement)
  - BreakingArsenalView.swift:36-50 (remove control test logging)
  - MoveDetailView.swift:47-50 (remove debug logging)

**BREAKING**: No breaking changes - maintains identical UI/UX while fixing navigation.

## Testing

- Verify tap on move "yes" successfully navigates to MoveDetailView
- Confirm MoveDetailView.onAppear logs execute
- Validate visual appearance matches current List design
- Test scroll performance with LazyVStack
- Verify search functionality works unchanged