## Why
Fix critical Swift compilation errors that are preventing the breakdex iOS app from building successfully for the precision video trimming feature.

## What Changes
- Fix GeometryProxy Equatable conformance issue in PrecisionTrimmerTimeline.swift:42
- Resolve type mismatch between CGFloat and Int64 in PrecisionTrimmerTimeline.swift:156
- Make calculateTimeFromDragPosition method accessible in PrecisionTrimmerTimeline.swift:334
- Fix minimumDurationMs access level in PrecisionTimecodeDisplay.swift:221

## Impact
- Affected specs: video-trimming, ui-components
- Affected code: PrecisionTrimmerTimeline.swift, PrecisionTimecodeDisplay.swift, TrimmerInteractionManager.swift
- **BREAKING**: None - these are compilation error fixes restoring intended functionality