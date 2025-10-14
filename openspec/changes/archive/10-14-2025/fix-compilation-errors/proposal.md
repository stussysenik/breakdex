## Why
Critical compilation errors are blocking the build and preventing the app from running. The errors involve main thread publishing violations, syntax issues in pattern matching, and incorrect async function handling.

## What Changes
- Fix main thread publishing issues in UnifiedState.swift by ensuring all @Published property updates happen on MainActor
- Fix tuple pattern matching syntax error in TrimmerView.swift
- Fix async function conversion error in VideoPlayer.swift TaskGroup usage
- Ensure all UI state updates follow Swift 6 concurrency requirements

## Impact
- Affected specs: state-management, video-playback, video-trimming
- Affected code: UnifiedState.swift, TrimmerView.swift, VideoPlayer.swift
- **BREAKING**: None - these are syntax and compliance fixes only