# Implement Photo Picker to TrimmerView Video Loading

## Why
Enable users to select videos from their photo library and seamlessly load them into the TrimmerView for creating video flashcards. This is a core user journey that bridges video selection with the trimming interface, completing the essential AddMove workflow.

## What Changes
- Complete the video loading flow from PhotosPickerItem to TrimmerView display
- Implement proper state management and progress tracking during video loading
- Add error handling and retry mechanisms for video loading failures
- Integrate existing video loading infrastructure (VideoLoadingService, PhotosAssetLoader)
- Ensure smooth user experience with loading indicators and progress feedback

## Impact
- **Affected specs**: video-loading, photo-integration, add-move-workflow
- **Affected code**:
  - Features/AddMove/Views/SelectClip.swift (photo picker integration)
  - Features/Shared/Video/TrimmerView.swift (video display)
  - Features/Shared/Models/UnifiedState.swift (state management)
  - Features/Shared/Services/VideoLoadingService.swift (loading infrastructure)
- **User impact**: Users can successfully select videos from Photos and see them loaded in the trimming interface
- **Technical impact**: Establishes reliable video loading pipeline with proper error handling