## Why
Complete the migration to clean MVVM architecture by removing temporary adapter files and legacy services, ensuring all views use AddMoveViewModel directly following MVVM, SRP, and WYSIWYG principles.

## What Changes
- Replace MinimalTrimmerViewAdapter with actual MinimalTrimmerView implementation
- Migrate NameMoveView to use AddMoveViewModel directly (remove adapter)
- Remove legacy adapter files: NameMoveViewAdapter, MinimalTrimmerViewAdapter
- Remove legacy services: VideoLoadingService, VideoLoadingPerformanceMonitor
- Remove LegacyCompatibility wrapper
- Ensure clean MVVM separation throughout the add-move workflow

## Impact
- Affected specs: add-move-workflow, video-loading, ui-components
- Affected code: AddMove feature views and services
- **BREAKING**: Removes adapter compatibility layer
- Improves maintainability and follows established architecture patterns