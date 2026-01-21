## Why

The video loading system gets stuck at 88% progress due to state management violations that cause the system to reach 100% completion then revert back to 80%, preventing users from completing video import workflow.

## Root Cause Analysis

The current architecture has three competing components managing the same loading state:
1. **RobustVideoLoader** - Service layer handling video asset loading
2. **SharedVideoPlayer** - Player layer handling video playback initialization
3. **AddMoveViewModel** - ViewModel layer handling UI state

These components create race conditions where:
- Loader reaches `fullyReady(100%)` state
- Player initialization triggers state reversion to `loading(80%)`
- UI shows 88% progress and never completes

## What Changes

- **BREAKING**: Remove state retrogression in `LoadingState` enum
- **MODIFIED**: Create single coordinated state management pattern
- **ADDED**: State monotonicity validation to prevent backward transitions
- **ADDED**: Minimal diagnostic logging for future debugging
- **MODIFIED**: Simplify async coordination to eliminate race conditions
- **BREAKING**: Remove competing continuation logic in video loader

## Impact

- **Affected specs**: video-loading (state coordination)
- **Affected code**:
  - `LoadingState.swift` - ensure monotonic state transitions
  - `RobustVideoLoader.swift` - remove competing player initialization logic
  - `AddMoveViewModel.swift` - implement proper state observation
  - `SharedVideoPlayer.swift` - simplify to pure player functionality
- **Breaking changes**: State retrogression removal, coordinated initialization
- **User impact**: Users can successfully complete video import workflow without getting stuck at 88%

## Technical Summary

The core issue is that the current architecture allows state to flow backward: `fullyReady(100%) → loading(80%)`, which violates the principle that loading progress should only increase. This architectural fix ensures state transitions are monotonic (only forward) and eliminates the race conditions between the three components trying to manage the same state.

The solution implements a single source of truth for loading state with proper MVVM separation and 2025 Swift best practices:
- **@MainActor Isolation**: All ViewModels and UI-related state management use `@MainActor` to ensure UI updates happen on the main thread by default
- **Structured Concurrency**: Replace competing continuations with proper `async/await` patterns and `TaskGroup` coordination
- **State Machine Pattern**: Implement deterministic state transitions that prevent retrogression
- **Modern AVFoundation Loading**: Use iOS 18's async AVAsset loading APIs instead of callback-based approaches

The Service layer handles asset loading using modern async patterns, the Player layer handles playback with proper MainActor isolation, and the ViewModel layer coordinates between them using structured concurrency.

Minimal diagnostic logging is added to track state transitions and identify future issues without overwhelming the logs.