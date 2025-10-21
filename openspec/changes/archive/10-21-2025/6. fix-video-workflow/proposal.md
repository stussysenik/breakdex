## Why
The video workflow fails because saved moves contain fake Photos library identifiers instead of real video references. This breaks navigation, video loading, and user experience.

**Evidence from logs (Line 1290):** `Generated placeholder photos identifier: BB1F4884-75B2-499B-9C84-AC8FA5EC9B31`

**Root cause:** `PHAsset.fetchAssets(withLocalIdentifiers: [placeholderUUID])` always returns nil because placeholder UUIDs don't exist in Photos library.

## What Changes
- Replace placeholder identifier generation with actual video export to Photos library
- Export trimmed video segments using AVAssetExportSession with timeRange
- Fix save workflow to return to ready state instead of navigating away
- Add trim boundary enforcement during video playback
- Add minimal diagnostic logging for future debugging

## Impact
- **Affected specs:** move-persistence, video-playback, save-workflow
- **Affected code:** MovePersistenceService.swift, MoveDetailView.swift, AddMoveView.swift
- **Breaking change:** Yes - moves will now create real Photos library entries instead of placeholders