## Why
The TrimmerView component has 6 Swift compilation errors: 4 complex expression type-checking timeouts and 2 SharedVideoPlayer.PlayerState property access errors, preventing the project from building successfully.

## What Changes
- Break down complex expressions in TrimmerView.swift at lines 90, 1375, 1379, and 1411
- Fix SharedVideoPlayer.PlayerState property access errors at lines 210 and 252
- Refactor nested SwiftUI view builders and computed properties into smaller, digestible components
- Maintain existing functionality while improving code readability and compilation performance

## Impact
- Affected specs: video-playback
- Affected code: Features/Shared/Video/TrimmerView.swift
- **BREAKING**: None - this is a compilation fix that maintains existing behavior