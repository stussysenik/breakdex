# Fix SwiftUI View Invalidation Failure

## Why

Users successfully load videos to 100% but the app fails to transition from SelectClip to MinimalTrimmerView, leaving them stuck at the "select a clip" screen despite successful video loading.

## Problem Statement

There's a **SwiftUI view invalidation failure** where the AddMoveView's `currentStep` state changes correctly internally, but the SwiftUI view rendering pipeline fails to recompose the view hierarchy. This creates a disconnect between the ViewModel state and the visual representation.

### Evidence from Logs

1. **State Management Works Correctly:**
   - Video loading reaches 100% ✅
   - AddMoveViewModel transitions to `fullyReady` ✅
   - `currentStep` updates from `ready` to `trimming` ✅
   - `viewTransitionID` changes to force view recomposition ✅

2. **View Rendering Fails:**
   - User sees "select a clip button again" ❌
   - MinimalTrimmerView never appears ❌
   - Despite `currentStep: trimming` being logged ❌

### Root Cause

The issue is at the **SwiftUI view rendering boundary** where `@Published` property changes don't properly trigger view invalidation. The problem is a race condition between:
- ViewModel state updates (working correctly)
- SwiftUI view diffing and recomposition (failing)

## Solution Strategy

### Core Fix: Ensure SwiftUI View Invalidation

Update AddMoveView to use **explicit view invalidation patterns** that guarantee SwiftUI processes state changes correctly, following Apple's recommended practices for view composition.

### Changes Required

#### 1. Fix SwiftUI View Invalidation in AddMoveView
**File:** `breakdex/Features/AddMove/Views/AddMoveView.swift`

**Current problematic pattern:**
```swift
case .trimming:
    MinimalTrimmerView(viewModel: viewModel)
```

**Enhanced implementation with explicit invalidation:**
```swift
case .trimming:
    MinimalTrimmerView(viewModel: viewModel)
        .id("trimmer-\(viewModel.viewTransitionID)") // Force view identity
        .onAppear {
            Logger.ui.debug("✅ MinimalTrimmerView appeared - video should be ready")
        }
```

#### 2. Add Explicit State Synchronization
**File:** `breakdex/Features/AddMove/Views/AddMoveView.swift`

**Enhanced state transition handling:**
```swift
private func handleStepChange(_ newStep: AddMoveStep) {
    Task { @MainActor in
        let oldStep = currentStep
        currentStep = newStep

        // Force SwiftUI view invalidation with explicit timing
        viewTransitionID = UUID().uuidString

        // Small delay to ensure SwiftUI processes the change
        await Task.yield()

        Logger.ui.info("🔄 View transition: \(oldStep) → \(newStep), ID: \(viewTransitionID)")
    }
}
```

#### 3. Add Minimal Diagnostic Logging
**File:** `breakdex/Features/AddMove/Views/AddMoveView.swift`

**Enhanced logging for view lifecycle:**
```swift
.onChange(of: currentStep) { _, newStep in
    Logger.ui.debug("🎯 SwiftUI: currentStep changed to \(newStep)")
}

.onChange(of: viewModel.viewTransitionID) { _, newID in
    Logger.ui.debug("🔄 SwiftUI: viewTransitionID changed to \(newID)")
}
```

## Expected Outcomes

### Functional Behavior
- **Predictable Transitions:** Users selecting videos immediately see MinimalTrimmerView after loading reaches 100%
- **Visual Consistency:** The displayed view matches the ViewModel state at all times
- **Reliable State Sync:** No more "stuck at select clip" despite successful loading

### Technical Behavior
- **SwiftUI Best Practices:** Uses explicit view identity and state synchronization patterns
- **MVVM Compliance:** Clear separation between ViewModel logic and View rendering
- **Enhanced Debugging:** Diagnostic logging provides clear visibility into view lifecycle

## Verification Criteria

### Build and Runtime
1. ✅ Build succeeds without compilation errors
2. ✅ Video selection immediately transitions to MinimalTrimmerView after loading
3. ✅ No "stuck at select clip" behavior observed
4. ✅ Diagnostic logs show clear view transition sequence

### User Experience
1. ✅ Smooth video selection → loading → trimming workflow
2. ✅ Video loads immediately in MinimalTrimmerView when it appears
3. ✅ No confusing state inconsistencies between UI and actual state

### Debugging
1. ✅ View transition logs provide clear troubleshooting information
2. ✅ State changes are traceable through the entire pipeline
3. ✅ Enhanced logging helps identify future issues quickly

## Risk Assessment

**Low Risk Changes:**
- Follows Apple's recommended SwiftUI view invalidation patterns
- Uses explicit view identity to force recomposition (Apple best practice)
- Enhanced logging provides immediate visibility into issues
- Changes are backward compatible

**Mitigation Strategies:**
- Small, focused changes minimize risk
- Diagnostic logging provides immediate feedback
- No changes to core video loading logic
- Follows established MVVM patterns

## Implementation Notes

### Apple Best Practices Alignment (2024-2025)
- **Explicit View Identity:** Using `.id()` modifier to force view recreation when state changes
- **MainActor Isolation:** Ensuring all UI updates happen on main thread
- **Task Yielding:** Using `await Task.yield()` to ensure SwiftUI processes changes
- **Diagnostic Logging:** Enhanced visibility into view lifecycle for debugging

### Architectural Principles
- **Single Responsibility:** View invalidation logic stays in AddMoveView
- **MVVM Pattern:** Clear separation between ViewModel state and View rendering
- **Transparent State:** View transitions are observable and debuggable
- **User Experience Focus:** Immediate visual feedback for state changes

This fix addresses the core SwiftUI rendering issue while maintaining clean architecture and adding valuable debugging capabilities for future development.