# Tasks: Fix Trimmer Highlight Alignment

## Ordered Work Items

### 1. Backup Current Implementation
- [x] Create backup of current `MinimalTrimmerView.swift` timeline section
- [x] Document current coordinate calculation approach for reference
- [x] Verify current visual behavior with screenshots

### 2. Implement Coordinate Calculation Fix
- [x] Locate the `timelineSection` ZStack in `MinimalTrimmerView.swift` (around line 386)
- [x] Remove existing HStack-based highlight implementation (lines 338-350)
- [x] Add explicit handle center coordinate calculations:
  ```swift
  let startHandleCenterCoord = timeToCoordinate(startTime, totalWidth: timelineGeometry.size.width) + (handleWidth / 2.0)
  let endHandleCenterCoord = timeToCoordinate(endTime, totalWidth: timelineGeometry.size.width) + (handleWidth / 2.0)
  let highlightWidth = max(0, endHandleCenterCoord - startHandleCenterCoord)
  ```

### 3. Replace Highlight Implementation
- [x] Replace HStack with single Rectangle implementation:
  ```swift
  Rectangle()
      .fill(Color.blue.opacity(0.4))
      .frame(width: highlightWidth, height: 40)
      .offset(x: startHandleCenterCoord)
  ```
- [x] Update handle `.offset()` calls to use calculated center coordinates
- [x] Ensure consistent use of `handleWidth` constant throughout

### 4. Update Handle Positioning
- [x] Modify left handle offset to use `startHandleCenterCoord`
- [x] Modify right handle offset to use `endHandleCenterCoord`
- [x] Verify handle `.frame()` uses `handleWidth` constant for consistency

### 5. Build and Syntax Validation
- [x] Run `swiftc -parse Features/Shared/Video/MinimalTrimmerView.swift` to check syntax
- [x] Run `xcodebuild -project breakdex.xcodeproj -scheme breakdex build` to verify compilation
- [x] Fix any compilation errors before proceeding

### 6. Visual Testing and Validation
- [x] Test with handles at 0s position - verify highlight starts at handle center
- [x] Test with handles at maximum position - verify highlight ends at handle center
- [x] Test handles touching - verify highlight width becomes 0
- [x] Test drag operations - verify highlight tracks handles smoothly
- [x] Test minimum duration constraints - verify alignment remains correct

### 7. Edge Case Testing
- [x] Test with very short videos (< 5 seconds)
- [x] Test with different video orientations (rotation affects timeline layout)
- [x] Test with different simulator screen sizes
- [x] Test rapid handle movements - verify no visual lag

### 8. Performance Validation
- [x] Verify no performance regression in drag operations
- [x] Check coordinate calculation efficiency
- [x] Validate memory usage remains stable
- [x] Test with 60fps drag performance

### 9. Documentation Updates
- [x] Update inline comments explaining new coordinate approach
- [x] Document the fix in CLAUDE.md if needed
- [x] Add diagnostic logging for coordinate calculations if helpful for future debugging

### 10. Final Verification
- [x] Complete visual inspection across all test scenarios
- [x] Verify accessibility features still work correctly
- [x] Confirm no regressions in other trimmer functionality
- [x] Final build verification and testing

## Dependencies
- Requires access to `MinimalTrimmerView.swift`
- Requires iOS 18.0 simulator for testing
- Requires video assets for comprehensive testing

## Parallelizable Work
- Items 2, 3, and 4 can be done in sequence as a single implementation step
- Items 6 and 7 can be tested in parallel with different video assets
- Items 5, 8, 9 can be done independently once implementation is complete