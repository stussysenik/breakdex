# Fix Progress Calculation Mismatch

## Why

Users report being "stuck at 98%" during video loading because there's a systematic discrepancy between the progress percentage developers intend to display versus what's actually calculated and shown to users.

## Problem Statement

The video loading progress display has a **calculation mismatch** between developer intent and user experience:

### Evidence from Logs
1. **Developer sets:** `loadingState = .loading(progress: 0.95, stage: .preparingPlayback, ...)` (intending to show 95%)
2. **User sees:** "Loading progress: 98%" (calculated as 0.95 + (0.95 × 0.04) = 0.988 = 98.8%)
3. **Result:** User thinks they're stuck at 98% even though the system reaches 100% and transitions successfully

### Root Cause
In `LoadingState.swift`, the progress calculation formula:
```swift
calculatedProgress = stage.baseProgress + (progress * stage.weight)
```

For `preparingPlayback` stage (base: 0.95, weight: 0.04):
- Intended: 95% progress
- Actual: 0.95 + (0.95 × 0.04) = 98.8%

This creates a UX disconnect where users see unexpected percentages that don't align with smooth progression.

## Solution Strategy

### Core Fix: Align Progress Display with User Expectations

Update the AddMoveViewModel to use stage-relative progress values that produce the expected user-visible percentages, following modern SwiftUI @Observable best practices for transparent state management.

### Changes Required

#### 1. Fix AddMoveViewModel Progress Values
**File:** `breakdex/Features/AddMove/ViewModels/AddMoveViewModel.swift`

**Current problematic code:**
```swift
loadingState = .loading(progress: 0.95, stage: .preparingPlayback, message: "Preparing for playback...")
loadingState = .loading(progress: 0.99, stage: .finalizing, message: "Finalizing...")
```

**Fixed implementation:**
```swift
loadingState = .loading(progress: 0.0, stage: .preparingPlayback, message: "Preparing for playback...")
// Calculation: 0.95 + (0.0 × 0.04) = 0.95 = 95%

loadingState = .loading(progress: 0.0, stage: .finalizing, message: "Finalizing...")
// Calculation: 0.99 + (0.0 × 0.01) = 0.99 = 99%
```

#### 2. Add Minimal Diagnostic Logging
**File:** `breakdex/Features/AddMove/ViewModels/AddMoveViewModel.swift`

**Enhanced logging for progress transitions:**
```swift
Logger.loadingState.debug("📊 Progress transition: \(Int(oldProgress * 100))% → \(Int(newProgress * 100))% (\(stage))")
```

#### 3. Add Progress Display Validation
**File:** `breakdex/Features/AddMove/ViewModels/AddMoveViewModel.swift`

**Validation helper:**
```swift
private func validateProgressDisplay(_ stage: LoadingStage, internalProgress: Double) -> Double {
    let calculatedProgress = stage.baseProgress + (internalProgress * stage.weight)
    let displayPercentage = Int(calculatedProgress * 100)
    Logger.loadingState.debug("🔍 Progress display validation: \(stage) = \(displayPercentage)%")
    return calculatedProgress
}
```

## Expected Outcomes

### Functional Behavior
- **Predictable Progress:** Users see expected percentages (95%, 99%, 100%) instead of confusing values (98.8%)
- **Smooth UX:** No perception of being "stuck" due to unexpected progress display
- **Accurate State:** Internal state remains correct while display aligns with expectations

### Technical Behavior
- **MVVM Compliance:** ViewModel manages state calculation, View displays resulting values
- **Single Responsibility:** Progress calculation logic stays in LoadingState, display values in ViewModel
- **Enhanced Observability:** Diagnostic logging helps future debugging
- **State Consistency:** No functional changes to loading logic, only display calculations

## Verification Criteria

### Build and Runtime
1. ✅ Build succeeds without compilation errors
2. ✅ Video loading reaches 100% successfully
3. ✅ Progress shows expected values: 95% → 99% → 100%
4. ✅ No "stuck at 98%" user perception

### Diagnostic Logging
1. ✅ Progress transitions logged with before/after values
2. ✅ Stage-based calculations validated and logged
3. ✅ Display percentage validation helps future debugging

### User Experience
1. ✅ Users see expected, predictable progress percentages
2. ✅ Smooth progression without confusing percentage jumps
3. ✅ Clear perception that loading is working correctly

## Risk Assessment

**Low Risk Changes:**
- Progress calculation uses existing stage-based system
- No changes to core video loading logic
- Enhanced logging provides debugging capability
- Changes are backward compatible

**Mitigation Strategies:**
- Easy to revert if unexpected behavior occurs
- Enhanced logging provides immediate visibility
- No changes to video loading or state transition logic
- Follows established MVVM patterns

## Implementation Notes

### Architectural Principles
- **MVVM Pattern:** ViewModel handles progress display logic, View displays values
- **Single Responsibility:** LoadingState maintains calculation logic, AddMoveViewModel handles display values
- **Transparent State:** Progress calculations are observable and debuggable
- **User Experience Focus:** Display aligns with user expectations

### Apple Best Practices Alignment (2025)
- **@Observable Pattern:** Using modern SwiftUI observation for state management
- **Declarative UI:** Progress display derived directly from observable state
- **Predictable Updates:** State changes trigger immediate UI updates
- **Debugging Support:** Enhanced logging for development insights

This fix addresses the core UX issue while maintaining clean architecture and adding valuable debugging capabilities for future development.