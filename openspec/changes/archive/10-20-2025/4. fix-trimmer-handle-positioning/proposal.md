## Why

The video trimmer handles have systematic positioning errors where the start handle appears off-screen at time=0:00:00 and the end handle cannot fully reach the timeline end position. This creates a broken user interaction experience where handles appear to "float" over the timeline rather than being precisely aligned with their corresponding time positions.

## What Changes

- Fix start handle positioning to appear at timeline beginning when startTime = 0.0
- Fix end handle positioning to reach timeline edge when endTime = videoDuration
- Restore mathematical consistency between time positions and visual coordinates
- Add minimal diagnostic logging for future debugging
- Maintain all existing functionality (minimum duration constraints, animations, haptic feedback)
- Implement coordinate space awareness following iOS 18 SwiftUI best practices
- Ensure gesture positioning uses precise coordinate mapping consistent with Apple's coordinateSpace guidelines

## Impact

- **Affected specs**: video-trimming
- **Affected code**: MinimalTrimmerView.swift:353,376 (handle positioning) and MinimalTrimmerView.swift:642,664 (drag gesture logic)
- **Breaking changes**: None - internal implementation only, no API changes