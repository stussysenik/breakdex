# Fix Persistent Core Data Initialization - Prevent White Screen

## Why
**Critical Issue**: The app is still crashing with white screen due to multiple Core Data container initializations. Despite our singleton pattern, the lazy `.container` property is being accessed 6+ times from different parts of the app, triggering repeated store loading and hitting our initialization limit. The fatal error occurs because we're still using lazy initialization which allows multiple accesses before the container is fully ready.

## Root Cause Analysis
- **Multiple Container Accesses**: Different views/view models are accessing `PersistenceController.shared.container.viewContext`
- **Lazy Initialization Problem**: Each access to `.container` triggers lazy loading if not already initialized
- **Timing Issue**: Container is being accessed before the previous initialization completes
- **Fatal Error on Limit**: Our protection mechanism crashes the app instead of gracefully handling the situation

## What Changes
- **Eager Initialization**: Initialize Core Data container immediately when `PersistenceController.shared` is created
- **Thread-Safe Initialization**: Use `dispatch_once` pattern to ensure single initialization
- **Remove Lazy Loading**: Eliminate the `lazy` keyword from container property
- **Graceful Degradation**: Replace fatal error with in-memory store fallback when limit is exceeded
- **Comprehensive Diagnostics**: Add stack trace logging to identify all container access points

## Impact
- **User Impact**: App will launch and display UI instead of crashing with white screen
- **Technical Impact**: Core Data will initialize only once and be ready for all subsequent accesses
- **Affected Code**:
  - PersistenceBridge.swift (eager initialization, remove lazy)
  - Main app initialization (ensure early initialization)
  - All views accessing `.container.viewContext` (no changes needed)

## Success Criteria
- App launches without crashing
- Core Data initializes exactly once per app lifecycle
- No "Multiple Core Data initializations detected" warnings
- All views can successfully access Core Data context
- UI loads and displays properly
- Diagnostic logs show single initialization