## Why
When users click "Cancel" during video trimming, they remain stuck in the trimming view instead of returning to video selection. This creates a broken user experience where the cancel button doesn't perform its expected function.

## What Changes
- Fix state synchronization between AddMoveViewModel and AddMoveView
- Add state observation to detect ViewModel reset events
- Ensure cancel button transitions user back to video selection
- Add minimal diagnostic logging for debugging

## Impact
- Affected specs: add-move-workflow
- Affected code: AddMoveView.swift (state observation), MinimalTrimmerView.swift (existing cancel logic)
- User Experience: Cancel button will work as expected
- Reliability: Deterministic state transitions during cancel operations