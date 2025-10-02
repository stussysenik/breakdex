import SwiftUI
import Photos
import CoreData
import OSLog

/// Manages synchronization between Core Data metadata and BreakDex album contents
/// Ensures data integrity and handles orphaned metadata with comprehensive diagnostic logging
@MainActor
class AlbumSyncManager: ObservableObject {
    static let shared = AlbumSyncManager()
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🔄 AlbumSyncManager")

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncResults: SyncResults?

    private var viewContext: NSManagedObjectContext? = nil
    private var syncTimer: Timer?
    
    struct SyncResults {
        let totalMoves: Int
        let foundInPhotos: Int
        let missingFromPhotos: Int
        let totalCombos: Int
        let orphanedCombos: Int
        let orphanedMetadata: Int
        let syncedAt: Date

        var hasIssues: Bool {
            missingFromPhotos > 0 || orphanedCombos > 0 || orphanedMetadata > 0
        }
    }
    
    private init() {
        // Start periodic sync
        startPeriodicSync()
    }
    
    func configure(with viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }
    
    // MARK: - Sync Operations
    
    /// Perform a full synchronization between Core Data and BreakDex album
    /// - Returns: Sync results with comprehensive diagnostic logging
    func performFullSync() async throws -> SyncResults {
        logger.info("🔄 AlbumSyncManager: 🚀 Starting full synchronization cycle")

        guard let context = viewContext else {
            logger.error("🔄 AlbumSyncManager: ❌ Core Data context not configured")
            throw AlbumSyncError.contextNotConfigured
        }

        await MainActor.run { isSyncing = true }
        defer { Task { await MainActor.run { isSyncing = false } } }
        
        // Get all moves from Core Data with diagnostic logging
        logger.info("🔄 AlbumSyncManager: 📊 Fetching all moves from Core Data")
        let moveFetchRequest = Move.fetchRequest()
        let allMoves = try await context.perform {
            try context.fetch(moveFetchRequest)
        }

        let totalMoves = allMoves.count
        var foundInPhotos = 0
        var missingFromPhotos: [Move] = []

        logger.info("🔄 AlbumSyncManager: 📊 Found \(totalMoves) total moves in Core Data")
        logger.info("🔄 AlbumSyncManager: 🔍 Analyzing move synchronization status")

        // Check each move with detailed logging
        for move in allMoves {
            if let photosIdentifier = move.photosIdentifier, !photosIdentifier.isEmpty {
                // BreakDex move - check if video exists in Photos
                if await videoExistsInPhotos(photosIdentifier) {
                    foundInPhotos += 1
                    logger.debug("🔄 AlbumSyncManager: ✅ Move '\(move.name ?? "Untitled")' found in Photos")
                } else {
                    missingFromPhotos.append(move)
                    logger.warning("🔄 AlbumSyncManager: ❌ Move '\(move.name ?? "Untitled")' missing from Photos (ID: \(photosIdentifier))")
                }
            } else {
                logger.debug("🔄 AlbumSyncManager: ⚠️ Legacy file-based move '\(move.name ?? "Untitled")' ignored in sync")
            }
        }

        // 🎯 NEW: Get all combos from Core Data and check for orphaned combos with detailed logging
        logger.info("🔄 AlbumSyncManager: 📊 Fetching all combos from Core Data")
        let comboFetchRequest = Combo.fetchRequest()
        let allCombos = try await context.perform {
            try context.fetch(comboFetchRequest)
        }

        let totalCombos = allCombos.count
        var orphanedCombos: [Combo] = []

        logger.info("🔄 AlbumSyncManager: 📊 Found \(totalCombos) total combos in Core Data")
        logger.info("🔄 AlbumSyncManager: 🔍 Analyzing combo synchronization status")

        // Check each combo for orphaned state with detailed logging
        for combo in allCombos {
            guard let comboMoveEntities = combo.comboMoves?.allObjects as? [ComboMove],
                  let comboMoves = comboMoveEntities.compactMap({ $0.move }) as? [Move],
                  !comboMoves.isEmpty else {
                // Combo has no moves - consider it orphaned
                orphanedCombos.append(combo)
                logger.warning("🔄 AlbumSyncManager: ❌ Combo '\(combo.name ?? "Untitled")' has no moves - marking as orphaned")
                continue
            }

            logger.debug("🔄 AlbumSyncManager: 🔍 Analyzing combo '\(combo.name ?? "Untitled")' with \(comboMoves.count) moves")

            // Check if any moves in this combo are missing from Photos
            var hasOrphanedMoves = false
            for move in comboMoves {
                guard let photosIdentifier = move.photosIdentifier, !photosIdentifier.isEmpty else {
                    logger.warning("🔄 AlbumSyncManager: ❌ Move '\(move.name ?? "Untitled")' in combo '\(combo.name ?? "Untitled")' has no photosIdentifier")
                    hasOrphanedMoves = true
                    break // Move without photosIdentifier is orphaned
                }

                let moveExists = await videoExistsInPhotos(photosIdentifier)
                if !moveExists {
                    logger.warning("🔄 AlbumSyncManager: ❌ Move '\(move.name ?? "Untitled")' in combo '\(combo.name ?? "Untitled")' missing from Photos (ID: \(photosIdentifier))")
                    hasOrphanedMoves = true
                    break
                }
            }

            if hasOrphanedMoves || comboMoves.isEmpty {
                orphanedCombos.append(combo)
                logger.warning("🔄 AlbumSyncManager: ❌ Combo '\(combo.name ?? "Untitled")' contains orphaned moves - marking for cleanup")
            } else {
                logger.debug("🔄 AlbumSyncManager: ✅ Combo '\(combo.name ?? "Untitled")' all moves verified in Photos")
            }
        }
        
        // 🎯 NEW: Clean up orphaned Core Data entries (moves missing from Photos) with enhanced logging
        if !missingFromPhotos.isEmpty {
            logger.info("🔄 AlbumSyncManager: 🧹 Found \(missingFromPhotos.count) orphaned move(s) in Core Data. Starting cleanup...")
            logger.info("🔄 AlbumSyncManager: 📊 Orphaned moves to delete: \(missingFromPhotos.map { $0.name ?? "Untitled" }.joined(separator: ", "))")

            await context.perform {
                for orphanedMove in missingFromPhotos {
                    self.logger.info("🔄 AlbumSyncManager: 🗑️ Deleting Core Data entry for move: \(orphanedMove.name ?? "Untitled") (ID: \(orphanedMove.id?.uuidString ?? "unknown"))")
                    context.delete(orphanedMove)
                }
                do {
                    try context.save()
                    self.logger.info("🔄 AlbumSyncManager: ✅ Orphaned move cleanup complete. Deleted \(missingFromPhotos.count) entries.")
                } catch {
                    self.logger.error("🔄 AlbumSyncManager: ❌ Error saving context after cleanup: \(error)")
                    self.logger.warning("🔄 AlbumSyncManager: 🔄 Rolling back Core Data context changes")
                    context.rollback()
                }
            }
        } else {
            logger.info("🔄 AlbumSyncManager: ✅ No orphaned Core Data move entries found - all moves have corresponding Photos assets")
        }

        // 🎯 NEW: Clean up orphaned combos (combos with missing moves) with enhanced logging
        if !orphanedCombos.isEmpty {
            logger.info("🔄 AlbumSyncManager: 🧹 Found \(orphanedCombos.count) orphaned combo(s) in Core Data. Starting cleanup...")
            logger.info("🔄 AlbumSyncManager: 📊 Orphaned combos to delete: \(orphanedCombos.map { $0.name ?? "Untitled" }.joined(separator: ", "))")

            await context.perform {
                for orphanedCombo in orphanedCombos {
                    let comboMoveCount = orphanedCombo.comboMoves?.count ?? 0
                    self.logger.info("🔄 AlbumSyncManager: 🗑️ Deleting Core Data entry for combo: \(orphanedCombo.name ?? "Untitled") (ID: \(orphanedCombo.id?.uuidString ?? "unknown"), Moves: \(comboMoveCount))")
                    context.delete(orphanedCombo)
                }
                do {
                    try context.save()
                    self.logger.info("🔄 AlbumSyncManager: ✅ Orphaned combo cleanup complete. Deleted \(orphanedCombos.count) entries.")
                } catch {
                    self.logger.error("🔄 AlbumSyncManager: ❌ Error saving context after combo cleanup: \(error)")
                    self.logger.warning("🔄 AlbumSyncManager: 🔄 Rolling back Core Data context changes")
                    context.rollback()
                }
            }
        } else {
            logger.info("🔄 AlbumSyncManager: ✅ No orphaned Core Data combo entries found - all combos have valid moves")
        }

        // Check for orphaned metadata (videos in album but not in Core Data)
        let albumVideos = await getAllBreakDexVideos()
        let photosIdentifiersInCoreData = Set(allMoves.compactMap { $0.photosIdentifier })
        let orphanedIdentifiers = albumVideos.filter { !photosIdentifiersInCoreData.contains($0.localIdentifier) }
        let orphanedMetadata = orphanedIdentifiers.count

        if !orphanedIdentifiers.isEmpty {
            logger.warning("🔄 AlbumSyncManager: 📊 Found \(orphanedMetadata) video(s) in BreakDex album without Core Data entries")
            logger.info("🔄 AlbumSyncManager: 📋 Orphaned video identifiers (first 3): \(orphanedIdentifiers.prefix(3).map { $0.localIdentifier.prefix(20) + "..." }.joined(separator: ", "))")
            if orphanedIdentifiers.count > 3 {
                logger.info("🔄 AlbumSyncManager: 📋 ... and \(orphanedIdentifiers.count - 3) more")
            }
        }

        let results = SyncResults(
            totalMoves: totalMoves,
            foundInPhotos: foundInPhotos,
            missingFromPhotos: missingFromPhotos.count,
            totalCombos: totalCombos,
            orphanedCombos: orphanedCombos.count,
            orphanedMetadata: orphanedMetadata,
            syncedAt: Date()
        )

        // 🎯 NEW: Comprehensive sync completion logging
        logger.info("🔄 AlbumSyncManager: ✅ Full synchronization completed successfully")
        logger.info("🔄 AlbumSyncManager: 📊 SYNC RESULTS SUMMARY:")
        logger.info("🔄 AlbumSyncManager: 📊 Total Moves: \(totalMoves)")
        logger.info("🔄 AlbumSyncManager: 📊 Found in Photos: \(foundInPhotos)")
        logger.info("🔄 AlbumSyncManager: 📊 Missing from Photos: \(missingFromPhotos.count)")
        logger.info("🔄 AlbumSyncManager: 📊 Total Combos: \(totalCombos)")
        logger.info("🔄 AlbumSyncManager: 📊 Orphaned Combos: \(orphanedCombos.count)")
        logger.info("🔄 AlbumSyncManager: 📊 Orphaned Metadata: \(orphanedMetadata)")
        logger.info("🔄 AlbumSyncManager: 📊 Has Issues: \(results.hasIssues)")
        logger.info("🔄 AlbumSyncManager: ⏰ Sync completed at: \(results.syncedAt)")

        await MainActor.run {
            syncResults = results
            lastSyncDate = results.syncedAt
        }

        return results
    }
    
