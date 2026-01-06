## 1. Implementation
- [x] 1.1 Create atomic state transition structure in RobustVideoLoader
- [x] 1.2 Replace separate progress/stage updates with atomic updates
- [x] 1.3 Add @MainActor isolation to loading state management
- [x] 1.4 Add minimal diagnostic logging for stage timing
- [x] 1.5 Update AddMoveViewModel to handle atomic state transitions
- [x] 1.6 Verify LoadingState calculation matches atomic updates
- [x] 1.7 Test cancel-trim-select-new-clip workflow

## 2. Testing
- [x] 2.1 Verify atomic state transitions eliminate race conditions
- [x] 2.2 Test progress display accuracy during stage transitions
- [x] 2.3 Verify 99.9% loading reliability across multiple sessions
- [x] 2.4 Validate diagnostic logging provides actionable insights