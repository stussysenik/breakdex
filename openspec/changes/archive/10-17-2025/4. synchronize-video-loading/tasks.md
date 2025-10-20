# Synchronize Video Loading: Single AddMoveViewModel Implementation Tasks

## Simple Implementation Plan

### Phase 1: Remove TrimmerViewModelProtocol (Critical)

#### 1.1 Remove Protocol Complexity
- [ ] DELETE TrimmerViewModelProtocol from MinimalTrimmerView.swift
- [ ] Remove all protocol conformance requirements
- [ ] Eliminate asset transfer methods from protocol
- [ ] Remove complex asset validation methods from protocol

**Files to modify:**
- `breakdex/Features/Shared/Video/MinimalTrimmerView.swift` (lines 8-31)

#### 1.2 Simplify AddMoveViewModel Extension
- [ ] Remove AddMoveViewModel extension that implements TrimmerViewModelProtocol
- [ ] Keep only essential AddMoveViewModel functionality
- [ ] Remove transfer-specific methods from AddMoveViewModel

**Validation:** Compilation succeeds without protocol dependencies

### Phase 2: Single SharedVideoPlayer Instance (Critical)

#### 2.1 Move SharedVideoPlayer to AddMoveViewModel
- [ ] Add `@Published var videoPlayer: SharedVideoPlayer = SharedVideoPlayer(mode: .main)` to AddMoveViewModel
- [ ] Update AddMoveViewModel.loadVideo() to load directly into self.videoPlayer
- [ ] Set trim ranges when video loads (trimEndTime = duration, trimStartTime = max(0, duration-10))

**Code changes:**
```swift
// AddMoveViewModel.swift
@Published var videoPlayer: SharedVideoPlayer = SharedVideoPlayer(mode: .main)

func loadVideo(from item: PhotosUI.PhotosPickerItem) async {
    // Load directly into self.videoPlayer
    let asset = try await videoLoader.loadVideo(from: item)
    await videoPlayer.loadVideo(asset)

    // Set trim ranges
    let duration = asset.duration.seconds
    trimEndTime = duration
    trimStartTime = max(0, duration - 10)

    loadingState = .fullyReady(asset)
    currentStep = .trimming
}
```

#### 2.2 Update MinimalTrimmerView to Use AddMoveViewModel Directly
- [ ] Change MinimalTrimmerView to observe AddMoveViewModel instead of protocol
- [ ] Remove `@StateObject private var videoPlayer` from MinimalTrimmerView
- [ ] Update VideoPlayerView to use `viewModel.videoPlayer`
- [ ] Remove setupTrimmerWithGuard() and waitForPlayerReadiness() methods

**Code changes:**
```swift
// MinimalTrimmerView.swift
struct MinimalTrimmerView: View {
    @ObservedObject var viewModel: AddMoveViewModel  // Direct observation

    var body: some View {
        VStack {
            VideoPlayerView(player: viewModel.videoPlayer)  // Direct player use
            // Timeline binds to viewModel.trimStartTime/trimEndTime
            // Actions call viewModel methods directly
        }
        .onAppear {
            // Player already loaded, just initialize UI if needed
        }
    }
}
```

**Validation:** Video displays immediately when transitioning to trimming view

### Phase 3: Clean View Architecture (High Priority)

#### 3.1 Simplify SelectClip View
- [ ] Ensure SelectClip only forwards video selection to AddMoveViewModel
- [ ] Remove any business logic from SelectClip
- [ ] Keep SelectClip as "dumb" UI component

#### 3.2 Simplify NameMoveView
- [ ] Ensure NameMoveView only binds to AddMoveViewModel properties
- [ ] Remove any validation logic from NameMoveView
- [ ] Keep NameMoveView as "dumb" UI component

#### 3.3 Update AddMoveView Flow
- [ ] Ensure AddMoveView transitions based on viewModel.currentStep
- [ ] Remove complex state coordination logic
- [ ] Keep flow simple: ready → selecting → trimming → naming → saving

