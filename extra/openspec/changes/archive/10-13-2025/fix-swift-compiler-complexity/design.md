## Context
CreateComboView.swift contains a complex SwiftUI view body at line 41:25 that exceeds the Swift compiler's type-checking timeout. The expression combines multiple view modifiers, nested views, and complex binding expressions that together create a type-checking challenge for the compiler.

## Goals / Non-Goals
- Goals: Resolve Swift compiler type-checking timeout while maintaining all existing functionality
- Goals: Improve code maintainability by breaking down complex expressions
- Goals: Follow Clean Architecture principles for view organization
- Non-Goals: Change user experience or visual appearance
- Non-Goals: Modify the underlying business logic or data flow

## Decisions
- Decision: Extract complex view modifiers into separate computed properties to reduce type-checking complexity
- Reasoning: SwiftUI compiler type-checking struggles with deeply nested modifier chains
- Alternatives considered:
  - Using @ViewBuilder - rejected as it doesn't solve the core type-checking issue
  - Splitting into multiple separate Views - rejected as over-engineering for this case
  - Ignoring the error - rejected as it prevents successful compilation

## Technical Approach
1. **Main View Body Extraction**: Pull the NavigationView content into `navigationContentView`
2. **Sheet Modifier Extraction**: Extract the complex move picker sheet into `movePickerSheet`
3. **Alert Modifier Extraction**: Separate the four alert modifiers into individual computed properties
4. **Task Modifier Extraction**: Extract the video loading task into `videoLoadingTask`
5. **Binding Simplification**: Simplify the complex timeline binding in `timelineSection`

## Risks / Trade-offs
- Risk: Introducing bugs during refactoring
- Mitigation: Carefully preserve all existing functionality and test thoroughly
- Risk: Over-engineering the solution
- Mitigation: Keep changes minimal and focused only on compiler issues
- Trade-off: Slightly more code lines for better compiler performance and maintainability

## Migration Plan
1. Create the new computed properties in CreateComboView.swift
2. Replace the complex body expression with the new computed properties
3. Build and test to ensure compiler error is resolved
4. Verify all functionality works as expected
5. No rollback needed as this is a refactoring-only change

## Open Questions
- None: This is a straightforward compiler issue fix with well-understood solutions