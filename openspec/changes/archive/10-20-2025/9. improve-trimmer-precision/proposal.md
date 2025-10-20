## Why
The video trimmer handle positioning suffers from imprecise snap-to-second behavior that discards user's precise frame selections, creating a jarring user experience where handles jump to whole seconds after dragging.

## What Changes
- Replace `snapToNearestSecond` function with `snapToNearestFrame` to provide frame-level precision
- Update drag gesture `.onEnded` handlers to use the new frame-precision snapping
- Add frame rate validation and fallback behavior for edge cases
- Maintain user's precise time selections during trim operations

## Impact
- Affected specs: video-trimming (new capability)
- Affected code: MinimalTrimmerView.swift (lines 453, 481, 899)
- User experience: Eliminates jarring handle jumps and provides precise frame-accurate trimming