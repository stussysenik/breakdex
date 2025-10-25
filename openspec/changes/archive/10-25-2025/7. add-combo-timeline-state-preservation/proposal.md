## Why
Users lose their timeline node selection context when saving and viewing combos, requiring manual reselection of the move they were working on. Additionally, MoveListView lacks swipe-to-delete functionality that users expect based on ComboListView behavior.

## What Changes
- Add timeline node state preservation to Combo model using existing `activeMoveVideoReference` Core Data attribute
- Enhance ComboDetailView to restore saved timeline node selection on load
- Update timeline node navigation to use MoveDetailView with full video playback support
- Fix touch target redundancy in ComboListView (remove conflicting gesture handlers)
- Add swipe-to-delete functionality to MoveListView matching ComboListView UX

## Impact
- **Affected specs**:
  - New capability: `combo-timeline-state` (timeline node state preservation)
  - New capability: `move-list-ui` (MoveListView swipe-to-delete)
- **Affected code**:
  - `Features/Combo/ViewModels/ComboViewModel.swift` - Add state preservation logic
  - `Features/Combo/Views/ComboDetailView.swift` - Add state restoration + video navigation
  - `Features/Arsenal/Views/ComboListView.swift` - Fix touch target redundancy
  - `Features/Arsenal/Views/MoveListView.swift` - Add swipe-to-delete functionality
  - `Features/Arsenal/ViewModels/ArsenalViewModel.swift` - Add deleteMove method if missing