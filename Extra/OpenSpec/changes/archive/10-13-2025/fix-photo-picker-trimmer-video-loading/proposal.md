# Fix Photo Picker to Trimmer Video Loading

## Why
**Critical Issue**: The app crashes with "Too many open files" causing Core Data failure and preventing the core user flow of selecting videos from Photos and loading them into the TrimmerView. The previous attempt shows resource leaks and inadequate error handling that block the essential AddMove workflow.

## What Changes
- **Fix Resource Management**: Eliminate file handle leaks in video loading pipeline that cause "Too many open files" crashes
- **Minimalistic Diagnostic Logging**: Implement focused, essential logging only for critical state transitions and errors
- **Robust Error Recovery**: Strengthen error handling in PersistenceBridge and video loading chain
- **Streamlined Video Loading**: Simplify PhotosPickerItem → Loading UI → TrimmerView flow with proper cleanup
- **Memory Management**: Optimize AVAsset handling and cleanup throughout the video loading process

## Impact
- **Affected code**:
  - Features/Shared/Services/PersistenceBridge.swift (Core Data stability fixes)
  - Features/Shared/Services/VideoLoadingService.swift (resource leak fixes)
  - Features/AddMove/Views/SelectClip.swift (streamlined photo picker integration)
  - Features/Shared/Models/UnifiedState.swift (cleaner state management)
- **User impact**: Users can successfully complete the core workflow: Add Move tab → Select Clip → Choose from Photos → Loading UI → TrimmerView with loaded video
- **Technical impact**: Stable, resource-efficient video loading that won't crash the app or corrupt Core Data store