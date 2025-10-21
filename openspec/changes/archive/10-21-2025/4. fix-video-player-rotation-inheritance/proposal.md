## Why
Video rotation applied during trimming is lost when navigating to the NameMoveView, causing videos to display in their original orientation instead of the user-selected rotated orientation.

## What Changes
- Standardize video player architecture across all workflow stages
- Ensure rotation state preservation through the video pipeline
- Add minimal diagnostic logging for rotation debugging
- **BREAKING**: NameMoveView will use SharedVideoPlayer instead of raw AVPlayer

## Impact
- Affected specs: video-player-display
- Affected code: Features/AddMove/Views/NameMoveView.swift, Features/Shared/Video/AVPlayerViewRepresentable.swift