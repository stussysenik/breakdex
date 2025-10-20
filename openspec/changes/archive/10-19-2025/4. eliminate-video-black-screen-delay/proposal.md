## Why

Users returning to the Add Move tab within 5 seconds experience a 2-3 second black screen before video appears, breaking the expected instantaneous video display behavior. This is caused by unnecessary player cleanup cycles and temporal mismatch between async preloading and sync view appearance.

## What Changes

- **MODIFIED**: SharedVideoPlayer lifecycle management to maintain player instance across tab navigation
- **MODIFIED**: AddMoveViewModel workflow suspension to avoid player cleanup during quick return scenarios
- **MODIFIED**: AddMoveView state coordination to ensure player readiness before view transition
- **ADDED**: Minimal diagnostic logging for player state transitions and timing metrics
- **REMOVED**: Comprehensive player cleanup during workflow suspension for quick returns

## Impact

- **Affected specs**: video-player, add-move-workflow
- **Affected code**:
  - `breakdex/Features/Shared/Video/SharedVideoPlayer.swift` (maintain instance across navigation)
  - `breakdex/Features/AddMove/ViewModels/AddMoveViewModel.swift` (remove cleanup during suspension)
  - `breakdex/Features/AddMove/Views/AddMoveView.swift:128-140` (coordinate timing)
- **User impact**: Instantaneous video display when returning to Add Move tab, no black screen delay
- **Technical impact**: Reduced resource contention, eliminated unnecessary reload cycles
- **Breaking changes**: None - maintains existing interface while improving performance