## 1. Implementation
- [x] 1.1 Replace raw AVPlayer with SharedVideoPlayer in NameMoveView
- [x] 1.2 Add rotation parameter to AVPlayerViewRepresentable
- [x] 1.3 Implement rotation transform using Apple's recommended approach
- [x] 1.4 Add diagnostic logging for rotation debugging
- [x] 1.5 Test rotation preservation across workflow stages

## 2. Validation
- [x] 2.1 Verify 90° rotation displays correctly in NameMoveView
- [x] 2.2 Verify rotation preserved when navigating back to Trimmer
- [x] 2.3 Verify all rotation angles work (0°, 90°, 180°, 270°)
- [x] 2.4 Test with various video orientations and aspect ratios