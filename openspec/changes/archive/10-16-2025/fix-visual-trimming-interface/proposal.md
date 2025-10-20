## Why
The MinimalTrimmerView has functional core components but suffers from spatial design issues and non-functional drag handles. Based on user feedback and logs showing "Trimming cancelled" events, the interface needs improved visual hierarchy, proper spacing, and working interactive controls.

## What Changes
- Fix horizontal and vertical spacing in MinimalTrimmerView layout
- Implement functional start/end drag handles with proper gesture handling
- Add centered playhead indicator for visual timeline feedback
- Ensure timeline components stay within screen bounds
- Improve visual hierarchy between video player, time displays, and timeline
- Add submit button functionality to proceed to NameMoveView

## Impact
- Affected specs: video-trimming (new capability)
- Affected code: MinimalTrimmerView.swift, TrimModification.swift, AddMoveUnifiedState.swift
- User experience: Enhanced precision for "mechanical watch" accurate video trimming
- Performance: Maintains current AVFoundation efficiency with improved UI responsiveness