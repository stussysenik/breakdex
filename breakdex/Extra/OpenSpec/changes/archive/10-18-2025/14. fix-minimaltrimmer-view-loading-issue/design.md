## Context
The MinimalTrimmerView fails to appear in the SwiftUI view hierarchy despite correct state transitions. Analysis shows:
- State transitions work: AddMoveViewModel (95%) → SelectClip (99%) → AddMoveView.trimming (100%)
- AddMoveView correctly switches to trimming state and attempts to render MinimalTrimmerView
- SwiftUI recomposition works (body recomputed with currentStep: trimming)
- MinimalTrimmerView.onAppear never fires, indicating the view never actually renders

## Goals / Non-Goals
- **Goals**:
  - Fix MinimalTrimmerView rendering issue with minimal architectural changes
  - Add targeted diagnostic logging for future debugging
  - Maintain MVVM pattern and clean architecture principles
  - Ensure reliable view appearance across different device sizes and video formats
- **Non-Goals**:
  - Major architectural refactoring of the video trimming system
  - Performance optimizations beyond what's needed to fix the rendering issue
  - Changes to the overall add-move workflow structure

## Decisions
- **Decision**: Simplify MinimalTrimmerView initialization by removing complex timing guards and async setup operations that could block rendering
  - **Rationale**: The current setup has multiple guard conditions and async tasks that may cause SwiftUI to abandon view creation
  - **Alternatives considered**:
    1. Keeping complex setup with better error handling (rejected: too complex for this specific issue)
    2. Moving all setup to ViewModel (rejected: violates current MVVM separation)

- **Decision**: Add minimal diagnostic logging to track view lifecycle events
  - **Rationale**: Current lack of logging makes debugging difficult; targeted logging will help identify future issues
  - **Alternatives considered**:
    1. Comprehensive logging throughout (rejected: would be too verbose)
    2. No logging changes (rejected: would leave debugging as difficult as current state)

- **Decision**: Ensure video player is ready before view appears by leveraging existing state management
  - **Rationale**: The issue may be related to attempting to render before video player is fully ready
  - **Alternatives considered**:
    1. Adding loading states within MinimalTrimmerView (rejected: adds complexity and may not solve root issue)
    2. Making video player loading synchronous (rejected: would hurt performance)

## Risks / Trade-offs
- **Risk**: Simplifying initialization logic might remove important validation
  - **Mitigation**: Keep essential validation while removing blocking operations
- **Risk**: Adding logging could impact performance
  - **Mitigation**: Use minimal, essential logging only for critical lifecycle events
- **Trade-off**: Immediate appearance vs. comprehensive setup validation
  - **Decision**: Prioritize appearance with post-render validation

## Migration Plan
1. **Analysis Phase**: Identify specific blocking operations in MinimalTrimmerView.onAppear
2. **Implementation Phase**:
   - Remove complex timing guards and async setup from view initialization
   - Add diagnostic logging to track view lifecycle
   - Ensure proper state validation without blocking
3. **Testing Phase**:
   - Verify view appears correctly across different scenarios
   - Test state transitions and data flow
   - Validate error handling
4. **Rollback**: If changes cause regressions, revert to previous version with additional debugging

## Open Questions
- What specific operation in MinimalTrimmerView.onAppear is causing the early return or blocking?
- Are there hidden dependencies on video player state that aren't being properly validated?
- Could the issue be related to the view's complex state management (@State variables, performance manager, etc.)?
- Is there a SwiftUI rendering issue related to the view's size or complexity?