## Context
The current codebase has two list views (ComboListView and MoveListView) that both implement swipe-to-delete functionality but use different underlying UI components:
- ComboListView: Uses `List` with `.listStyle(.plain)`
- MoveListView: Uses `ScrollView` with `LazyVStack`

Both implement the same swipe actions pattern, but the difference in list components could lead to subtle behavioral differences that impact user experience consistency.

## Goals / Non-Goals
- Goals: Ensure identical swipe-to-delete behavior between ComboListView and MoveListView
- Goals: Maintain performance characteristics of current implementations
- Goals: Preserve existing functionality while standardizing behavior
- Non-Goals: Change the visual design or appearance beyond behavior consistency
- Non-Goals: Break existing navigation or interaction patterns

## Decisions
- Decision: Use ComboListView's `List` implementation as the baseline for standardization
- Reasoning: List component provides built-in swipe gesture optimization and consistent iOS behavior
- Alternative considered: Using ScrollView/LazyVStack for both - rejected due to complexity of manual swipe handling
- Alternative considered: Creating a unified component - rejected as over-engineering for current scope

## Risks / Trade-offs
- Risk: Moving from ScrollView to List may impact performance for very large datasets
- Mitigation: Monitor performance and consider optimizations if needed
- Risk: List component limitations may affect custom styling capabilities
- Mitigation: Test current custom styles work with List approach
- Trade-off: Standardization vs. customization - choosing standardization for consistency

## Migration Plan
1. Analyze current MoveListView implementation differences
2. Update MoveListView to use List instead of ScrollView/LazyVStack
3. Ensure all swipe actions, haptics, and animations work identically
4. Test both views with various data sizes and edge cases
5. Verify no regression in existing functionality

## Open Questions
- Should we create a shared ListRow component to further standardize behavior?
- Are there any specific performance considerations with the MoveListView data that we need to account for?