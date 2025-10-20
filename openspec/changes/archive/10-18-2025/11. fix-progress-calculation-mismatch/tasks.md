# Fix Progress Calculation Mismatch - Implementation Tasks

## Task 1: Update AddMoveViewModel Progress Values
**File:** `breakdex/Features/AddMove/ViewModels/AddMoveViewModel.swift`
**Location:** Lines 381 and 389 (coordinatePlayerInitialization function)

### Changes Required
- [x] Update `preparingPlayback` stage progress from `0.95` to `0.0`
- [x] Update `finalizing` stage progress from `0.99` to `0.0`
- [x] Verify calculations produce expected display percentages (95% and 99%)

### Validation
- [x] Test video loading shows 95% during preparing playback stage
- [x] Test video loading shows 99% during finalizing stage
- [x] Confirm 100% is reached successfully

## Task 2: Add Diagnostic Logging
**File:** `breakdex/Features/AddMove/ViewModels/AddMoveViewModel.swift`

### Changes Required
- [x] Add progress transition logging in coordinatePlayerInitialization
- [x] Add stage-based calculation validation logging
- [x] Add display percentage validation helper method

### Implementation Details
```swift
// Add before each state transition:
Logger.loadingState.debug("📊 Progress transition: \(Int(oldProgress * 100))% → \(Int(newProgress * 100))% (\(stage))")

// Add validation helper:
private func validateProgressDisplay(_ stage: LoadingStage, internalProgress: Double) -> Double {
    let calculatedProgress = stage.baseProgress + (internalProgress * stage.weight)
    let displayPercentage = Int(calculatedProgress * 100)
    Logger.loadingState.debug("🔍 Progress display validation: \(stage) = \(displayPercentage)%")
    return calculatedProgress
}
```

### Validation
- [x] Logs show clear before/after progress values
- [x] Stage calculations are logged and verifiable
- [x] Display percentages are validated in logs

## Task 3: Update AddMoveViewModel Extension
**File:** `breakdex/Features/AddMove/ViewModels/AddMoveViewModel.swift`
**Location:** Lines 632-634 (progressPercentage computed property)

### Changes Required
- [x] Add diagnostic logging to progressPercentage calculation
- [x] Log raw loadingState.progress vs displayed percentage
- [x] Validate progress calculation alignment

### Implementation Details
```swift
public var progressPercentage: Int {
    let rawProgress = loadingState.progress
    let displayPercentage = Int(rawProgress * 100)
    Logger.loadingState.debug("🔍 Progress display: raw=\(rawProgress), display=\(displayPercentage)%")
    return displayPercentage
}
```

### Validation
- [x] Progress percentage logs show calculation details
- [x] Display values match expected percentages
- [x] No regression in progress reporting

## Task 4: Build Verification
**Command:** `xcodebuild -project breakdex.xcodeproj -scheme breakdex -destination 'platform=iOS Simulator,name=iPhone 16' build`

### Validation
- [x] Build succeeds without compilation errors
- [x] No warnings related to progress calculation
- [x] All logging statements compile correctly

## Task 5: Integration Testing
**Test Scenario:** Complete video loading workflow

### Test Steps
- [x] Launch app and navigate to Add Move
- [x] Select video from PhotosPicker
- [x] Observe progress display throughout loading
- [x] Verify smooth progression: 95% → 99% → 100%
- [x] Confirm transition to MinimalTrimmerView
- [x] Check logs for proper diagnostic output

### Expected Results
- [x] User sees expected percentages (not 98.8%)
- [x] No perception of being "stuck"
- [x] Logs show clear progress transition details
- [x] Video loading completes successfully

## Task 6: Regression Testing
**Test Areas:**
- [x] Video loading with different video formats
- [x] iCloud download scenarios
- [x] Error handling during loading
- [x] State transition consistency
- [x] Memory usage during loading

### Validation
- [x] No regression in existing functionality
- [x] Error states still display correctly
- [x] Performance impact is minimal
- [x] Memory usage remains stable

## Task 7: Documentation Update
**Files:** Update inline documentation if needed

### Changes Required
- [x] Document progress calculation approach in AddMoveViewModel
- [x] Add comments explaining stage-relative progress values
- [x] Update any related API documentation

### Validation
- [x] Code comments explain the fix clearly
- [x] Documentation matches implementation
- [x] Future developers understand the approach

## Dependencies
- **Task 1** must be completed before Task 2
- **Task 2** must be completed before Task 3
- **Task 4** must be completed before Task 5
- **Task 5** must be completed before Task 6

## Notes
- Focus on minimal, precise changes
- Maintain existing architecture patterns
- Add valuable diagnostic capabilities
- Ensure no functional regressions