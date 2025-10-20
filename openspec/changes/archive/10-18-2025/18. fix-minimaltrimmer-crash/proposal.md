## Why

Video loading crashes during transition to MinimalTrimmerView on physical devices due to infinite recursion in MinimalTrimmerView's rotation property didSet observer, causing EXC_BAD_ACCESS and making the app appear to "hang" at 95% from user perspective.

## Problem Statement

The MinimalTrimmerView rotation property has a didSet observer that calls updateRotation(), which incorrectly sets the rotation property again, triggering infinite recursion until stack overflow. This crash occurs immediately after video loading completes (100%) and transitions to trimming state.

**Evidence from logs and crash report**:
- Video loading successfully reaches 100% and calls onStepChange(.trimming) ✅
- AddMoveView transitions to trimming state and attempts to render MinimalTrimmerView ✅
- Crash occurs at MinimalTrimmerView.swift:1112 in rotation property didSet ❌
- EXC_BAD_ACCESS (code=2, address=0x16f8dbff0) indicates stack overflow from infinite recursion
- User sees app dismiss/crash and returns to "Select a clip" button

**Root cause**: Line 1196 in updateRotation() method sets `rotation = newRotation`, which triggers the didSet observer again, creating infinite recursion.

## What Changes

- **MODIFIED**: MinimalTrimmerView.swift updateRotation() method - Remove recursive rotation property assignment
- **ADDED**: Guard clause in rotation property didSet to prevent unnecessary updateRotation calls
- **ADDED**: Diagnostic logging to track rotation update calls and prevent infinite recursion
- **MAINTAINED**: All existing rotation functionality and MVVM architecture

## Impact

- **Affected capabilities**: add-move-workflow, video-trimming, rotation-management
- **Affected code**:
  - `breakdex/Features/Shared/Video/MinimalTrimmerView.swift:1112 (rotation didSet)`
  - `breakdex/Features/Shared/Video/MinimalTrimmerView.swift:1196 (updateRotation method)`
- **Breaking changes**: None - preserves existing rotation interface and behavior
- **User impact**: Video loading completes successfully and MinimalTrimmerView appears without crashing
- **Performance impact**: Improved - eliminates infinite recursion and stack overflow