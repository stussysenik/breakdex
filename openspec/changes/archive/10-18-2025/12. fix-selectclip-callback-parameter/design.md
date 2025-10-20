## Context
The AddMove flow allows users to select, trim, and save video moves. The flow follows MVVM architecture with AddMoveViewModel managing state and AddMoveView coordinating UI transitions. The SelectClip component handles video selection and loading, then transitions to MinimalTrimmerView for trimming.

Current issue: Users get stuck at 95% loading despite backend processing completing successfully.

## Goals / Non-Goals
- **Goals**: Restore proper view transition from SelectClip to MinimalTrimmerView
- **Goals**: Add diagnostic logging for future debugging
- **Goals**: Ensure clean MVVM callback patterns
- **Non-Goals**: Restructure the entire AddMove architecture
- **Non-Goals**: Modify loading progress calculation logic

## Decisions
- **Decision**: Use iOS 18 @State-driven view switching with explicit view IDs
  - **Why**: SwiftUI @State with switch statements is the standard iOS 18 pattern for state-driven UI
  - **Apple best practice**: Use explicit view IDs to force recomposition when SwiftUI doesn't detect state changes
  - **Alternatives considered**:
    - Using NavigationStack (overkill for simple view switching)
    - Using @StateObject binding (violates SRP for simple state)
    - Using Environment values (unnecessary complexity)
- **Decision**: Add comprehensive logging at transition points
  - **Why**: Enables debugging of SwiftUI view recomposition issues
  - **Apple best practice**: Use .onChange and .onAppear modifiers for view lifecycle tracking

## Risks / Trade-offs
- **Risk**: Explicit view IDs could impact performance if overused
  - **Mitigation**: Use only for problematic view transitions, not universally
- **Risk**: Excessive logging could impact performance
  - **Mitigation**: Use appropriate log levels (info/debug) and keep messages concise
- **Trade-off**: Adding view IDs increases code complexity but ensures reliable view recomposition

## Migration Plan
1. Add explicit view ID property to force SwiftUI recomposition
2. Update view switching to use id() modifier when state changes
3. Add diagnostic logging with .onChange and .onAppear modifiers
4. Test the complete video loading → trimming flow
5. Verify MinimalTrimmerView appears correctly
6. Remove or reduce logging once stability is confirmed

## Open Questions
- Should we add error handling for callback failures?
- Do we need similar fixes in other parts of the app using SelectClip?