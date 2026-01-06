# Design: Ensuring Finalizing State Observation

## Architecture Analysis

### Current State Management Flow
```
AddMoveViewModel (Producer) → SwiftUI @Observable (Transport) → SelectClip (Consumer)
     ↓                           ↓                              ↓
preparingPlayback → Frame Coalescing → preparingPlayback observed
finalizing      → Frame Coalescing → SKIPPED ❌
fullyReady      → Frame Coalescing → fullyReady observed
```

### Target State Management Flow
```
AddMoveViewModel (Producer) → SwiftUI @Observable (Transport) → SelectClip (Consumer)
     ↓                           ↓                              ↓
preparingPlayback → Frame Boundary → preparingPlayback observed ✅
finalizing      → Frame Boundary → finalizing observed ✅
fullyReady      → Frame Boundary → fullyReady observed ✅
```

## Technical Problem Space

### SwiftUI Observation Constraints
- SwiftUI processes @Observable updates on main runloop frames (~16.67ms at 60fps)
- Multiple state updates within same frame are coalesced into final state
- Intermediate states are lost when updates occur too quickly
- Frame boundaries are required for each state to be observed

### Temporal Synchronization Requirements
- Each state transition must cross at least one UI frame boundary
- MainActor execution must be ensured for state consistency
- State propagation timing must be measurable and diagnosable
- Observation delays should be minimal but sufficient

## Solution Architecture

### Frame Boundary Enforcement Pattern
```swift
// Pattern: State → MainActor Sync → Frame Separation → Next State
await MainActor.run { }  // Ensure main thread execution
await Task.yield()       // Cross frame boundary
// State is now guaranteed to be observed
```

### State Transition Protocol
1. **State Setting Phase**: Set new loading state on MainActor
2. **Frame Boundary Phase**: Force frame boundary crossing
3. **Observation Phase**: UI processes and observes the state
4. **Validation Phase**: Confirm observation before proceeding

### Diagnostic Framework
- **Timing Detection**: Measure state setting vs observation timing
- **Frame Validation**: Detect same-frame state updates
- **Propagation Tracking**: Verify complete state transition chain
- **Performance Monitoring**: Ensure minimal overhead

## Implementation Strategy

### Phase 1: Analysis and Instrumentation
- Add high-precision timing to current state transitions
- Measure current frame coalescing behavior
- Establish baseline for state propagation delays

### Phase 2: Frame Separation Implementation
- Implement MainActor synchronization pattern
- Add frame boundary enforcement between state transitions
- Validate that each state reaches UI observation

### Phase 3: Diagnostic Enhancement
- Add comprehensive state propagation logging
- Implement frame coalescing detection
- Create observability for future debugging

### Phase 4: Validation and Optimization
- Test complete state transition sequence
- Verify user experience improvement
- Optimize diagnostic logging for production

## Risk Mitigation

### Technical Risks
- **Performance Impact**: Minimize overhead from frame separation
- **Timing Issues**: Use conservative frame boundary timing
- **Compatibility**: Maintain existing API contracts

### Mitigation Strategies
- **Incremental Implementation**: Add frame separation gradually
- **Rollback Capability**: Keep existing code as fallback
- **Comprehensive Testing**: Validate at each implementation phase

## Success Criteria

### Functional Requirements
- All intermediate states (95%, 99%, 100%) are observed by UI
- Smooth user experience without perceptible jumps
- Complete diagnostic visibility into state propagation

### Technical Requirements
- State transitions occur across separate UI frames
- MainActor synchronization is guaranteed
- Diagnostic logging provides actionable insights
- No performance regression in video loading

### Architectural Requirements
- MVVM pattern is preserved and enhanced
- SwiftUI observation best practices are followed
- Code remains maintainable and debuggable
- Solution scales to future state management needs