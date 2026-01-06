## 1. Fix ViewModel Logic
- [x] 1.1 Update AddMoveViewModel.swift handleVideoLoaded() to default trimStartTime to 0.0
- [x] 1.2 Remove lastTenSecondsStart calculation and assignment
- [x] 1.3 Add diagnostic logging for trim initialization

## 2. Fix Handle Coordinate Math
- [x] 2.1 Add handleWidth constant (20.0) to MinimalTrimmerView
- [x] 2.2 Update timeToCoordinate function to account for handle boundaries
- [x] 2.3 Update coordinateToTime function to account for handle boundaries
- [x] 2.4 Add enhanced logging for coordinate calculations

## 3. Validation
- [x] 3.1 Test with video of different durations
- [x] 3.2 Verify handles stay within timeline bounds
- [x] 3.3 Verify default trim starts at 00:00:00
- [x] 3.4 Verify minimum duration constraints still work

## 4. Documentation
- [x] 4.1 Update code comments with coordinate calculation logic
- [x] 4.2 Archive this change with proper documentation