# Why
Two views (AddMoveView and SelectClip) observing the same @Published loadingState property simultaneously, causing SwiftUI "multiple updates per frame" warnings and UI hangs at 94-98% during video loading.

## What Changes
- Remove duplicate onChange observer in AddMoveView (line 70)
- Enhance SelectClip → AddMoveView communication through callbacks
- Add minimal diagnostic logging to track observer conflicts
- Preserve existing frame separation in ViewModel

## Impact
- **Affected specs**: add-move state management
- **Affected code**: AddMoveView.swift, SelectClip.swift, AddMoveViewModel.swift
- **Expected outcome**: Smooth loading progression 94% → 95% → 99% → 100% without UI hangs