## Context
The video trimmer interface has systematic handle positioning issues that create a poor user experience. Two separate problems work together:

1. **Logic Issue**: ViewModel defaults trim start to last 10 seconds (24.125s for a 34.125s video)
2. **Layout Issue**: Handle positioning doesn't account for handle width, causing handles to extend beyond timeline bounds

## Goals / Non-Goals
- Goals: Fix handle positioning to be accurate and contained within timeline bounds
- Goals: Default trim selection to start of video instead of last 10 seconds
- Non-Goals: Change overall trimmer UI design or functionality
- Non-Goals: Add new features beyond fixing positioning issues

## Decisions
- Decision: Fix both logic and layout issues together for complete solution
- Decision: Use handle-aware coordinate calculations to keep handles within bounds
- Decision: Change default behavior to start at video beginning for better UX
- Alternatives considered:
  - Only fixing layout (would still default to 24.125s)
  - Only fixing logic (handles would still extend beyond bounds)
  - Adding offset to handles vs fixing coordinate math (chose coordinate math for cleaner solution)

## Risks / Trade-offs
- Risk: Changing default trim behavior may affect existing workflows
- Mitigation: Clear change documentation and testing
- Trade-off: Slightly more complex coordinate calculations for accurate positioning

## Migration Plan
- Update AddMoveViewModel trim initialization logic
- Update MinimalTrimmerView coordinate conversion functions
- Test with various video durations and trim scenarios
- Verify existing functionality (minimum duration, constraints) still works

## Open Questions
- None identified - the issue is well-documented with clear solution