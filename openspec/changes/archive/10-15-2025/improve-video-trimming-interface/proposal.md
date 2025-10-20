## Why
The current video trimming interface in breakdex is not functional or intuitive for athletes cataloging training footage. Based on analysis of the existing MinimalTrimmerView and user feedback, the interface lacks proper visual feedback, synchronized playback, and mechanical watch precision needed for precise movement analysis. Athletes need a frictionless trimming experience that feels as precise as a mechanical watch when selecting specific moments from training videos.

## What Changes
- **Redesign the visual timeline** with intuitive drag handles, clear visual feedback, and real-time preview
- **Implement synchronized video playback** that works seamlessly with the trimming interface
- **Add millisecond-precise playhead movement** that corresponds to video playback position
- **Create clean, modern controls layout** following iOS 18 design principles
- **Implement proper trim range validation** with visual feedback for invalid selections
- **Add comprehensive accessibility support** for athletes with different needs
- **Ensure consistent performance** across various video formats and frame rates
- **Add haptic feedback** for precise trimming interactions

## Impact
- **Affected specs**: video-trimming, video-playback, ui-components
- **Affected code**:
  - breakdex/Features/Shared/Video/MinimalTrimmerView.swift (complete redesign)
  - breakdex/Features/Shared/Video/VideoPlayer.swift (enhanced playback integration)
  - breakdex/Features/Shared/Models/TrimmerState.swift (state management improvements)
  - breakdex/Features/AddMove/Views/SelectClip.swift (workflow integration)
  - breakdex/Features/Shared/UI/Components/ (new trimming-specific components)
- **User impact**: Drastically improved trimming experience with mechanical watch precision
- **Performance impact**: Optimized for smooth 60fps interactions across all device types
- **Breaking changes**: Complete replacement of trimming interface while maintaining existing API contracts