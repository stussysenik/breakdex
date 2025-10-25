## Context
The app crashes when users attempt to save combos due to illegal NSManagedObject hash overrides. Core Data explicitly forbids overriding hash and isEqual methods as it relies on internal object management. Additionally, the combo detail view is missing, preventing users from viewing and interacting with saved combos through clickable timeline nodes.

## Goals / Non-Goals
**Goals:**
- Fix Core Data crash enabling combo creation
- Implement complete combo list → detail navigation flow
- Add clickable timeline nodes with video playback
- Use iOS 16+ NavigationStack best practices
- Ensure type-safe navigation and proper state management

**Non-Goals:**
- Automatic UI refresh after combo creation (manual navigation required)
- Complex timeline editing features
- Offline sync capabilities
- Multi-user collaboration

## Decisions
- **Decision**: Remove all hash overrides from Core Data classes
  - **Rationale**: Apple explicitly forbids NSManagedObject hash overrides; Core Data manages object identity internally via objectID
  - **Evidence**: Industry consensus from Stack Overflow, Swift Forums, and Apple documentation

- **Decision**: Use NavigationStack with navigationDestination for combo navigation
  - **Rationale**: iOS 16+ modern pattern provides type-safe navigation, deeplink support, and lazy view instantiation
  - **Alternative considered**: Traditional NavigationView with programmatic NavigationLink (deprecated in iOS 16)

- **Decision**: Implement ComboDetailView with interactive timeline
  - **Rationale**: Leverage existing ComboTimelineView with navigationDestination for clickable nodes
  - **Evidence**: Production apps like VideoTimelineView use similar patterns for timeline interactions

- **Decision**: Use NSManagedObjectID for navigation type safety
  - **Rationale**: ObjectID is Hashable and provides Core Data's built-in identity management
  - **Alternative considered**: Custom Hashable conformance (would require illegal hash override)

## Risks / Trade-offs
- **Risk**: Removing hash overrides may break existing code relying on custom equality
  - **Mitigation**: Core Data's built-in objectID comparison provides sufficient identity management
- **Risk**: NavigationStack requires iOS 16+, potentially limiting device support
  - **Mitigation**: Project targets iOS 18.0, making this a non-issue
- **Trade-off**: Manual navigation refresh vs automatic UI updates
  - **Rationale**: Prioritizes simplicity and reliability over automatic refresh complexity

## Migration Plan
1. **Phase 1**: Remove hash overrides from Core Data classes
   - Test combo creation no longer crashes
   - Verify Core Data relationships work correctly
2. **Phase 2**: Implement NavigationStack navigation
   - Replace placeholder NavigationLink in ComboListView
   - Add navigationDestination for Combo entities
3. **Phase 3**: Create ComboDetailView
   - Implement combo header with learning state
   - Add interactive timeline with clickable nodes
4. **Phase 4**: Integrate video playback
   - Connect timeline node selection to video loading
   - Test complete user flow end-to-end

**Rollback**: Keep backup of current hash implementations; revert if critical functionality breaks

## Open Questions
- Should combo deletion include confirmation dialog? (Currently uses swipe-to-delete)
- Should timeline nodes show move learning state indicators?
- Optimal timeline scrolling behavior for long combos?