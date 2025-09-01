import SwiftUI
import Photos
import CoreData
import BreakingFlashcards

/// Manages video relinking for missing videos in the BreakDex system
/// This is the central "Recovery Hub" for all missing video scenarios
@MainActor
class VideoRelinkManager: ObservableObject {
    static let shared = VideoRelinkManager()

    @Published private(set) var isOperationInProgress = false
    @Published private(set) var relinkQueue: [Move] = []

    private var viewContext: NSManagedObjectContext? = nil

    private init() {}

    func configure(with viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }

    // MARK: - Relink Operations

    /// Check if a video exists for the given Photos identifier
    /// - Parameter photosIdentifier: Photos local identifier
    /// - Returns: True if video exists and is accessible
    func videoExistsInPhotos(_ photosIdentifier: String) async -> Bool {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [photosIdentifier], options: nil)
        return fetchResult.firstObject != nil
    }

    /// Scan BreakDex album for videos that might match the missing move
    /// - Parameter originalIdentifier: The missing Photos identifier
    /// - Returns: Array of potential replacement videos
    func scanBreakDexForMatches(_ originalIdentifier: String) async -> [PHAsset] {
        guard let album = await BreakDexAlbumManager.shared.albumState.album else {
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

    /// Attempt to relink a move with a new Photos identifier
    /// - Parameters:
    ///   - move: The move to relink
    ///   - newPhotosIdentifier: The new Photos identifier
    /// - Returns: Success status
    func relinkMove(_ move: Move, with newPhotosIdentifier: String) async throws {
        guard let context = viewContext else {
            throw VideoRelinkError.contextNotConfigured
        }

        try? await MainActor.run { isOperationInProgress = true }
        defer { Task { try? await MainActor.run { isOperationInProgress = false } } }

        // Verify the new video exists
        guard await videoExistsInPhotos(newPhotosIdentifier) else {
            throw VideoRelinkError.videoNotFound
        }

        // Update the move in Core Data
        try await context.perform {
            move.photosIdentifier = newPhotosIdentifier
            // Reset trim ranges for the new video
            move.trimStartTime = 0.0
            move.trimEndTime = 0.0

            try context.save()
        }
    }

    /// Add a move to the relink queue for batch processing
    /// - Parameter move: The move that needs relinking
    func addToRelinkQueue(_ move: Move) {
        if !relinkQueue.contains(where: { $0.id == move.id }) {
            relinkQueue.append(move)
        }
    }

    /// Remove a move from the relink queue
    /// - Parameter move: The move to remove
    func removeFromRelinkQueue(_ move: Move) {
        relinkQueue.removeAll { $0.id == move.id }
    }

    /// Process all moves in the relink queue
    /// - Parameter onProgress: Callback for progress updates
    func processRelinkQueue(onProgress: ((Int, Int) -> Void)? = nil) async throws {
        let total = relinkQueue.count
        var processed = 0

        for move in relinkQueue {
            // For now, we'll just mark these as needing manual relinking
            // In a full implementation, you might try to auto-match based on metadata
            processed += 1
            onProgress?(processed, total)
        }

        // Clear the queue after processing
        try? await MainActor.run { relinkQueue.removeAll() }
    }

    /// Find potential matches for a missing video based on move metadata
    /// - Parameter move: The move with missing video
    /// - Returns: Array of potential replacement videos
    func findPotentialMatches(for move: Move) async -> [PHAsset] {
        guard let album = await BreakDexAlbumManager.shared.albumState.album else {
            return []
        }

        // Get all videos in BreakDex album
        let allVideos = await BreakDexAlbumManager.shared.getAllVideosInBreakDex()

        // For now, return all videos as potential matches
        // In a more sophisticated implementation, you could:
        // - Match by creation date proximity
        // - Match by duration similarity
        // - Use machine learning to match video content
        return allVideos
    }

    // MARK: - Batch Operations for Import

    /// Process relinking for imported moves
    /// - Parameter importedMoves: Array of imported move data
    func processImportRelinks(_ importedMoves: [MoveExport]) async throws {
        try? await MainActor.run { isOperationInProgress = true }
        defer { Task { try? await MainActor.run { isOperationInProgress = false } } }

        for importedMove in importedMoves {
            // Check if the video exists in current BreakDex
            if await videoExistsInPhotos(importedMove.photosIdentifier) {
                // Video exists - create move directly
                try await createMoveFromImport(importedMove)
            } else {
                // Video missing - add to relink queue
                // Note: This would require converting MoveExport to Move or storing temporarily
                print("Video \(importedMove.photosIdentifier) not found - would add to relink queue")
            }
        }
    }

    private func createMoveFromImport(_ importedMove: MoveExport) async throws {
        guard let context = viewContext else {
            throw VideoRelinkError.contextNotConfigured
        }

        try await context.perform {
            let newMove = Move(context: context)
            newMove.id = UUID()
            newMove.name = importedMove.name
            newMove.photosIdentifier = importedMove.photosIdentifier
            newMove.trimStartTime = importedMove.trimStartTime ?? 0.0
            newMove.trimEndTime = importedMove.trimEndTime ?? 0.0
            newMove.learningState = importedMove.learningState
            newMove.createdAt = Date()

            try context.save()
        }
    }
}

// MARK: - Supporting Types

struct MoveExport: Codable {
    let name: String
    let photosIdentifier: String
    let trimStartTime: Double?
    let trimEndTime: Double?
    let learningState: String
}

// MARK: - Error Types

enum VideoRelinkError: LocalizedError {
    case contextNotConfigured
    case videoNotFound
    case relinkFailed
    case invalidMove

    var errorDescription: String? {
        switch self {
        case .contextNotConfigured:
            return "Core Data context not configured."
        case .videoNotFound:
            return "Video not found in Photos library."
        case .relinkFailed:
            return "Failed to relink video."
        case .invalidMove:
            return "Invalid move data."
        }
    }
}
