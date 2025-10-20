## 1. Implementation
- [x] 1.1 Add SharedVideoPlayer cleanup method with proper observer removal
- [x] 1.2 Update AddMoveViewModel.reset() to call SharedVideoPlayer cleanup
- [x] 1.3 Add session boundary diagnostic logging with thread safety
- [x] 1.4 Ensure MainActor isolation for all cleanup operations
- [x] 1.5 Add minimal diagnostic logging for session tracking

## 2. Validation
- [x] 2.1 Run openspec validate with strict mode
- [x] 2.2 Test cancel-trim-select-new-clip workflow 10 times consecutively
- [x] 2.3 Verify diagnostic logs show proper session isolation
- [x] 2.4 Confirm 100% success rate for multi-session video loading
- [x] 2.5 Validate no KVO observer leaks or memory issues