# Fix Video Loading Initialization

## Why
The AddMove feature incorrectly initializes in a loading state, causing users to see a loading spinner instead of the expected "Select a Clip" button. This creates a confusing user experience where the app appears to be loading when it should be ready for video selection. Additionally, we have excellent video loading components (SimpleLoading.swift, VideoLoadingState.swift, VideoPlayer.swift) that are not being fully utilized in the current video loading flow.

## What Changes
- Fix the initial state in AddMoveUnifiedState to show "Select Clip" button by default
- Integrate SimpleLoading.swift component for consistent loading UI across the app
- Enhance diagnostic logging to track state transitions and loading progress
- Ensure VideoLoadingState.swift properly maps to AddMoveFlowState
- Utilize VideoPlayer.swift for consistent video playback experience
- Improve error handling and recovery mechanisms in video loading flow

## Impact
- **Affected specs**: video-loading, add-move-workflow, user-interface-states
- **Affected code**:
  - Features/Shared/Models/UnifiedState.swift (state initialization fix)
  - Features/AddMove/Views/SelectClip.swift (integrate SimpleLoading component)
  - Features/Shared/Video/VideoLoadingState.swift (ensure proper state mapping)
  - Features/Shared/Video/SimpleLoading.swift (enhance utilization)
- **User impact**: Users will see the correct "Select Clip" button on app launch instead of a perpetual loading spinner
- **Technical impact**: Proper state management, better component utilization, improved debugging capabilities

## Success Criteria
1. App launches to AddMove tab showing "Select Clip" button by default
2. Video selection flow properly utilizes SimpleLoading component
3. Enhanced logging provides clear visibility into state transitions
4. Error handling provides graceful recovery options
5. Video loading flow is consistent across all features