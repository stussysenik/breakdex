## Why
MinimalTrimmerView fails to appear when SwiftUI attempts to render it during the trimming workflow, despite all state transitions working correctly (AddMoveViewModel → SelectClip → AddMoveView with currentStep: trimming). The onAppear modifier for MinimalTrimmerView never fires, indicating a fundamental rendering issue within the view itself rather than state management problems.

## What Changes
- **Root Cause Analysis**: Investigate why MinimalTrimmerView.onAppear never triggers despite correct state transitions
- **View Initialization Fix**: Resolve the underlying SwiftUI rendering issue preventing MinimalTrimmerView from appearing
- **Diagnostic Logging**: Add minimal, targeted logging to verify view lifecycle events and debug future issues
- **State Validation**: Ensure proper state synchronization between AddMoveViewModel and MinimalTrimmerView
- **Performance Optimization**: Remove any blocking operations or timing dependencies that could prevent view rendering

## Impact
- **Affected specs**: video-trimming-interface, add-move-workflow
- **Affected code**:
  - `breakdex/Features/Shared/Video/MinimalTrimmerView.swift`
  - `breakdex/Features/AddMove/Views/AddMoveView.swift` (diagnostic logging only)
- **User impact**: Users cannot proceed past video selection to trimming stage, breaking the core add move workflow
- **Technical impact**: Resolves a critical view rendering bottleneck while maintaining MVVM architecture and clean separation of concerns