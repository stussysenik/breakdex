## Why
The Athlete persona requires frictionless, mechanical watch precise video trimming and rotation controls in the trimmer view to catalog training footage with millisecond accuracy and visual feedback, regardless of interaction speed or network conditions.

## What Changes
- Implement precision trimming controls with millisecond timecode precision
- Add 90-degree rotation functionality with immediate visual feedback
- Create start/end trim handles with mechanical watch-like scrubbing precision
- Implement minimum duration constraint (3 seconds) with physical handle blocking
- Add playhead for precise navigation
- Track all modifications for processing by NameMoveView
- Isolate common patterns into separate files to prevent monolithic architecture
- Add comprehensive error handling and accessibility support
- Implement memory-efficient video processing for large files

## Impact
- Affected specs: video-trimming (new), video-playback (modified)
- Affected code: Features/AddMove/Views/, Features/Shared/Video/, Features/Shared/UI/
- Breaking changes: Requires new TrimModification tracking model
- Performance impact: Minimal - optimized for iOS 18.0 with efficient state management
- Accessibility impact: Adds VoiceOver support and reduced motion options
- Memory impact: Implements lazy loading and memory pooling for video frames