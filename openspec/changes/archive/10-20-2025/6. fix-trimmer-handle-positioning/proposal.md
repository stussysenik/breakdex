## Why
The MinimalTrimmerView has a systematic discrepancy where ViewModel trim values (trimStartTime: 24.125s, trimEndTime: 34.125s) are not properly propagated to local state (startTime: 0.0s, endTime: 0.0s), causing handles to position incorrectly at timeline bounds instead of the selected trim range.

## What Changes
- Fix state initialization order in MinimalTrimmerView setupTrimmerDirect()
- Enhance timeline visual implementation with coordinate space management from FeatureRichTrimmerView
- Add proper handle positioning with named coordinate space for drag gestures
- Implement enhanced time-to-coordinate conversion functions
- Fix condition evaluation for ViewModel trim value inheritance

## Impact
- Affected specs: video-trimming (new capability)
- Affected code: Features/Shared/Video/MinimalTrimmerView.swift:687-696 (state initialization), Features/Shared/Video/MinimalTrimmerView.swift:325-488 (timeline implementation)
- **BREAKING**: Changes handle positioning behavior to correctly display selected trim range

## Note: I've used FeatureRichTrimmerView for reference here.