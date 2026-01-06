## Why
Multiple video player implementations with conflicting names are causing compilation errors. There are duplicate `SharedVideoPlayerView` definitions across different files, leading to "ambiguous type lookup" errors that prevent the project from building.

## What Changes
- Remove duplicate VideoPlayerView.swift file that conflicts with the comprehensive VideoPlayer.swift implementation
- Consolidate to a single, comprehensive video player system following MVVM pattern
- Update references in MoveDetailView.swift to use the correct video player components
- Remove stub SharedVideoPlayerView definition from SharedButton.swift
- Maintain existing SharedVideoPlayer class and VideoPlayerView from VideoPlayer.swift

## Impact
- Affected specs: video-playback
- Affected code: Features/Shared/Video/VideoPlayerView.swift (removed), Features/Arsenal/Views/MoveDetailView.swift (updated), Features/Shared/UI/Components/SharedButton.swift (cleaned)
- Build system: Resolves compilation errors and provides clean video player architecture
- User experience: Consistent video playback across the app