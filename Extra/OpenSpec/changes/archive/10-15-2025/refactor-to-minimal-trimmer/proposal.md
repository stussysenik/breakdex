## Why
The EnhancedTrimmerView introduces unnecessary complexity with 539+ lines, heavy coordinator dependencies, and over-engineered components. The MinimalTrimmerView provides the same core functionality with cleaner architecture, better maintainability, and simpler state management while following the project's essentialism principles.

## What Changes
- Replace EnhancedTrimmerView with MinimalTrimmerView throughout the application
- Remove VideoTrimmerCoordinator dependency and related coordinator files
- Update AddMoveView to use MinimalTrimmerView instead of EnhancedTrimmerView
- Simplify video trimming workflow by using direct SharedVideoPlayer integration
- Remove enhanced trimmer components (EnhancedTrimHandleView, TimelineView, PlayheadView)
- Maintain all existing functionality: trim range selection, rotation, preview, and navigation

## Impact
- **Affected specs**: video-trimming-interface
- **Affected code**:
  - `breakdex/Features/Shared/Video/Trimmer/Views/EnhancedTrimmerView.swift` (remove)
  - `breakdex/Features/Shared/Video/MinimalTrimmerView.swift` (keep, ensure integration)
  - `breakdex/Features/AddMove/Views/AddMoveView.swift` (update usage)
  - Related coordinator and component files (remove)
- **Benefits**: Reduced complexity (~200+ lines removed), better maintainability, cleaner architecture aligned with SRP and essentialism principles