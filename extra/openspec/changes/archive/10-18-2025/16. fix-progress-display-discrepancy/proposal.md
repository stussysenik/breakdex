# Fix Progress Display Discrepancy

## Why

Users successfully load videos to 100% and the AddMoveViewModel correctly transitions to `fullyReady` state, but the SelectClip UI still shows 95% progress, creating a disconnect between the actual loading state and what users see. This breaks the expected video selection → loading → trimming workflow.

## Problem Statement

There is a **systematic discrepancy** between progress values in the loading pipeline:

1. **AddMoveViewModel** correctly sets loading states and calculates overall progress (95% → 99% → 100%)
2. **LoadingState** properly calculates absolute progress using `baseProgress + (progress × weight)` formula
3. **SelectClip UI** incorrectly observes raw stage-relative progress instead of calculated absolute progress

### Evidence from Analysis

- **Line 164**: AddMoveViewModel logs "100% - Fully ready" ✅
- **Line 167**: SelectClip observes "raw=0.6, display=60%" ❌
- **Line 175**: SelectClip observes "0% (preparingPlayback)" instead of 95% ❌

The issue is in `SelectClip.swift:149` where `let progressPercent = Int(progress * 100)` uses the raw stage-relative progress parameter instead of the calculated overall progress.

## What Changes

- **MODIFIED**: SelectClip.swift - Fix progress observation to use calculated absolute progress
- **ADDED**: Minimal diagnostic logging to track progress source discrepancies
- **MAINTAINED**: All existing MVVM architecture and AddMoveViewModel interface

## Impact

- **Affected capabilities**: add-move-workflow, loading-progress, video-selection
- **Affected code**:
  - `breakdex/Features/AddMove/Views/SelectClip.swift:147-150`
- **Breaking changes**: None - preserves existing AddMoveViewModel and LoadingState interfaces
- **User impact**: Users see accurate progress throughout loading and immediate transition to MinimalTrimmerView after 100%
- **Technical impact**: Ensures consistent progress observation across the entire loading pipeline