# Design: Fix Trimmer Highlight Alignment

## Current Implementation Analysis

### Coordinate System Issues
The current `MinimalTrimmerView.swift` uses different coordinate calculations for handles vs highlight:

**Handles (lines 356, 388):**
```swift
.offset(x: timeToCoordinate(startTime, totalWidth: timelineGeometry.size.width) + (handleWidth / 2.0))
```

**Highlight (lines 338-350):**
```swift
HStack(spacing: 0) {
    Rectangle()
        .fill(Color.clear)
        .frame(width: timeToCoordinate(startTime, totalWidth: timelineGeometry.size.width))

    Capsule()
        .fill(Color.blue.opacity(0.4))
        .frame(width: timeToCoordinate(endTime - startTime, totalWidth: timelineGeometry.size.width))

    Rectangle()
        .fill(Color.clear)
}
```

### Root Cause
1. `timeToCoordinate()` returns coordinates within available track (totalWidth - handleWidth)
2. Handles add handle radius to center themselves on the track
3. Blue highlight uses HStack layout that doesn't account for handle center positioning
4. This creates visual misalignment

## Proposed Solution

### New Coordinate Calculations
```swift
// Calculate handle center coordinates explicitly
let startHandleCenterCoord = timeToCoordinate(startTime, totalWidth: timelineGeometry.size.width) + (handleWidth / 2.0)
let endHandleCenterCoord = timeToCoordinate(endTime, totalWidth: timelineGeometry.size.width) + (handleWidth / 2.0)
let highlightWidth = max(0, endHandleCenterCoord - startHandleCenterCoord)

// Single Rectangle positioned absolutely
Rectangle()
    .fill(Color.blue.opacity(0.4))
    .frame(width: highlightWidth, height: 40)
    .offset(x: startHandleCenterCoord)
```

### Benefits
1. **Precise Alignment**: Highlight spans exactly from handle center to handle center
2. **Simplified Logic**: Single Rectangle instead of complex HStack
3. **Better Performance**: Fewer layout calculations
4. **Visual Consistency**: No more "floating" appearance

## Implementation Details

### Location
- File: `Features/Shared/Video/MinimalTrimmerView.swift`
- Function: `timelineSection` -> `GeometryReader` -> `ZStack`
- Lines: Around 386 (the ZStack containing timeline elements)

### Changes Required
1. Remove existing HStack-based highlight (lines 338-350)
2. Add new coordinate calculations before handles
3. Replace with single Rectangle using absolute positioning
4. Update handle .offset() to use calculated center coordinates

### Edge Cases Handled
- Handles at extreme positions (0s and videoDuration)
- Minimum duration constraints
- Zero-width highlight when handles touch
- Video rotation (no impact on timeline alignment)

## Testing Strategy

### Visual Tests
1. Handles at 0s: highlight starts at left handle center
2. Handles at max: highlight ends at right handle center
3. Handles together: highlight width becomes 0
4. Drag operations: highlight tracks handles smoothly

### Coordinate Validation
1. Verify startHandleCenterCoord matches left handle .offset()
2. Verify endHandleCenterCoord matches right handle .offset()
3. Verify highlightWidth = endHandleCenterCoord - startHandleCenterCoord
4. Verify highlight never exceeds timeline bounds