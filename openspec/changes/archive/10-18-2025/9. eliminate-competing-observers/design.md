# Design: Eliminate Competing Observer Pattern

## Problem Architecture
```
AddMoveViewModel @Published loadingState
          ↓
┌─────────────────┬─────────────────┐
│   AddMoveView    │   SelectClip    │
│ (line 70)       │ (internal)      │
│ onChange handler │ onChange handler│
│ Step transitions │ Loading UI      │
└─────────────────┴─────────────────┘
          ↓
SwiftUI coalescing sees "multiple updates per frame"
```

## Solution Architecture
```
AddMoveViewModel @Published loadingState
          ↓
┌─────────────────┐
│   SelectClip    │
│ (exclusive)     │
│ onChange handler│
│ Loading UI      │
│ + Step callbacks│
└─────────────────┘
          ↓
Single source of truth for loading state
```

## Key Insights
1. **Single Observer Pattern**: Follow Apple's recommended practice of one observer per @Published property
2. **Callback Communication**: Replace duplicate observation with direct callback from SelectClip to AddMoveView
3. **Frame Separation**: Preserve existing await Task.yield() separation in ViewModel (already working)
4. **Diagnostic Logging**: Add minimal logging to track observer conflicts and frame timing

## MVVM & SRP Compliance
- **SelectClip**: Single responsibility for loading UI and state communication
- **AddMoveView**: Single responsibility for step orchestration
- **AddMoveViewModel**: Single responsibility for state management and frame separation

## Risk Mitigation
- Preserve existing working frame separation logic
- Maintain backward compatibility with existing callback interface
- Add comprehensive logging for debugging future issues