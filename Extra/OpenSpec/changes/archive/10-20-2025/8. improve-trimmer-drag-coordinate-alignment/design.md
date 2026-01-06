## Context
The trimmer coordinate system has a fundamental architecture issue where coordinate calculations and visual positioning are mixed. The drag gesture coordinates (finger position) and handle center coordinates don't align because the timeToCoordinate and coordinateToTime functions include radius offsets while drag gestures provide raw finger coordinates.

## Goals / Non-Goals
- Goals: Achieve 1:1 tracking between finger movement and handle position
- Goals: Clean separation between coordinate logic and visual positioning
- Goals: Maintain all existing constraints (minimum duration, boundaries)
- Non-Goals: Change overall trimmer behavior or functionality
- Non-Goals: Modify the visual appearance beyond positioning precision

## Decisions
- Decision: Separate coordinate logic (pure time/space mapping) from visual offsets (handle positioning)
- Decision: Move radius calculations to view layer (.offset modifiers) instead of coordinate functions
- Decision: Adjust drag gesture handlers to map finger coordinates to available track coordinates
- Alternatives considered:
  - Adjusting drag gesture offset only (wouldn't fix the architectural issue)
  - Modifying coordinate functions to account for finger position (would mix concerns)
  - Adding more complex math to existing functions (would reduce maintainability)

## Risks / Trade-offs
- Risk: More files to modify for a single change
- Mitigation: Clear documentation and incremental testing
- Trade-off: Slightly more complex view layer for cleaner coordinate system

## Migration Plan
- Update timeToCoordinate to return coordinates on available track only
- Update coordinateToTime to work with available track coordinates only
- Add radius offset to .offset() modifiers in view
- Update drag gesture handlers to subtract radius before calling coordinateToTime
- Test drag precision with various video durations and handle positions

## Open Questions
- None identified - the coordinate space issue is well-documented with clear solution