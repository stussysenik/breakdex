## Why

The current video state persistence implementation works correctly for app backgrounding/foregrounding but fails for tab navigation. When users switch away from the Add Move tab and back, SwiftUI's TabView lifecycle causes view state reset while @StateObject preserves ViewModel state correctly. This creates a mismatch where AddMoveView's @State currentStep resets to `.ready` even though the ViewModel's suspended workflow state is preserved, violating the MVVM principle where view state should reflect ViewModel state.

## What Changes

- **MODIFIED**: AddMoveView.swift setupInitialState() method to check for suspended workflow state
- **ADDED**: State-aware view initialization logic that synchronizes @State currentStep with @StateObject ViewModel workflowState
- **ADDED**: Diagnostic logging following iOS 18 best practices for state synchronization debugging
- **MAINTAINED**: All existing @StateObject preservation mechanisms and MVVM architecture principles
- **ENHANCED**: View initialization follows Apple's guidance for "lightweight and cheap" view setup

## Impact

- **Affected specs**: add-move-workflow, video-state
- **Affected code**:
  - `breakdex/Features/AddMove/Views/AddMoveView.swift:118-123` (setupInitialState method)
- **User impact**: Seamless video trimming experience across TabView navigation with no state loss
- **Technical impact**: Proper state synchronization between SwiftUI @State lifecycle and @StateObject ViewModel persistence
- **Breaking changes**: None - preserves existing interface and behavior patterns
- **iOS 18 Compatibility**: Follows iOS 18 TabView best practices and modern SwiftUI state management patterns