import Photos
import SwiftUI
import Combine

/// Manages the BreakDex album in the Photos library
/// This is the single source of truth for all video storage operations
@MainActor
class BreakDexAlbumManager: ObservableObject {
    static let shared = BreakDexAlbumManager()
    
    private let albumName = "BreakDex"
    private let albumIdentifierKey = "BreakDexAlbumIdentifier"
    
    enum AlbumState {
        case unknown
        case creating
        case ready(PHAssetCollection)
        case failed(Error)
        case permissionDenied
        
        var album: PHAssetCollection? {
            switch self {
            case .ready(let collection):
                return collection
            default:
                return nil
            }
        }
    }
    
    @Published private(set) var albumState: AlbumState = .unknown
    @Published private(set) var isOperationInProgress = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Check album status on initialization
        checkAlbumStatus()
    }
    
    // MARK: - Album Management
    
    /// Ensure BreakDex album exists and is accessible
    /// - Returns: The BreakDex album if available
    func ensureBreakDexAlbum() async throws -> PHAssetCollection {
        // Check current state
        switch albumState {
        case .ready(let album):
            return album
        case .creating:
            // Wait for creation to complete
            try await waitForAlbumCreation()
            guard case .ready(let album) = albumState else {
                throw BreakDexAlbumError.albumCreationFailed
            }
            return album
        case .failed(let error):
            throw error
        case .permissionDenied:
            throw PhotosPermissionError.accessDenied
        case .unknown:
            break
        }
        
        // Check permissions first
        guard await PhotosPermissionManager.shared.ensurePermission() else {
            await MainActor.run { albumState = .permissionDenied }
            throw PhotosPermissionError.accessDenied
        }
        
        // Try to find existing album
        if let existingAlbum = await findBreakDexAlbum() {
            await MainActor.run { albumState = .ready(existingAlbum) }
            return existingAlbum
        }
        
        // Create new album
        await MainActor.run { albumState = .creating }
        let newAlbum = try await createBreakDexAlbum()
        await MainActor.run { albumState = .ready(newAlbum) }
        
        return newAlbum
    }
    
    /// Check if BreakDex album exists and update state
    func checkAlbumStatus() {
        Task {
            do {
                _ = try await ensureBreakDexAlbum()
            } catch {
                await MainActor.run { albumState = .failed(error) }
            }
        }
    }
    
    // MARK: - Video Operations
    
    /// Copy a video asset to the BreakDex album
    /// - Parameter asset: The PHAsset to copy
    /// - Returns: The new PHAsset in BreakDex album
    func copyVideoToBreakDex(_ asset: PHAsset) async throws -> PHAsset {
        await MainActor.run { isOperationInProgress = true }
        defer { Task { await MainActor.run { isOperationInProgress = false } } }

        let album = try await ensureBreakDexAlbum()

        // For copying existing PHAssets, we need to get the video data first
        let videoData = try await getVideoData(from: asset)
        let tempURL = try await saveVideoDataToTempFile(videoData)

        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempURL)
                let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                if let placeholder = request?.placeholderForCreatedAsset {
                    albumChangeRequest?.addAssets([placeholder] as NSFastEnumeration)
                }
            } completionHandler: { success, error in
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempURL)

                if success {
                    // Find the newly created asset
                    let fetchOptions = PHFetchOptions()
                    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                    fetchOptions.fetchLimit = 1

                    let fetchResult = PHAsset.fetchAssets(in: album, options: fetchOptions)
                    if let newAsset = fetchResult.firstObject {
                        continuation.resume(returning: newAsset)
                    } else {
                        continuation.resume(throwing: BreakDexAlbumError.assetCreationFailed)
                    }
                } else {
                    continuation.resume(throwing: error ?? BreakDexAlbumError.assetCreationFailed)
                }
            }
        }
    }
    
    /// Copy a video from file URL to BreakDex album
    /// - Parameter fileURL: Local file URL of the video
    /// - Returns: The new PHAsset in BreakDex album
    func copyVideoToBreakDex(from fileURL: URL) async throws -> PHAsset {
        await MainActor.run { isOperationInProgress = true }
        defer { Task { await MainActor.run { isOperationInProgress = false } } }
        
        let album = try await ensureBreakDexAlbum()
        
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
                let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                if let placeholder = request?.placeholderForCreatedAsset {
                    albumChangeRequest?.addAssets([placeholder] as NSFastEnumeration)
                }
            } completionHandler: { success, error in
                if success {
                    // Find the newly created asset
                    let fetchOptions = PHFetchOptions()
                    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                    fetchOptions.fetchLimit = 1
                    
                    let fetchResult = PHAsset.fetchAssets(in: album, options: fetchOptions)
                    if let newAsset = fetchResult.firstObject {
                        continuation.resume(returning: newAsset)
                    } else {
                        continuation.resume(throwing: BreakDexAlbumError.assetCreationFailed)
                    }
                } else {
                    continuation.resume(throwing: error ?? BreakDexAlbumError.assetCreationFailed)
                }
            }
        }
    }
    
    /// Check if a video exists in BreakDex album by local identifier
    /// - Parameter localIdentifier: Photos local identifier
    /// - Returns: The asset if found, nil otherwise
    func findVideoInBreakDex(localIdentifier: String) async -> PHAsset? {
        guard let album = albumState.album else { return nil }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "localIdentifier == %@", localIdentifier)
        
        let fetchResult = PHAsset.fetchAssets(in: album, options: fetchOptions)
        return fetchResult.firstObject
    }
    
    /// Get all videos in BreakDex album
    /// - Returns: Array of all video assets in BreakDex
    func getAllVideosInBreakDex() async -> [PHAsset] {
        guard let album = albumState.album else { return [] }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetchResult = PHAsset.fetchAssets(in: album, options: fetchOptions)
        var assets: [PHAsset] = []
        
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        return assets
    }
    
    // MARK: - Private Helpers
    
    private func getVideoData(from asset: PHAsset) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            let manager = PHImageManager.default()
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat

            manager.requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                guard let urlAsset = avAsset as? AVURLAsset else {
                    continuation.resume(throwing: BreakDexAlbumError.assetCreationFailed)
                    return
                }

                do {
                    let data = try Data(contentsOf: urlAsset.url)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func saveVideoDataToTempFile(_ data: Data) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        
        try data.write(to: tempURL)
        return tempURL
    }
    
    private func findBreakDexAlbum() async -> PHAssetCollection? {
        return await withCheckedContinuation { continuation in
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "title == %@", albumName)
            
            let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
            
            if let album = collections.firstObject {
                continuation.resume(returning: album)
            } else {
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func createBreakDexAlbum() async throws -> PHAssetCollection {
        return try await withCheckedThrowingContinuation { continuation in
            var collectionPlaceholder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges {
                let createRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: self.albumName)
                collectionPlaceholder = createRequest.placeholderForCreatedAssetCollection
            } completionHandler: { success, error in
                if success, let collectionPlaceholder = collectionPlaceholder {
                    let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionPlaceholder.localIdentifier], options: nil)
                    if let album = fetchResult.firstObject {
                        continuation.resume(returning: album)
                    } else {
                        continuation.resume(throwing: BreakDexAlbumError.albumCreationFailed)
                    }
                } else {
                    continuation.resume(throwing: error ?? BreakDexAlbumError.albumCreationFailed)
                }
            }
        }
    }
    
    private func waitForAlbumCreation() async throws {
        // Simple polling mechanism - in production, consider using a more sophisticated approach
        let maxAttempts = 10
        let delay: UInt64 = 500_000_000 // 0.5 seconds
        
        for _ in 0..<maxAttempts {
            if case .ready = albumState {
                return
            }
            try await Task.sleep(nanoseconds: delay)
        }
        
        throw BreakDexAlbumError.albumCreationTimeout
    }
}

// MARK: - Error Types

enum BreakDexAlbumError: LocalizedError {
    case albumCreationFailed
    case assetCreationFailed
    case albumCreationTimeout
    case albumNotFound
    
    var errorDescription: String? {
        switch self {
        case .albumCreationFailed:
            return "Failed to create BreakDex album. Please check Photos permissions."
        case .assetCreationFailed:
            return "Failed to add video to BreakDex album."
        case .albumCreationTimeout:
            return "Album creation is taking longer than expected. Please try again."
        case .albumNotFound:
            return "BreakDex album not found. It may have been deleted."
        }
    }
}

// MARK: - PHAsset Extensions

extension PHAsset {
    /// Check if asset is a video
    var isVideo: Bool {
        mediaType == .video
    }
    
    /// Get video duration in seconds
    func getVideoDuration() async -> Double? {
        await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestAVAsset(forVideo: self, options: options) { avAsset, _, _ in
                if let asset = avAsset {
                    if #available(iOS 16.0, *) {
                        Task {
                            let duration = try await asset.load(.duration)
                            continuation.resume(returning: CMTimeGetSeconds(duration))
                        }
                    } else {
                        continuation.resume(returning: CMTimeGetSeconds(asset.duration))
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
