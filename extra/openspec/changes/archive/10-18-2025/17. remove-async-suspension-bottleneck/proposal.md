## Why

Video loading hangs at 95% on physical devices due to async task suspension points in AddMoveViewModel's coordinatePlayerInitialization method that cause continuation timeouts on device hardware, preventing transition to MinimalTrimmerView.

## Problem Statement

The coordinatePlayerInitialization method in AddMoveViewModel.swift uses `await MainActor.run {}` and `await Task.yield()` calls during critical state transitions (95% → 99% → 100%). These async suspension points work on simulator (fast hardware) but timeout on physical devices (slower hardware, memory pressure), breaking the video loading flow.

**Evidence from logs**:
- Line 167: "Hang detected: 0.37s (debugger attached, not reporting)"
- Lines 390-392: First async suspension gap at 95% stage
- Lines 406-408: Second async suspension gap at 99% stage
- Physical devices: Async continuation timeout during suspension
- Simulator: Tasks resume quickly, no timeout

**Root cause**: Task suspension during critical state transitions creates timing-dependent failures on physical devices.

## What Changes

- **MODIFIED**: AddMoveViewModel.swift coordinatePlayerInitialization method - Replace async suspension points with synchronous state updates
- **ADDED**: Asset-based validation fallback for device-specific AVPlayer readiness timing differences
- **ADDED**: Minimal diagnostic logging to track async task behavior and state transition timing
- **MAINTAINED**: All existing MVVM architecture and AddMoveViewModel interface

## Impact

- **Affected capabilities**: add-move-workflow, video-loading
- **Affected code**:
  - `breakdex/Features/AddMove/ViewModels/AddMoveViewModel.swift:390-392, 406-408`
- **Breaking changes**: None - preserves existing AddMoveViewModel interface
- **User impact**: Video loading reliably completes to 100% and transitions to MinimalTrimmerView on both simulator and physical devices
- **Performance impact**: Improved - eliminates async suspension overhead during critical transitions