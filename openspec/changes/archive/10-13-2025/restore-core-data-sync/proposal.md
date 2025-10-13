# Restore Core Data Model Synchronization

## Why
Critical build failures are preventing compilation due to Core Data model synchronization issues. The Core Data model defines required attributes (`learningState`, `photosIdentifier`), but the generated NSManagedObject subclasses are out of sync, causing "Value of type 'Move' has no member" errors.

## What Changes
- Regenerate Core Data classes to synchronize with current model definition
- Restore commented-out critical services (MoveSaver, SharedVideoPlayerView)
- Fix missing Logger utility dependencies
- Verify Core Data migration functionality

## Impact
- **Affected specs**: core-data-integration, video-playback, move-management
- **Affected code**:
  - CoreData/Move+CoreDataClass.swift (REGENERATE)
  - CoreData/Move+CoreDataProperties.swift (REGENERATE)
  - Features/AddMove/Services/MoveSaver.swift (UNCOMMENT)
  - Features/Shared/Video/VideoPlayerView.swift (UNCOMMENT)
  - Features/Shared/Services/PersistenceBridge.swift (VERIFY)
- **BREAKING**: None - restores existing broken functionality

## Root Cause
The Core Data model (`breakdex.xcdatamodeld`) correctly defines `learningState` and `photosIdentifier` attributes, but Xcode's generated NSManagedObject subclasses don't reflect these properties, causing compilation failures when code tries to access them.