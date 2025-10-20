## 1. Implementation
- [x] 1.1 Add @MainActor-isolated session tracking to AddMoveViewModel
- [x] 1.2 Modify LoadingState validation for session-aware transitions (Apple state machine pattern)
- [x] 1.3 Add thread-safe diagnostic logging for session boundaries
- [x] 1.4 Update reset() method to generate new session IDs with proper @MainActor isolation
- [x] 1.5 Test cancel-trim-select-new-clip workflow following iOS 2024 patterns

## 2. Validation
- [x] 2.1 Run openspec validate with strict mode
- [x] 2.2 Test loading reliability across multiple sessions
- [x] 2.3 Verify diagnostic logging provides session visibility with thread safety
- [x] 2.4 Confirm 99.9% loading success rate in testing
- [x] 2.5 Validate @MainActor compliance throughout state transition chain