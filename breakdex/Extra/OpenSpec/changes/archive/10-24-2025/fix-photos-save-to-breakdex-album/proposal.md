## Why

The app crashes when users tap the Save button in NameMoveView because MovePersistenceService violates Photos framework API rules by accessing placeholder properties outside the required context block. Additionally, saved videos go to the general Photos library instead of the BreakDex album, preventing organized move management.

## What Changes

- Fix Photos API context violation in MovePersistenceService.saveTempFileToPhotosLibrary() at line 1221
- Integrate PhotoKitService with MovePersistenceService for BreakDex album creation and management
- Add @MainActor thread safety to all Photos operations
- Update service collaboration to ensure videos save to BreakDex album (existing or new)
- Add minimal diagnostic logging for future debugging
- Remove duplicate album creation logic

## Impact

- Affected specs: photo-album-management
- Affected code:
  - MovePersistenceService.swift:288-364 (Photos API violation)
  - MoveSaver.swift:74-79 (service integration)
  - PhotoKitService.swift:50-357 (thread safety)
  - AddMoveViewModel.swift:680-685 (error handling)

**BREAKING**: MovePersistenceService.saveVideoToPhotos() method signature changes to support album-specific saving.