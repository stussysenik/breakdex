## Context
Based on analysis of production logs (lines 63-69, 100-101) and research into SwiftUI best practices, we identified two critical issues:
1. TextField lag caused by UIAlertController AutoLayout conflicts and keyboard session management
2. NavigationStack nesting causing navigation failures due to competing navigation hierarchies

## Goals / Non-Goals
- Goals: Eliminate TextField input lag, fix combo navigation, improve overall UI responsiveness
- Non-Goals: Major architecture overhaul, adding new navigation patterns, external dependencies

## Decisions
- Decision: Remove NavigationStack from ComboDetailView (parent ComboListView already has one)
  - Rationale: Stack Overflow consensus and Apple docs confirm nested NavigationStacks cause conflicts
  - Alternatives considered: Using NavigationPath, complete navigation refactor (overkill for current scope)

- Decision: Replace SwiftUI alert with custom sheet using @FocusState
  - Rationale: Production research shows UITextField in alerts has known performance issues; @FocusState provides instant keyboard control
  - Alternatives considered: Introspect library (adds dependency), keeping alert (doesn't fix core issue)

## Risks / Trade-offs
- Risk: Sheet UX differs from native alert feel → Mitigation: Use consistent styling and animations
- Risk: Removing NavigationStack might break navigationBar modifiers → Mitigation: Test all navigation scenarios
- Trade-off: Slightly more code for sheet vs alert → Benefit: Eliminates 2.7+ second lag

## Migration Plan
1. Test current navigation flow thoroughly
2. Remove nested NavigationStack from ComboDetailView
3. Replace alert with custom sheet implementation
4. Add @FocusState management for instant TextField responsiveness
5. Validate all navigation paths work correctly
6. Rollback: Keep original alert code commented for quick revert if needed

## Open Questions
- Should we implement a shared TextField component to prevent similar issues elsewhere?