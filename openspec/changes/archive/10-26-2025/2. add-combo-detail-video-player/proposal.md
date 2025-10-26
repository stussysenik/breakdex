## Why
ComboDetailView currently displays timeline nodes for navigation but lacks a central video player to show the selected move's video. Users expect to tap timeline nodes and see the corresponding video play, which is the core functionality missing from the combo viewing experience.

## What Changes
- Add video player section to ComboDetailView between header and timeline
- Add state management for video loading, player instance, and loading states
- Connect timeline node selection to video loading using existing PhotosAssetLoader
- Implement loading states and error handling for video playback
- Use existing AVPlayerViewRepresentable for consistent video playback experience

## Impact
- Affected specs: `combo-detail-view` (new capability)
- Affected code: `Features/Combo/Views/ComboDetailView.swift`
- Dependencies: Existing `PhotosAssetLoader`, `AVPlayerViewRepresentable`, and shared loading components