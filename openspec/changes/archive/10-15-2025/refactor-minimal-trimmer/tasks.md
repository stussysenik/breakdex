## 1. Foundation and Structure
- [x] 1.1 Create new MinimalTrimmerView with basic structure
- [x] 1.2 Define simple state model (startTime, endTime, isPlaying, rotation)
- [x] 1.3 Create basic timeline component with drag handles
- [x] 1.4 Set up video player integration with SharedVideoPlayer

## 2. Core Trimming Functionality
- [x] 2.1 Implement drag gesture handling for trim handles
- [x] 2.2 Add visual feedback for trim range selection
- [x] 2.3 Implement universal frame rate detection and adaptation
- [x] 2.4 Create timecode calculation system for all frame rates (24fps, 30fps, 60fps, 120fps, VFR)
- [x] 2.5 Implement frame-accurate trimming with timecode display (HH:MM:SS:FF + milliseconds)
- [x] 2.6 Add trim validation (minimum 3 seconds)
- [x] 2.7 Create play/pause controls for trim preview

## 3. Visual Timeline Implementation
- [ ] 3.1 Generate video thumbnail strip with frame-accurate positioning
- [x] 3.2 Style trim handles with clear visual indicators and frame boundaries
- [x] 3.3 Add highlight overlay for selected range with frame precision
- [x] 3.4 Implement smooth animations for handle movements across all frame rates
- [x] 3.5 Create adaptive timeline scaling for different video durations

## 4. Rotation Workflow
- [x] 4.1 Add rotation button to trimmer interface
- [x] 4.2 Create rotation selection UI (90°, 180°, 270°, 360°)
- [x] 4.3 Implement instant rotation preview with smooth animation
- [x] 4.4 Update workflow to proceed to NameMoveView after rotation

## 5. Workflow Integration
- [x] 5.1 Update AddMoveUnifiedState to use MinimalTrimmerView
- [x] 5.2 Integrate with existing video loading and error handling
- [x] 5.3 Update navigation flow from SelectClip → Trimmer → Rotation → NameMove
- [x] 5.4 Handle edge cases (video loading errors, invalid trim ranges)

## 6. Testing and Validation
- [ ] 6.1 Create unit tests for trim state management
- [ ] 6.2 Add UI tests for drag handle interactions
- [ ] 6.3 Test integration with existing video processing pipeline
- [ ] 6.4 Validate performance on various video sizes and formats

## 7. File Cleanup and Migration
- [ ] 7.1 Delete over-engineered files (TrimmerState, TrimmerInteractionManager, PrecisionTrimmerTimeline)
- [ ] 7.2 Simplify TrimModification to basic struct with 3 properties
- [ ] 7.3 Simplify PrecisionTimecodeDisplay to SimpleTimecodeDisplay
- [ ] 7.4 Review and keep RotatedVideoPlayer & VideoRotationControls if simple
- [ ] 7.5 Remove old complex TrimmerView after validation
- [ ] 7.6 Clean up unused dependencies and imports
- [ ] 7.7 Update documentation and comments

## 8. Final Validation
- [ ] 8.1 Build verification with xcodebuild
- [ ] 8.2 Manual testing on physical device
- [ ] 8.3 Performance profiling for memory and CPU usage
- [ ] 8.4 Final review and approval of simplified interface