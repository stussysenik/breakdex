## Why
The video trimmer displays vertical videos incorrectly - vertical content appears inside a fixed horizontal 16:9 container, creating a mismatch between video orientation and container layout. Users see horizontal framing with vertical content rotated independently, breaking the "what you see is what you get" principle.

## What Changes
- Replace fixed 16:9 aspect ratio container with automatic aspect ratio detection using AVPlayerViewController
- Apply rotation to the entire video component (content + container) as a synchronized unit using SwiftUI's rotationEffect
- Add minimal diagnostic logging to track video loading, aspect ratio detection, and rotation state
- Remove complex manual transform calculations in favor of native iOS video player handling

## Impact
- Affected specs: video-trimming (new capability to be created)
- Affected code: Features/Shared/Video/MinimalTrimmerView.swift:236-242 (video preview section), Features/Shared/Video/MinimalTrimmerView.swift:1325-1354 (rotation transforms)
- **BREAKING**: Changes video display behavior to show correct aspect ratio from first load instead of forcing 16:9 container