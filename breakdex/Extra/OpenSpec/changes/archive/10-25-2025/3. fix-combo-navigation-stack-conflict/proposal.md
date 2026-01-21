## Why
ComboDetailView navigation is completely broken due to NavigationStack hierarchy conflict. Users can tap on combo items in the list (confirmed by logs `📋 COMBO_LIST_VIEW: 👆 Tapped combo: yeah`) but the navigation never triggers - no ComboDetailView appearance logs are generated.

## Root Cause Evidence
1. **BreakingArsenalView.swift:17** creates parent NavigationStack
2. **BreakingArsenalView.swift:36-42** uses NavigationLink to push ComboListView into parent stack
3. **ComboListView.swift:33** creates nested NavigationStack (❌ PROBLEM)
4. **ComboListView.swift:180** NavigationLink(value: combo.objectID) tries to navigate
5. **ComboListView.swift:57-62** navigationDestination registered on nested stack
6. **RESULT**: NavigationLink exists in parent context, navigationDestination in child context - they never meet

## What Changes
- Remove nested NavigationStack from ComboListView.swift (NOT ComboDetailView.swift)
- Use parent NavigationStack from BreakingArsenalView for consistency with MoveListView pattern
- Maintain all existing navigationBar modifiers and visual styling
- Add navigation success logging for verification

## Impact
- **Affected code**: Features/Arsenal/Views/ComboListView.swift (lines 33, 57-62)
- **Breaking**: None - fixes completely broken navigation
- **Verification**: ComboDetailView will appear when combo items are tapped
- **Pattern**: Aligns with working MoveListView navigation pattern