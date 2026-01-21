# Ensure Finalizing State Observation

## Why

Users get stuck at 95% during video loading because the 99% finalizing state is never observed by the UI due to SwiftUI's frame coalescing mechanism, causing a perceptible jump from 95% directly to 100% and then to trimming.

## Problem Statement

The AddMoveViewModel correctly sets the loading state through the proper progression: preparingPlayback (95%) → finalizing (99%) → fullyReady (100%), but SelectClip view only observes: preparingPlayback (95%) → fullyReady (100%), skipping the finalizing state entirely.

### Evidence from Logs
- AddMoveViewModel sets finalizing state at line 400 ✅
- SelectClip still shows preparingPlayback state at line 155 ❌
- Finalizing state logs are completely missing from UI observation
- User sees: 95% → 100% → trimming (skipping 99%)

### Root Cause
SwiftUI's @Observable system coalesces multiple state updates that occur within the same UI frame into a single update, causing the intermediate finalizing state to be skipped during the observation cycle.

## What Changes

- **MODIFIED**: AddMoveViewModel.swift - Ensure temporal separation between preparingPlayback → finalizing → fullyReady state transitions
- **ADDED**: Frame boundary detection to prevent state coalescing
- **ADDED**: Minimal diagnostic logging for state propagation timing
- **MAINTAINED**: All existing MVVM architecture and API contracts

## Impact

- **Affected specs**: add-move-workflow, loading-progress
- **Affected code**:
  - `breakdex/Features/AddMove/ViewModels/AddMoveViewModel.swift:386-418`
- **Breaking changes**: None - preserves existing AddMoveViewModel interface
- **User impact**: Users see smooth progression 95% → 99% → 100% before transitioning to trimming
- **Performance impact**: Minimal - ensures proper UI frame timing

## Technical Solution

**Current Problematic Pattern**:
```swift
// Multiple state updates in rapid succession within same frame
loadingState = .loading(progress: 0.0, stage: .preparingPlayback, ...)
await Task.yield()  // Insufficient separation
loadingState = .loading(progress: 0.0, stage: .finalizing, ...)
await Task.yield()  // Insufficient separation
loadingState = .fullyReady(asset)  // Finalizing state skipped by UI
```

**Fixed Solution**:
```swift
// Ensure each state update reaches UI before next update
loadingState = .loading(progress: 0.0, stage: .preparingPlayback, ...)
await MainActor.run { }  // Force main thread synchronization
await Task.yield()  // Allow UI processing

loadingState = .loading(progress: 0.0, stage: .finalizing, ...)
await MainActor.run { }  // Force main thread synchronization
await Task.yield()  // Allow UI processing

loadingState = .fullyReady(asset)  // Now properly observed after finalizing
```

**Key Principles**:
1. **MainActor Synchronization**: Ensure each state is set on main thread
2. **Frame Boundary Enforcement**: Use `await MainActor.run { }` to cross frame boundaries
3. **Observation Guarantee**: Each intermediate state reaches the UI before the next state
4. **Minimal Diagnostics**: Track state propagation timing without verbose logging

## Apple Documentation Alignment

Following iOS 18 and 2025 Apple best practices:
- **@MainActor Enforcement**: Leverage enhanced main-thread guarantees in iOS 18
- **SwiftUI Observation**: Ensure single state update per UI frame for reliable propagation
- **Swift Concurrency**: Use proper async/await patterns with actor isolation
- **MVVM Architecture**: Maintain clean separation between ViewModel and View layers