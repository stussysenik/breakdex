## Why
Fix critical Core Data crash preventing combo creation and implement end-to-end combo functionality with modern NavigationStack patterns and clickable timeline interactions.

## What Changes
- Remove illegal NSManagedObject hash overrides causing app crashes
- Implement modern NavigationStack with navigationDestination for type-safe combo detail navigation
- Create ComboDetailView with interactive timeline node functionality
- Establish proper Core Data relationship fetching and state synchronization

## Impact
- **Critical fix**: Resolves app termination when saving combos
- **Enhanced UX**: Seamless navigation from combo list to detail view
- **Interactive timeline**: Clickable timeline nodes for video playback
- **Modern architecture**: iOS 16+ NavigationStack best practices
- **Type safety**: Hashable-based navigation with compile-time guarantees

### Affected specs:
- `core-data` - Core Data entity management and relationships
- `ui-navigation` - Navigation patterns and view transitions
- `timeline-interaction` - Timeline node interactions and video playback

### Affected code:
- `CoreData/Combo+CoreDataClass.swift` - Remove illegal hash override
- `CoreData/ComboMove+CoreDataClass.swift` - Remove illegal hash override
- `CoreData/Review+CoreDataClass.swift` - Remove illegal hash override
- `Features/Arsenal/Views/ComboListView.swift` - Modernize navigation
- `Features/Combo/Views/` - Add ComboDetailView and enhance timeline
- `Features/Arsenal/ViewModels/ArsenalViewModel.swift` - Core Data fetching
- `Features/Combo/ViewModels/ComboViewModel.swift` - Combo creation logic