    /// Sync a specific move
    /// - Parameter move: The move to sync
    func syncMove(_ move: Move) async throws {
        guard let photosIdentifier = move.photosIdentifier else {
            throw AlbumSyncError.invalidMove
        }
        
        if await videoExistsInPhotos(photosIdentifier) {
            // Video exists - update any metadata if needed
            logger.info("🔄 AlbumSyncManager: ✅ Move '\(move.name ?? "Unknown")' is in sync with Photos")
        } else {
            // Video missing - this should be handled by VideoRelinkManager
            logger.warning("🔄 AlbumSyncManager: ⚠️ Move '\(move.name ?? "Unknown")' video not found in Photos")
        }
    }
    
    /// Clean up orphaned metadata (videos in album but not in Core Data)
    /// This is a destructive operation that should be used carefully
    func cleanupOrphanedMetadata() async throws {
        guard let context = viewContext else {
            throw AlbumSyncError.contextNotConfigured
        }
        
        let albumVideos = await getAllBreakDexVideos()
        let allMoves = try await context.perform {
            try context.fetch(Move.fetchRequest())
        }
        
        let photosIdentifiersInCoreData = Set(allMoves.compactMap { $0.photosIdentifier })
        
        // Find videos that exist in album but not in Core Data
        let orphanedIdentifiers = albumVideos.filter { !photosIdentifiersInCoreData.contains($0.localIdentifier) }
        
        if !orphanedIdentifiers.isEmpty {
            logger.info("🔄 AlbumSyncManager: 🧹 Found \(orphanedIdentifiers.count) orphaned videos in BreakDex album")

            // Note: In a production app, you might want to:
            // 1. Ask user for confirmation before deletion
            // 2. Move orphaned videos to a separate album
            // 3. Log the operation for audit purposes

            // For now, we'll just log them
            for video in orphanedIdentifiers {
                logger.info("🔄 AlbumSyncManager: 📋 Orphaned video: \(video.localIdentifier)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func videoExistsInPhotos(_ photosIdentifier: String) async -> Bool {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [photosIdentifier], options: nil)
        return fetchResult.firstObject != nil
    }
    
    private func getAllBreakDexVideos() async -> [PHAsset] {
        do {
            let album = try await AlbumManager.shared.getBreakDexAlbum()

            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

            let fetchResult = PHAsset.fetchAssets(in: album, options: fetchOptions)
            var videos: [PHAsset] = []

            fetchResult.enumerateObjects { asset, _, _ in
                videos.append(asset)
            }

            return videos
        } catch {
            print("❌ Failed to get BreakDex album for video enumeration: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Periodic Sync
    
    private func startPeriodicSync() {
        // Sync every 5 minutes when app is active
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task {
                do {
                    _ = try await self?.performFullSync()
                } catch {
                    self?.logger.error("🔄 AlbumSyncManager: ❌ Periodic sync failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func stopPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    deinit {
        // Stop timer synchronously - Timer operations are thread-safe
        syncTimer?.invalidate()
    }
}

// MARK: - Error Types

enum AlbumSyncError: LocalizedError {
    case contextNotConfigured
    case invalidMove
    case syncFailed
    
    var errorDescription: String? {
        switch self {
        case .contextNotConfigured:
            return "Core Data context not configured."
        case .invalidMove:
            return "Invalid move data for sync."
        case .syncFailed:
            return "Album synchronization failed."
        }
    }
}
