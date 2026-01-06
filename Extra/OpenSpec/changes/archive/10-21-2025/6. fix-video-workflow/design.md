## Context
The video workflow fails because placeholder Photos identifiers cannot be used to load actual videos. The system stores trim metadata correctly but saves fake UUIDs instead of real video references, breaking the entire video loading chain.

## Goals / Non-Goals
- Goals: Fix video persistence, enable trimmed video export, restore proper navigation
- Non-Goals: Complex video editing features, multiple export formats, cloud sync

## Decisions
- Decision: Use AVAssetExportSession with timeRange for actual trimmed video export
  - Why: Creates real video files that work with Photos library, standard iOS practice
  - Alternatives considered: Virtual trimming during playback (rejected for complexity)

- Decision: Replace placeholder UUID generation with PHPhotoLibrary integration
  - Why: Only way to create valid Photos identifiers
  - Alternatives considered: Custom video storage (rejected for user experience)

- Decision: Fix save workflow to return to ready state
  - Why: Preserves user workflow for creating multiple moves
  - Alternatives considered: Keep current navigation (rejected for poor UX)

## Risks / Trade-offs
- Export time: Trimming takes 5-10 seconds vs instant metadata save
  - Mitigation: Use high-quality preset, show progress indication
- Storage space: Creates additional video files
  - Mitigation: iOS manages Photos library efficiently, users expect saved videos
- Permissions: Requires Photos library access
  - Mitigation: Clear permission request, graceful fallback

## Migration Plan
- Move entities with placeholder identifiers will show "Video not found" error
- New saves will create real Photos library entries
- No database schema changes required - existing moves remain intact
- Users can re-save problematic moves to create real video entries

## Open Questions
- Performance impact on older devices (needs testing)
- Optimal export preset balancing quality vs speed (may need adjustment)