# Fix ViewModel State Collision - AddMove Loading UI Hang

## Problem Statement
The video loading UI in the Add Move feature hangs at 94% due to multiple @Published state updates occurring within the same UI frame, causing SwiftUI's update coalescing mechanism to lose the final `.fullyReady` state.

## Root Cause Analysis
In `AddMoveViewModel.swift`, the `coordinatePlayerInitialization()` function updates the @Published `loadingState` property three times synchronously:

1. `loadingState = .loading(progress: 0.95, stage: .preparingPlayback, ...)`
2. `loadingState = .loading(progress: 0.99, stage: .finalizing, ...)`
3. `loadingState = .fullyReady(asset)`

This triggers the warning: "onChange(of: LoadingState) action tried to update multiple times per frame" and causes the UI to hang at 94%.

## Solution Strategy
Apply frame separation between sequential @Published updates using `await Task.yield()` to ensure each state transition renders in its own UI frame.

## Changes Required

### 1. Revert SharedVideoPlayer.swift
**File**: `breakdex/Features/Shared/Video/VideoPlayer.swift`
**Action**: Restore original "fire-and-forget" Task pattern in `finalizeVideoLoad()`

**Rationale**: The SharedVideoPlayer implementation was correct. The issue is in the ViewModel, not the service layer.

### 2. Fix AddMoveViewModel.swift
**File**: `breakdex/Features/AddMove/ViewModels/AddMoveViewModel.swift`
**Function**: `coordinatePlayerInitialization()`
**Action**: Add `await Task.yield()` between loadingState updates

**Implementation**:
```swift
if playerReady {
    Logger.loadingState.info("📊 Service→ViewModel: 95% - Preparing for playback")
    loadingState = .loading(progress: 0.95, stage: .preparingPlayback, message: "Preparing for playback...")

    // Frame separation for UI update
    await Task.yield()

    Logger.loadingState.info("📊 Service→ViewModel: 99% - Finalizing")
    loadingState = .loading(progress: 0.99, stage: .finalizing, message: "Finalizing...")

    // Frame separation for UI update
    await Task.yield()

    Logger.loadingState.info("📊 Service→ViewModel: 100% - Fully ready")
    let previousState = loadingState
    let newState = LoadingState.fullyReady(asset)

    if newState.validateMonotonicTransition(from: previousState) {
        loadingState = newState
        Logger.loadingState.info("✅ AddMoveViewModel: UI Observation: Monotonic transition to fullyReady successful")
    }
}
```

### 3. Enhanced Diagnostic Logging
Add specific logging to track state transition timing and frame separation effectiveness:

```swift
// Frame timing diagnostics
let frameTimestamp = CFAbsoluteTimeGetCurrent()
Logger.loadingState.debug("🎯 Frame separation: \(frameTimestamp)s - State update: 95%")
```

## Expected Outcomes

### Functional
- Loading UI progresses smoothly: 94% → 95% → 99% → 100%
- No "multiple updates per frame" warnings
- Video loading completes reliably without hanging
- Each loading state is visible to the user

### Technical
- SwiftUI can process each state transition in separate frames
- Proper separation of concerns restored (Service handles business logic, ViewModel handles UI state)
- Enhanced logging provides future debugging insights

## Verification Criteria
1. ✅ Build succeeds without compilation errors
2. ✅ No "multiple updates per frame" warnings in logs
3. ✅ Loading UI visibly progresses through all states
4. ✅ Video loading completes to 100% consistently
5. ✅ Diagnostic logs show frame separation timing

## Risk Mitigation
- **Low Risk**: Changes are minimal and focused on state update timing
- **Reversible**: Easy to revert if unexpected behavior occurs
- **Testable**: Solution can be verified through UI observation and log analysis

## Implementation Notes
- This fix follows MVVM principles by placing UI state management in the ViewModel
- Adheres to SRP by focusing solely on state transition timing
- Uses SwiftUI's built-in concurrency primitives for reliable frame separation
- Maintains existing logging patterns for consistency