## Context
Users create combos with selected timeline nodes and expect that selection to persist when viewing saved combos. Currently, the `activeMoveVideoReference` Core Data attribute exists but is unused, causing timeline nodes to always default to index 0. Additionally, MoveListView lacks swipe-to-delete functionality that exists in ComboListView, creating inconsistent UX.

## Goals / Non-Goals
- **Goals**:
  - Preserve user's timeline node selection state across combo save/load cycles
  - Enable video playback when clicking timeline nodes in ComboDetailView
  - Provide consistent swipe-to-delete UX across MoveListView and ComboListView
  - Optimize touch targets for better usability
- **Non-Goals**:
  - Change the Core Data schema (use existing attributes)
  - Modify the existing video player implementation
  - Change the fundamental navigation architecture

## Decisions
- **Decision**: Use existing `activeMoveVideoReference` attribute to store NSManagedObjectID as Data
  - **Why**: No schema changes required, attribute already exists in Core Data model
  - **Alternatives considered**:
    - Add new attribute for timeline index (would require migration)
    - Use UserPrefs (would be lost if combo deleted)
- **Decision**: Navigate timeline nodes to MoveDetailView instead of basic text view
  - **Why**: Leverages existing SharedVideoPlayer integration, consistent with rest of app
  - **Alternatives considered**:
    - Add video player to ComboDetailView (complex, duplicates existing functionality)
    - Create new video-only view (unnecessary code duplication)

## Risks / Trade-offs
- **Risk**: NSManagedObjectID URI representation may not be stable across Core Data migrations
  - **Mitigation**: Test with migration scenarios, provide fallback to index 0
- **Trade-off**: Additional Core Data lookup for state restoration
  - **Justification**: Minimal performance impact for significant UX improvement
- **Risk**: Touch target changes may affect existing user behavior
  - **Mitigation**: Maintain visual appearance, only clean up redundant gesture handlers

## Migration Plan
1. **State Migration**: Existing combos without `activeMoveVideoReference` data will default to index 0 (current behavior)
2. **No Breaking Changes**: All new functionality is additive
3. **Backward Compatibility**: Existing navigation patterns continue to work

## Open Questions
- Should we add validation to ensure stored NSManagedObjectID still exists in Core Data?
- Do we need to handle edge cases where stored move is deleted from combo?