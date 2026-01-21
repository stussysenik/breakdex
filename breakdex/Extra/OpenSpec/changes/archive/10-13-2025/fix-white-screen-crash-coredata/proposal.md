# Fix White Screen Crash - Core Data Resource Exhaustion

## Why
**Critical Issue**: The app is crashing with a white screen due to Core Data "Too many open files" error (Code 24). The logs show repeated Core Data store initialization (200+ times), indicating the PersistenceController is being instantiated multiple times instead of using a singleton pattern. This causes resource exhaustion and fatal crash at PersistenceBridge.swift:17.

## What Changes
- **Fix PersistenceController Singleton**: Ensure only one instance is created and reused
- **Add Resource Limits**: Prevent multiple Core Data store initializations
- **Debug Logging**: Add initialization tracking to identify multiple instantiations
- **Safe Unwrapping**: Replace force unwrap with safe optional handling at crash site

## Impact
- **User Impact**: App will launch and display UI instead of crashing with white screen
- **Technical Impact**: Prevents resource exhaustion and ensures stable Core Data operations
- **Affected Code**:
  - PersistenceBridge.swift (singleton enforcement)
  - Main app initialization (prevent multiple instances)
  - Core Data model loading (resource management)

## Success Criteria
- App launches without crashing
- Core Data initializes only once per app lifecycle
- UI loads and displays properly
- No "Too many open files" errors
- Resource usage remains stable