## Why
The video loading system exhibits a functorial composition failure causing UI progress to hang at 60% during iCloud downloads, creating a broken state synchronization chain between RobustVideoLoader and AddMoveViewModel.

## What Changes
- Fix iCloud progress handler to include intermediate state transitions after download completion
- Remove conditional state filtering in AddMoveViewModel that breaks functorial mapping
- Ensure continuous progress flow from 60% → 70% → 80% → 100% instead of jumping from 60% → 100%
- **BREAKING**: Changes progress update behavior in AddMoveViewModel.handleProgressUpdate()

## Impact
- Affected specs: video-loading
- Affected code: RobustVideoLoader.swift (lines 173-180), AddMoveViewModel.swift (line 328)
- User experience: Smooth continuous progress indication during video loading
- **MVVM/SRP Compliance**: Changes respect architectural boundaries - Service layer fixes progress reporting, ViewModel fixes state mapping