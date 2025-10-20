## Context

The breakdex app is a video flashcard application for athletes to catalog and review training movements. The current video trimming interface (MinimalTrimmerView) has several critical issues:

1. **Poor Visual Feedback**: Timeline lacks clear visual indicators for trim range and playback position
2. **Synchronization Issues**: Video playback and trim interface are not properly synchronized
3. **Limited Precision**: Difficult to achieve millisecond-level precision needed for movement analysis
4. **Accessibility Gaps**: Missing proper VoiceOver support and haptic feedback
5. **Performance Issues**: Laggy interactions and inefficient rendering

Athletes using the app need "mechanical watch" precision when selecting specific moments from training footage for creating flashcards.

## Goals / Non-Goals

**Goals:**
- Create an intuitive, visually appealing trimming interface with mechanical watch precision
- Implement seamless synchronization between video playback and timeline interaction
- Ensure 60fps performance across all device types and video formats
- Provide comprehensive accessibility support for inclusive user experience
- Maintain Clean Architecture principles with proper separation of concerns
- Support frame-accurate trimming across various video formats and frame rates

**Non-Goals:**
- Adding complex video editing features beyond basic trimming
- Implementing advanced effects or transitions
- Creating a professional video editing suite
- Supporting video compositing or multi-track editing

## Decisions

### Decision 1: Component Architecture
**What**: Adopt a modular component architecture with separate, focused components for timeline, handles, playhead, and controls.

**Why**:
- Follows Single Responsibility Principle for maintainability
- Enables independent testing and optimization of each component
- Allows for better accessibility implementation per component
- Supports future enhancements without affecting core functionality

**Alternatives considered**:
- Monolithic view approach (rejected for complexity and maintainability)
- External video editing library (rejected for dependency bloat and customization limitations)

### Decision 2: State Management Approach
**What**: Use a centralized TrimmerState ObservableObject with computed properties for derived state.

**Why**:
- Provides single source of truth for all trimming-related state
- Enables reactive UI updates with SwiftUI
- Simplifies debugging and state synchronization
- Supports undo/redo functionality with minimal overhead

**Alternatives considered**:
- Distributed state across components (rejected for synchronization complexity)
- External state management library (rejected for over-engineering)

### Decision 3: Video Playback Integration
**What**: Enhance existing VideoPlayer with delegate pattern for precise position callbacks and playback control.

**Why**:
- Leverages existing, proven video playback infrastructure
- Provides frame-accurate position reporting
- Maintains consistency with rest of app
- Allows for seamless integration with current Core Data models

**Alternatives considered**:
- AVPlayerView directly (rejected for limited customization)
- Custom video player implementation (rejected for complexity and maintenance burden)

### Decision 4: Timeline Rendering Strategy
**What**: Use SwiftUI Canvas for high-performance custom timeline rendering with optimized drawing.

**Why**:
- Provides 60fps performance with efficient GPU acceleration
- Enables precise control over visual elements and animations
- Supports complex visual feedback requirements
- Maintains smooth interaction across device types

**Alternatives considered**:
- HStack with Spacer-based layout (rejected for performance limitations)
- UIKit-based custom view (rejected for SwiftUI integration complexity)

### Decision 5: Accessibility Implementation
**What**: Implement accessibility through semantic views and custom actions with comprehensive VoiceOver support.

**Why**:
- Ensures inclusive design for athletes with different abilities
- Provides iOS-native accessibility experience
- Supports dynamic type and high contrast modes
- Enables keyboard navigation and switch control

**Alternatives considered**:
- Minimal accessibility implementation (rejected for inclusivity requirements)
- Post-development accessibility add-on (rejected for better integrated approach)

## Risks / Trade-offs

### Risk: Performance with Large Video Files
**Mitigation**: Implement progressive thumbnail loading and efficient memory management with caching strategies.

### Risk: Video Format Compatibility
**Mitigation**: Comprehensive testing across various formats, frame rates, and device types with fallback mechanisms.

### Risk: Complex Interaction States
**Mitigation**: Careful state machine design with comprehensive testing and error handling.

### Trade-off: Feature Complexity vs Usability
**Decision**: Prioritize core trimming functionality with mechanical precision over advanced features to maintain simplicity and performance.

### Trade-off: Custom Implementation vs Third-party Library
**Decision**: Custom implementation for precise control and no external dependencies, accepting higher development effort for better long-term maintainability.

## Migration Plan

### Phase 1: Foundation (Week 1-2)
- Set up new component architecture
- Implement basic timeline rendering
- Create state management foundation
- Add basic video playback integration

### Phase 2: Core Functionality (Week 3-4)
- Implement drag handles and trim range selection
- Add playhead synchronization
- Create control panel interface
- Add basic validation and error handling

### Phase 3: Polish and Accessibility (Week 5-6)
- Implement comprehensive accessibility features
- Add haptic feedback and animations
- Optimize performance across devices
- Complete testing and validation

### Phase 4: Integration and Deployment (Week 7-8)
- Integrate with existing workflow
- Update documentation and tests
- Final validation and deployment preparation
- Monitor and address any post-deployment issues

### Rollback Plan
- Maintain current MinimalTrimmerView as fallback option
- Implement feature flags for gradual rollout
- Prepare quick revert mechanism if critical issues arise
- Maintain backward compatibility for existing data

## Open Questions

1. **Video Processing Strategy**: Should trim processing happen client-side or server-side for large files?
2. **Offline Support**: What level of offline functionality is required for trimming operations?
3. **Cloud Sync**: How should trimming progress sync across devices for the same user?
4. **Performance Metrics**: What specific performance targets should we establish for timeline interactions?
5. **User Testing**: How can we best involve athletes in the testing process to validate precision requirements?