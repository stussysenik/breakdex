## Why
The video trimmer handles have coordinate space misalignment between drag gestures and handle positioning. When users drag handles, there's a noticeable offset between finger position and handle movement because the coordinate calculations and visual offsets are mixed together. This creates an imprecise user experience where handles don't track finger movements exactly.

## What Changes
- Separate coordinate logic from visual positioning in MinimalTrimmerView
- Modify timeToCoordinate and coordinateToTime to work with pure coordinates on the "available track"
- Move handle radius offset to the .offset() modifiers in the view layer
- Update drag gesture handlers to properly map finger position to handle center position
- Maintain all existing functionality (minimum duration, animations, haptic feedback)

## Impact
- Affected specs: video-trimming (enhanced precision)
- Affected code:
  - Features/Shared/Video/MinimalTrimmerView.swift: timeToCoordinate and coordinateToTime functions
  - Features/Shared/Video/MinimalTrimmerView.swift: handle .offset() modifiers
  - Features/Shared/Video/MinimalTrimmerView.swift: drag gesture handlers (handleLeftHandleDrag, handleRightHandleDrag)
- **NON-BREAKING**: Improves precision without changing functional behavior