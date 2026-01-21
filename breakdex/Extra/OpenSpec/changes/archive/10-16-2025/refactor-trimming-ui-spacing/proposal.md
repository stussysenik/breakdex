## Why
The current MinimalTrimmerView implementation suffers from inadequate vertical spacing, improper visual hierarchy, and timeline components that don't achieve the desired "mechanical watch" precision. Users need a frictionless, precise trimming interface with clear visual separation between functional zones.

## What Changes
- Refactor vertical spacing system using consistent 8-point grid (32pt separation between major sections)
- Reorganize timeline visual hierarchy with proper layer ordering (Base Track → Highlight → Playhead → Handles)
- Add visual breathing room with consistent horizontal padding (16pt) and section separators
- Improve timeline height and touch targets for better interaction
- Create clear layout zones: Display (Top) → Interactive Ruler (Middle) → Actions (Bottom)

## Impact
- Affected specs: video-trimming (new capability)
- Affected code: breakdex/Features/Shared/Video/MinimalTrimmerView.swift
- Breaking: No breaking changes - UI refinements only