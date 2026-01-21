## Why
The current MinimalTrimmerView implementation has functional core components but suffers from spatial design issues that reduce precision and visual harmony. Based on user feedback and category theory analysis of the interaction patterns, the interface needs improved visual hierarchy, proper spatial alignment, direct manipulation controls, and removal of visual noise. The current floating handles lack precision, the timeline doesn't respect screen bounds, and the rotation flow requires unnecessary modal interaction.

## What Changes
- Redesign timeline layout to align with video player edges (visual harmony)
- Replace floating handles with edge-anchored trim controls for precision
- Remove unnecessary red playhead indicator that creates visual noise
- Implement direct 90-degree rotation on button tap instead of modal sheet
- Ensure all timeline components stay within safe screen boundaries
- Improve spatial relationship between video preview and timeline controls
- Maintain existing performance optimizations and state management
- Follow iOS 18 direct manipulation principles for more intuitive interactions

## Impact
- Affected specs: `video-trimming-interface` (new capability)
- Affected code: `breakdex/Features/Shared/Video/MinimalTrimmerView.swift`
- User experience: Enhanced precision and visual harmony for video trimming
- Performance: Maintains current AVFoundation efficiency with improved UI responsiveness
- Accessibility: Better spatial grounding and direct manipulation patterns