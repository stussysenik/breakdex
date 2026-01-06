## Why
The video container in NameMoveView has fixed dimensions that don't account for video rotation transforms, causing 1740px width overflow and 900px height overflow. This leads to CoreGraphics NaN errors and system instability that breaks MoveDetailView navigation.

## What Changes
- Add aspect ratio handling to video container in NameMoveView.swift
- Add view clipping to prevent overflow beyond container bounds
- Add minimal diagnostic logging to detect overflow conditions early
- Fix container to properly fit rotated video content

## Impact
- Affected specs: UI layout and video rendering
- Affected code: NameMoveView.swift (lines 82-84, 116-117)
- Fixes CoreGraphics NaN errors that cause system-wide instability
- Restores MoveDetailView navigation functionality