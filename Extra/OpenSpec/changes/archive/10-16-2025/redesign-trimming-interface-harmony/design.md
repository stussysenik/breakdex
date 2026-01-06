## Context
The current MinimalTrimmerView has advanced functionality but lacks visual harmony and precision in user interactions. Users report difficulty with floating handles, visual noise from the playhead, and friction in the rotation workflow. The interface needs to follow iOS 18 direct manipulation principles while maintaining existing performance characteristics.

## Goals / Non-Goals
- **Goals:**
  - Achieve visual harmony between video preview and timeline controls
  - Implement direct manipulation for all interactions (no modals)
  - Improve precision through better spatial grounding of controls
  - Maintain existing performance optimizations and AVFoundation integration
  - Follow iOS 18 design patterns for video editing interfaces

- **Non-Goals:**
  - Complete redesign of the video playback engine
  - Changes to core trim modification logic or data models
  - Breaking changes to existing AddMoveUnifiedState integration
  - Addition of new editing features beyond the scope mentioned

## Decisions

### Decision: Edge-Aligned Timeline Layout
**What:** Timeline width will match video player preview width with consistent margins
**Why:** Creates visual harmony and spatial relationship between content and controls
**Alternatives considered:**
- Full-width timeline (rejected: creates visual dissonance with video)
- Floating timeline (rejected: lacks spatial grounding)

### Decision: Edge-Anchored Trim Controls
**What:** Replace floating circular handles with edge-anchored trim controls
**Why:** Provides better precision and spatial grounding for drag operations
**Alternatives considered:**
- Improved floating handles (rejected: still lack spatial reference)
- Slider-style controls (rejected: less precise for video trimming)

### Decision: Direct Rotation on Tap
**What:** Implement immediate 90-degree rotation on button tap without modal
**Why:** Follows iOS 18 direct manipulation principles, reduces interaction friction
**Alternatives considered:**
- Improved modal sheet (rejected: still adds friction)
- Gesture-based rotation (rejected: complex to discover and implement)

### Decision: Remove Red Playhead
**What:** Remove visual playhead indicator from timeline
**Why:** Creates visual noise without functional benefit; users can see playback in video preview
**Alternatives considered:**
- Improved playhead design (rejected: still adds visual complexity)
- Optional playhead (rejected: adds configuration complexity)

## Risks / Trade-offs

### Risk: User Familiarity
**Risk:** Users may be accustomed to traditional timeline playhead indicators
**Mitigation:** Focus on clear visual feedback in video preview; maintain timecode displays

### Risk: Handle Precision
**Risk:** New edge-anchored controls may have different precision characteristics
**Mitigation:** Implement thorough testing and haptic feedback for precise control

### Trade-off: Visual Simplicity vs. Information Density
**Trade-off:** Removing playhead reduces visual noise but also removes a timeline reference
**Decision:** Prioritize clean, direct manipulation with clear video preview feedback

## Migration Plan

### Phase 1: Layout Updates
1. Update timeline positioning and constraints
2. Align timeline width with video player
3. Add safe area boundaries

### Phase 2: Control Redesign
1. Replace floating handles with edge-anchored controls
2. Update gesture handling for new controls
3. Add haptic feedback system

### Phase 3: Interaction Simplification
1. Remove playhead visual indicator
2. Implement direct rotation on tap
3. Update state management for new interactions

### Phase 4: Integration and Testing
1. Full workflow testing
2. Performance validation
3. Accessibility compliance verification

### Rollback Plan
- Keep existing implementation commented in code for rapid rollback
- Maintain feature flags for critical UI changes
- Prepare regression tests for core functionality

## Open Questions
- Should edge-anchored handles include visual indicators for current trim duration?
- How should the new rotation system handle rapid successive taps?
- What specific haptic feedback patterns work best for different handle interactions?

## Category Theory Analysis

### Objects and Morphisms
- **Objects:** VideoPlayer, Timeline, TrimControls, RotationControl, State
- **Morphisms:** seek, trim, rotate, validate, updateState
- **Functors:** UI ↔ State transformations maintaining structure

### Natural Transformations
- User interaction → Visual feedback (maintaining consistency)
- Video metadata → UI constraints (preserving relationships)
- Trim validation → State updates (maintaining invariants)

The redesign maintains the categorical structure while improving the natural transformations to be more direct and intuitive.