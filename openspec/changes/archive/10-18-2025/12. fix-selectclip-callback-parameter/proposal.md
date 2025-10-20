## Why
The AddMove flow gets stuck at 95% loading and never transitions to the MinimalTrimmerView, despite backend processing completing successfully. The root cause is a SwiftUI view composition issue where the `.trimming` case is not being executed despite `@State` changes being detected correctly.

## What Changes
- Force SwiftUI view recomposition when transitioning to .trimming state
- Add explicit view state validation and debugging
- Ensure proper SwiftUI state propagation for view switching

## Impact
- **Affected specs**: add-move-workflow, view-transition-handling
- **Affected code**: AddMoveView.swift switch statement, state handling
- **Breaking change**: No - restores intended functionality
- **User impact**: Critical - users cannot proceed past video loading screen