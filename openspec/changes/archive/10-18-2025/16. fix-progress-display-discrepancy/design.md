# Technical Design: Fix Progress Display Discrepancy

## Context

The video loading pipeline uses a multi-stage progress system where each stage has a base progress and weight. SelectClip view is observing the wrong progress source, causing UI display to diverge from the actual loading state.

## Goals / Non-Goals

### Goals
- Ensure UI displays accurate calculated progress (95% → 99% → 100%)
- Maintain immediate transition to MinimalTrimmerView after loading completion
- Add minimal diagnostic logging to prevent future regressions
- Preserve existing MVVM architecture and state management

### Non-Goals
- Redesign the entire progress calculation system
- Change LoadingState or AddMoveViewModel interfaces
- Add complex progress visualization features

## Decisions

### Decision: Use calculated progress from LoadingState
SelectClip should observe `newState.progress` (calculated absolute progress) instead of the raw `progress` parameter (stage-relative progress).

**Rationale**:
- LoadingState already calculates the correct absolute progress using `baseProgress + (progress × weight)`
- This ensures consistency across all UI components
- Follows the single source of truth principle

### Decision: Add diagnostic logging for progress source tracking
Include both raw and calculated progress in logs to quickly identify future discrepancies.

**Rationale**:
- Makes debugging easier without affecting performance
- Provides immediate visibility into progress calculation issues
- Follows the existing logging patterns in the codebase

### Decision: Follow iOS 18 SwiftUI observation best practices
Use the @ObservedObject pattern correctly and ensure proper state propagation.

**Rationale**:
- Maintains compatibility with existing MVVM architecture
- Follows Apple's recommended patterns for iOS 18
- Avoids frame coalescing issues with proper state observation

## Implementation Strategy

1. **Fix SelectClip progress observation**: Change from `progress` to `newState.progress`
2. **Add diagnostic logging**: Log both raw and calculated progress values
3. **Validate state transitions**: Ensure 95% → 99% → 100% progression is visible in UI
4. **Test trimming transition**: Confirm immediate transition to MinimalTrimmerView after 100%

## Risks / Trade-offs

### Risk: Breaking existing progress calculations
**Mitigation**: Preserve all existing LoadingState and AddMoveViewModel logic, only change the observation point in SelectClip.

### Risk: Performance impact from additional logging
**Mitigation**: Use debug-level logging that can be disabled in production builds.

## Migration Plan

1. Update SelectClip.swift progress observation logic
2. Add diagnostic logging
3. Test video loading workflow end-to-end
4. Verify immediate trimming transition
5. Validate against different video sources and sizes

## Open Questions

- None identified - the fix is straightforward and well-contained.