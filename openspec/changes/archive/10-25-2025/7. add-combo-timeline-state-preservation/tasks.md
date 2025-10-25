## 1. Core Data State Preservation Implementation
- [x] 1.1 Add timeline node state preservation logic to ComboViewModel.saveCombo()
- [x] 1.2 Add timeline node state restoration logic to ComboDetailView.loadComboMoves()
- [x] 1.3 Implement NSManagedObjectID to Data conversion utilities
- [x] 1.4 Add proper logging for state save/restore operations

## 2. Video Playback Navigation Enhancement
- [x] 2.1 Update ComboDetailView.moveDetailView() to use MoveDetailView
- [x] 2.2 Verify navigationDestination properly handles MoveDetailView
- [ ] 2.3 Test video playback functionality from timeline nodes
- [ ] 2.4 Ensure proper SharedVideoPlayer integration

## 3. Touch Target Optimization
- [x] 3.1 Remove redundant gesture handling in ComboListView.ComboRowView
- [x] 3.2 Ensure NavigationLink handles entire row tap target
- [x] 3.3 Preserve haptic feedback functionality
- [ ] 3.4 Test navigation behavior after cleanup

## 4. MoveListView Swipe-to-Delete Implementation
- [x] 4.1 Create MoveRowView component matching ComboRowView structure
- [x] 4.2 Add swipeActions with full-swipe delete functionality
- [x] 4.3 Implement deleteMove method in ArsenalViewModel if missing
- [x] 4.4 Add proper haptic feedback and error handling
- [x] 4.5 Update MoveListView to use new MoveRowView component

## 5. Testing and Validation
- [ ] 5.1 Unit tests for NSManagedObjectID conversion utilities
- [ ] 5.2 Integration tests for end-to-end timeline state preservation
- [ ] 5.3 UI tests for swipe-to-delete functionality in MoveListView
- [ ] 5.4 Manual testing of video playback from timeline nodes
- [ ] 5.5 Validation of touch target responsiveness improvements