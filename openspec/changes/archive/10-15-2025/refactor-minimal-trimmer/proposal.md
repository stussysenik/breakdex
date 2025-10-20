## Why
The current TrimmerView implementation has grown to 25,859 lines of code, making it unmaintainable and unusable. The visual interface is overwhelming with too many controls, states, and abstractions that violate the Single Responsibility Principle and create a poor user experience.

## What Changes
- Replace the complex TrimmerView with a minimal, functional trimming interface
- Simplify the trimming workflow to focus on core functionality: select range, preview, rotate, name
- Remove over-engineered category theory abstractions that add unnecessary complexity
- Implement a clean, visual timeline with intuitive drag handles
- Separate rotation into either a simple button or dedicated screen
- Reduce state management to essential properties only

## Impact
- Affected specs: video-trimming (new capability)
- Affected code:
  - breakdex/Features/Shared/Video/TrimmerView.swift (25,859 lines → ~200 lines)
  - breakdex/Features/Shared/Models/TrimmerState.swift (simplify)
  - breakdex/Features/AddMove/Views/SelectClip.swift (workflow integration)
- Breaking change: Complete replacement of trimming interface