## Why
The breakdex app currently has basic swipe-to-delete functionality for combos but lacks comprehensive swipe gesture capabilities across both moves and combos. Users need intuitive, consistent swipe actions for managing their arsenal content with proper haptic feedback, undo functionality, and accessibility support.

## What Changes
- Enhance existing swipe-to-delete functionality in ComboListView with production-grade features
- Add comprehensive swipe-to-delete functionality to MoveListView
- Implement undo functionality with timed confirmation for accidental deletions
- Add haptic feedback and accessibility support for swipe actions
- Create shared swipe action component for consistency across moves and combos
- Fix NavigationStack hierarchy conflict that prevents ComboDetailView navigation

## Impact
- **Affected capabilities**: ui-navigation, move-management, combo-management
- **Affected code**:
  - Features/Arsenal/Views/ComboListView.swift (NavigationLink fix + swipe enhancement)
  - Features/Arsenal/Views/MoveListView.swift (add swipe-to-delete)
  - Features/Shared/UI/Components/SwipeActionsComponent.swift (new shared component)
- **User Experience**: Significantly improved content management with iOS-standard swipe interactions
- **Breaking**: None - enhances existing functionality without removing current features