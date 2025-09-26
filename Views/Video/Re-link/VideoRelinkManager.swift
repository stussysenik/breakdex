import SwiftUI
import Photos
import CoreData

@MainActor /// "Recovery Hub" for all missing video scenarios, manages video relinking
class VideoRelinkManager: ObservableObject {
    static let shared = VideoRelinkManager()
    
    @Published private(set) var isOperationInProgress = false
    @Published private(set) var relinkQueue: [Move] = []
    
    private var viewContext: NSManagedObjectContext? = nil
    
    private init() {}
    
    func configure(with viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }
    
    func videoExistsInPhotos(_ photosIdentifier: String) -> Bool {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [photosIdentifier], options: nil)
        return fetchResult.firstObject != nil
    }
    
    func scanBreakDexForMatches(_ originalIdentifier: String) async -> [PHAsset] {
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
    
    func relinkMove(_ move: Move, with newPhotosIdentifier: String) async throws {
        guard let context = viewContext else {
            throw VideoRelinkError.contextNotConfigured
        }

        await MainActor.run { isOperationInProgress = true }
        defer { Task { await MainActor.run { isOperationInProgress = false } } }
        
        guard videoExistsInPhotos(newPhotosIdentifier) else { // verify the new video exists
            throw VideoRelinkError.videoNotFound
        }
        
        try await context.perform { // update the move in Core Data
            move.photosIdentifier = newPhotosIdentifier
            
            move.trimStartTime = 0.0
            move.trimEndTime = 0.0
            
            try context.save()
        }
    }
    
    func addToRelinkQueue(_ move: Move) {
        if !relinkQueue.contains(where: { $0.managedObjectID == move.managedObjectID }) {
            relinkQueue.append(move)
        }
    }
    
    func removeFromRelinkQueue(_ move: Move) {
        relinkQueue.removeAll { $0.managedObjectID == move.managedObjectID }
    }
    
    func processRelinkQueue(onProgress: ((Int, Int) -> Void)? = nil) async throws {
        let total = relinkQueue.count
        var processed = 0

        for _ in relinkQueue {
            processed += 1
            onProgress?(processed, total)
        }

        await MainActor.run { relinkQueue.removeAll() }
    }
    
    func findPotentialMatches(for move: Move) async -> [PHAsset] {
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
    
    func processImportRelinks(_ importedMoves: [MoveExport]) async throws {
        await MainActor.run { isOperationInProgress = true }
        defer { Task { await MainActor.run { isOperationInProgress = false } } }
        
        for importedMove in importedMoves {
            if videoExistsInPhotos(importedMove.photosIdentifier) {
                try await createMoveFromImport(importedMove)
            } else {
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
            // Note: We don't set the managedObjectID as it's read-only and managed by Core Data
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

struct MoveExport: Codable {
    let name: String
    let photosIdentifier: String
    let trimStartTime: Double?
    let trimEndTime: Double?
    let learningState: String
}

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
