import SwiftUI
import Photos
import CoreData

/// Manages synchronization between Core Data metadata and BreakDex album contents
/// Ensures data integrity and handles orphaned metadata
@MainActor
class AlbumSyncManager: ObservableObject {
    static let shared = AlbumSyncManager()
    
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncResults: SyncResults?
    
    private var viewContext: NSManagedObjectContext? = nil
    private var syncTimer: Timer?
    
    struct SyncResults {
        let totalMoves: Int
        let foundInPhotos: Int
        let missingFromPhotos: Int
        let orphanedMetadata: Int
        let syncedAt: Date
        
        var hasIssues: Bool {
            missingFromPhotos > 0 || orphanedMetadata > 0
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
    /// - Returns: Sync results
    func performFullSync() async throws -> SyncResults {
        guard let context = viewContext else {
            throw AlbumSyncError.contextNotConfigured
        }
        
        await MainActor.run { isSyncing = true }
        defer { Task { await MainActor.run { isSyncing = false } } }
        
        // Get all moves from Core Data
        let fetchRequest = Move.fetchRequest()
        let allMoves = try await context.perform {
            try context.fetch(fetchRequest)
        }
        
        let totalMoves = allMoves.count
        var foundInPhotos = 0
        var missingFromPhotos: [Move] = []
        
        // Check each move
        for move in allMoves {
            if let photosIdentifier = move.photosIdentifier, !photosIdentifier.isEmpty {
                // BreakDex move - check if video exists in Photos
                if await videoExistsInPhotos(photosIdentifier) {
                    foundInPhotos += 1
                } else {
                    missingFromPhotos.append(move)
                }
            }
            // Legacy file-based moves are ignored in this sync
        }
        
        // Check for orphaned metadata (videos in album but not in Core Data)
        let albumVideos = await getAllBreakDexVideos()
        let photosIdentifiersInCoreData = Set(allMoves.compactMap { $0.photosIdentifier })
        let orphanedIdentifiers = albumVideos.filter { !photosIdentifiersInCoreData.contains($0.localIdentifier) }
        let orphanedMetadata = orphanedIdentifiers.count
        
        let results = SyncResults(
            totalMoves: totalMoves,
            foundInPhotos: foundInPhotos,
            missingFromPhotos: missingFromPhotos.count,
            orphanedMetadata: orphanedMetadata,
            syncedAt: Date()
        )
        
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
            print("✅ Move '\(move.name ?? "Unknown")' is in sync with Photos")
        } else {
            // Video missing - this should be handled by VideoRelinkManager
            print("⚠️ Move '\(move.name ?? "Unknown")' video not found in Photos")
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
            print("🧹 Found \(orphanedIdentifiers.count) orphaned videos in BreakDex album")
            
            // Note: In a production app, you might want to:
            // 1. Ask user for confirmation before deletion
            // 2. Move orphaned videos to a separate album
            // 3. Log the operation for audit purposes
            
            // For now, we'll just log them
            for video in orphanedIdentifiers {
                print("📋 Orphaned video: \(video.localIdentifier)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func videoExistsInPhotos(_ photosIdentifier: String) async -> Bool {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [photosIdentifier], options: nil)
        return fetchResult.firstObject != nil
    }
    
    private func getAllBreakDexVideos() async -> [PHAsset] {
        guard let album = await AlbumManager.shared.getBreakDexAlbum() else {
            return []
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let fetchResult = PHAsset.fetchAssets(in: album, options: fetchOptions)
        var videos: [PHAsset] = []

        fetchResult.enumerateObjects { asset, _, _ in
            videos.append(asset)
        }

        return videos
    }
    
    // MARK: - Periodic Sync
    
    private func startPeriodicSync() {
        // Sync every 5 minutes when app is active
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task {
                do {
                    _ = try await self?.performFullSync()
                } catch {
                    print("❌ Periodic sync failed: \(error.localizedDescription)")
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
