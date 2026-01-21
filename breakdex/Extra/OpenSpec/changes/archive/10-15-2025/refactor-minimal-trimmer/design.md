## Context
The current TrimmerView suffers from massive over-engineering with 25,859 lines of code, excessive state management, and complex category theory abstractions that don't provide user value. The visual interface is cluttered and unusable.

## Goals / Non-Goals
- Goals: Simple, functional trimming interface that users can actually use
- Goals: Reduce code complexity by >99% while maintaining core functionality
- Goals: Clean visual hierarchy with intuitive drag handles
- Non-Goals: Preserve existing category theory abstractions
- Non-Goals: Maintain complex precision controls and magnetic snapping
- Non-Goals: Keep all current state management features

## Decisions
- Decision: Replace TrimmerView with simple ~200 line implementation
  - Reason: Current implementation is unmaintainable and unusable
  - Alternatives considered: Incremental refactoring (would still leave complexity), complete removal (would lose functionality)
- Decision: Use simple SwiftUI gestures for timeline interaction
  - Reason: Leverages platform conventions, reduces custom code
  - Alternatives considered: Custom gesture recognizers (more complexity), third-party libraries (dependencies)
- Decision: Separate rotation into distinct workflow step
  - Reason: Reduces cognitive load, follows principle of single responsibility
  - Alternatives considered: Rotation in same view (cluttered), rotation before trimming (confusing workflow)

## Risks / Trade-offs
- Risk: Losing some advanced trimming features during simplification
  - Mitigation: Focus on core 80% use case first, add features later based on user feedback
- Risk: Breaking existing integrations with TrimmerState
  - Mitigation: Create simple compatibility layer during transition
- Trade-off: Less precise control in favor of usability
  - Justification: Current precision features are unusable due to interface complexity

## File Cleanup Strategy

### Files to Delete (Mission Violation)
- **TrimmerState.swift** (828 lines) - Category theory over-engineering
- **TrimmerInteractionManager.swift** (784 lines) - Unnecessary interaction complexity
- **PrecisionTrimmerTimeline.swift** (757 lines) - Academic exercise vs functional tool

### Files to Simplify
- **TrimModification.swift** → Reduce to basic struct with startTime, endTime, rotation
- **PrecisionTimecodeDisplay.swift** → Rename to SimpleTimecodeDisplay, remove complexity

### Files to Review
- **RotatedVideoPlayer.swift** - Keep if essential for instant rotation feedback
- **VideoRotationControls.swift** - Keep if simple and functional

### Expected Impact
- **~2,369 lines removed** → 99% code reduction
- **Eliminate category theory abstractions** that add no user value
- **Remove over-engineered complexity** that makes interface unusable
- **Maintain essential functionality** while improving usability

## Migration Plan
1. Create new MinimalTrimmerView with essential functionality
2. Update AddMoveUnifiedState to use new trimmer
3. Maintain old TrimmerView during transition for rollback
4. Remove old implementation after validation
5. Update tests to cover new simplified interface

## Open Questions
- Should rotation be a button in trim view or separate screen?
- What minimum trim duration should be enforced? (currently 3 seconds)
- How should we handle video preview during trimming?