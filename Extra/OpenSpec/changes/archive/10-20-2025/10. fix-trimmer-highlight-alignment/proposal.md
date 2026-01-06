# Fix Trimmer Highlight Alignment

## Summary
Fix visual discrepancy in MinimalTrimmerView where the blue selected range highlight appears to "float" and doesn't align properly with trim handle centers, creating poor user experience during video trimming.

## Problem
The blue highlight that shows the selected trim range doesn't align with the handle centers because:
1. Blue highlight is positioned using coordinates within the *available track* (totalWidth - handleWidth)
2. Handles are positioned by adding handle radius to those coordinates
3. This creates a mismatch where highlight appears to float and have incomplete fill

## Solution
Modify the timeline section in `MinimalTrimmerView.swift` to calculate handle center coordinates explicitly and position the blue highlight to span precisely from the center of the left handle to the center of the right handle.

## Changes
- Replace the HStack-based highlight with a single Rectangle positioned absolutely
- Calculate handle center coordinates explicitly: `timeToCoordinate(...) + (handleWidth / 2.0)`
- Position highlight to start at left handle center and extend to right handle center
- Use Rectangle instead of Capsule for precise edges

## Files
- `Features/Shared/Video/MinimalTrimmerView.swift` (timelineSection ZStack around line 386)

## Validation
- Visual alignment test: blue highlight edges align perfectly with handle centers
- Edge case test: handles at 0s and videoDuration show full highlight
- Dragging test: highlight tracks handles precisely during drag operations