**Validation:** All views are simple UI with no business logic

### Phase 4: Enhanced Diagnostic Logging (Medium Priority)

#### 4.1 Add Comprehensive Logging
- [ ] Log video loading completion in AddMoveViewModel with asset details
- [ ] Log player state transitions in AddMoveViewModel
- [ ] Log trim range updates with validation results
- [ ] Add performance metrics for each operation

#### 4.2 Remove Complex Transfer Logging
- [ ] Remove asset transfer logging (no longer needed)
- [ ] Remove waitForPlayerReadiness logging
- [ ] Remove setupTrimmerWithGuard logging
- [ ] Keep only essential state transition logging

**Validation:** Clear, comprehensive logs for debugging the flow

### Phase 5: Testing (Medium Priority)

#### 5.1 Unit Tests
- [ ] Test AddMoveViewModel video loading directly into videoPlayer
- [ ] Test trim range validation in AddMoveViewModel
- [ ] Test state transitions in AddMoveViewModel

#### 5.2 Integration Tests
- [ ] Test complete flow: SelectClip → MinimalTrimmerView → NameMoveView
- [ ] Test video displays immediately in trimming view
- [ ] Test no asset transfer needed

#### 5.3 UI Tests
- [ ] Test smooth transitions between add move steps
- [ ] Test video player controls in trimming view
- [ ] Test trim range adjustments

**Validation:** All tests pass, no 10% freeze scenarios

## Success Criteria

### Functional Requirements
- [ ] Video loads and displays immediately in trimming view (no 10% freeze)
- [ ] Single SharedVideoPlayer instance used throughout flow
- [ ] AddMoveViewModel manages entire add move flow
- [ ] Views are "dumb" with no business logic
- [ ] No TrimmerViewModelProtocol complexity

### Architectural Requirements
- [ ] Follows MVVM principles (direct View → ViewModel observation)
- [ ] Follows SRP (each component has single responsibility)
- [ ] Validated by 2025 SwiftUI best practices
- [ ] Clean, maintainable code structure

### Performance Requirements
- [ ] Video displays within 1 second of loading completion
- [ ] No asset transfer overhead
- [ ] Memory efficient (single player instance)
- [ ] Smooth UI transitions

## Risk Assessment

**Risk Level: Very Low**
- **Architectural simplification** (removing complexity, not adding)
- **No breaking changes** to public APIs
- **Follows established patterns** (single ViewModel per flow)
- **Eliminates bottleneck** rather than adding new complexity

**Mitigation Strategies:**
- Test thoroughly with existing video formats
- Verify no regressions in current functionality
- Maintain all existing error handling
- Keep diagnostic logging for debugging

## Implementation Timeline

**Week 1:** Phase 1-2 (Critical architecture changes)
**Week 2:** Phase 3-4 (Clean architecture and logging)
**Week 3:** Phase 5 (Testing and validation)

## Files Modified

### Primary Changes
- `breakdex/Features/AddMove/ViewModels/AddMoveViewModel.swift` - Add videoPlayer property
- `breakdex/Features/Shared/Video/MinimalTrimmerView.swift` - Remove protocol, use AddMoveViewModel directly
- `breakdex/Features/AddMove/Views/AddMoveView.swift` - Simple flow transitions

### Testing Files
- `BreakingFlashcardsTests/AddMoveViewModelTests.swift` - Test single player instance
- `BreakingFlashcardsUITests/AddMoveFlowTests.swift` - Test complete flow

## Expected Outcome

**Before Fix:**
- UI freezes at 10% with "initializing video player"
- Complex TrimmerViewModelProtocol adds unnecessary abstraction
- Asset transfer between separate player instances fails

**After Fix:**
- Immediate video display when transitioning to trimming
- Single AddMoveViewModel manages entire flow
- Direct player sharing eliminates bottleneck
- Clean MVVM architecture following 2025 best practices

**Result:** Users can smoothly add moves without any loading freezes or confusing states.