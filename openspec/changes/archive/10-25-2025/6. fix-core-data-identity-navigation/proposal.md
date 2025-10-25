## Why
Critical navigation failures prevent users from accessing ComboDetailView and MoveDetailView despite previous navigation stack fixes. The root cause is Core Data entities with nil UUID identifiers that break SwiftUI's ForEach rendering, causing undefined navigation behavior and UI instability.

## Current Issues
1. **ForEach Failures**: `ForEach: the ID nil occurs multiple times within the collection, this will give undefined results!`
2. **Navigation Deadlock**: ComboListView taps detected (`📋 COMBO_LIST_VIEW: 👆 Tapped combo`) but ComboDetailView never appears
3. **Missing Identity**: ComboViewModel.saveCombo() creates entities without setting required UUID id property
4. **NavigationDestination Mismatch**: NavigationStack hierarchy exists but navigationDestination handlers are misaligned

## Root Cause Analysis
- Combo entities created with `newCombo.id = nil` (optional UUID never assigned)
- ComboMove entities also lack UUID assignment
- SwiftUI ForEach requires stable, unique identifiers for proper list management
- NavigationLinks fail when ForEach cannot properly track item identity

## What Changes
- Enforce UUID assignment for all Core Data entities during creation
- Align NavigationStack architecture with Apple's production recommendations
- Implement objectID-based identification as fallback for existing entities
- Add comprehensive navigation logging for verification
- Fix navigationDestination placement in proper NavigationStack context

## Impact
- **Critical Fix**: Resolves broken navigation to detail views
- **Stability**: Eliminates ForEach undefined behavior warnings
- **Production Pattern**: Implements Apple's recommended Core Data + SwiftUI integration
- **User Experience**: Enables full app navigation flow (combo list → combo detail, move list → move detail)

### Affected Features:
- Combo creation and navigation
- Move detail navigation
- Navigation stack consistency across Arsenal tab

### Affected Code:
- `Features/Combo/ViewModels/ComboViewModel.swift` - UUID assignment in saveCombo()
- `Features/Arsenal/Views/BreakingArsenalView.swift` - NavigationStack destinations
- `Features/Arsenal/Views/ComboListView.swift` - ForEach identification pattern
- `CoreData/Combo+CoreDataClass.swift` - Identity management (optional)

## Testing
- Verify combo creation saves with non-nil UUID identifiers
- Confirm navigation from combo list to combo detail works end-to-end
- Test ForEach no longer generates ID nil warnings
- Validate move detail navigation continues working
- Check navigation back buttons and stack behavior