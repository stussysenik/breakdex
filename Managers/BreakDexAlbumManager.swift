import Photos
import SwiftUI
import Combine
import OSLog

/// Manages the BreakDex album in the Photos library
/// This now serves as a compatibility layer over the atomic PhotoKitService
/// 🎯 DEPRECATED: Use PhotoKitService directly for new code
/// 🔄 COMPATIBILITY: Maintains existing API while using atomic operations
@MainActor
class BreakDexAlbumManager: ObservableObject {
    static let shared = BreakDexAlbumManager()

    private let albumName = "BreakDex"
    private let albumIdentifierKey = "BreakDexAlbumIdentifier"
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "BreakDexAlbumManager")
    private let photoKitService = PhotoKitService.shared

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
    /// 🔄 ATOMIC: Now uses PhotoKitService for atomic operations
    func ensureBreakDexAlbum() async throws -> PHAssetCollection {
        // Check current state
        switch albumState {
        case .ready(let album):
            return album
        case .creating:
            // Wait for creation to complete (simplified - PhotoKitService handles this atomically)
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
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

        // Use the atomic PhotoKitService
        logger.info("💾 ALBUM_MANAGER: 🔄 Using atomic PhotoKitService for album operations")

        do {
            let album = try await photoKitService.getOrCreateBreakDexAlbum()
            await MainActor.run { albumState = .ready(album) }
            logger.info("💾 ALBUM_MANAGER: ✅ BreakDex album ensured atomically")
            return album
        } catch {
            await MainActor.run { albumState = .failed(error) }
            logger.error("💾 ALBUM_MANAGER: ❌ Failed to ensure BreakDex album atomically: \(error.localizedDescription)")
            throw error
        }
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
    /// 🔄 ATOMIC: Now uses PhotoKitService for atomic operations
    func copyVideoToBreakDex(_ asset: PHAsset) async throws -> PHAsset {
        await MainActor.run { isOperationInProgress = true }
        defer { Task { await MainActor.run { isOperationInProgress = false } } }

        logger.info("💾 ALBUM_MANAGER: 🔄 Copying video to BreakDex album atomically")

        // For copying existing PHAssets, we need to get the video data first
        let videoData = try await getVideoData(from: asset)
        let tempURL = try await saveVideoDataToTempFile(videoData)

        // Use the atomic PhotoKitService to save the video
        do {
            let localIdentifier = try await photoKitService.saveVideoToBreakDexAlbum(tempURL)

            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)

            // Find the newly created asset by identifier
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
            if let newAsset = fetchResult.firstObject {
                logger.info("💾 ALBUM_MANAGER: ✅ Video copied to BreakDex album atomically: \(newAsset.localIdentifier)")
                return newAsset
            } else {
                throw BreakDexAlbumError.assetCreationFailed
            }
        } catch {
            // Clean up temp file on error
            try? FileManager.default.removeItem(at: tempURL)
            logger.error("💾 ALBUM_MANAGER: ❌ Failed to copy video to BreakDex album atomically: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Copy a video from file URL to BreakDex album
    /// - Parameter fileURL: Local file URL of the video
    /// - Returns: The new PHAsset in BreakDex album
    /// 🔄 ATOMIC: Now uses PhotoKitService for atomic operations
    func copyVideoToBreakDex(from fileURL: URL) async throws -> PHAsset {
        await MainActor.run { isOperationInProgress = true }
        defer { Task { await MainActor.run { isOperationInProgress = false } } }

        logger.info("💾 ALBUM_MANAGER: 🔄 Copying video from file to BreakDex album atomically")

        // Use the atomic PhotoKitService to save the video
        do {
            let localIdentifier = try await photoKitService.saveVideoToBreakDexAlbum(fileURL)

            // Find the newly created asset by identifier
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
            if let newAsset = fetchResult.firstObject {
                logger.info("💾 ALBUM_MANAGER: ✅ Video copied from file to BreakDex album atomically: \(newAsset.localIdentifier)")
                return newAsset
            } else {
                throw BreakDexAlbumError.assetCreationFailed
            }
        } catch {
            logger.error("💾 ALBUM_MANAGER: ❌ Failed to copy video from file to BreakDex album atomically: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Save a video to BreakDex album and return its identifier
    /// - Parameter fileURL: Local file URL of the video
    /// - Returns: Photos identifier of the saved video
    /// 🔄 ATOMIC: Now uses PhotoKitService for atomic operations
    func saveVideoToBreakDexAlbum(_ fileURL: URL) async throws -> String {
        logger.info("💾 ALBUM_MANAGER: 🔄 Saving video to BreakDex album atomically: \(fileURL.lastPathComponent)")

        do {
            let localIdentifier = try await photoKitService.saveVideoToBreakDexAlbum(fileURL)
            logger.info("💾 ALBUM_MANAGER: ✅ Video saved to BreakDex album atomically: \(localIdentifier)")
            return localIdentifier
        } catch {
            logger.error("💾 ALBUM_MANAGER: ❌ Failed to save video to BreakDex album atomically: \(error.localizedDescription)")
            throw error
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
    /// 🔄 ATOMIC: Now uses PhotoKitService for atomic operations
    func getAllVideosInBreakDex() async -> [PHAsset] {
        logger.info("💾 ALBUM_MANAGER: 📂 Getting all videos from BreakDex album")

        let assets = await photoKitService.getAllVideosInBreakDex()
        logger.info("💾 ALBUM_MANAGER: ✅ Retrieved \(assets.count) videos from BreakDex album")

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
