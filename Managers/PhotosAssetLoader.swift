import Foundation
import Photos
import AVKit
import OSLog

// MARK: - Photos Asset Loader Service
/// Handles asynchronous fetching of AVAssets from Photos library using local identifiers
/// This service provides a clean abstraction for loading video assets from the Photos library
/// and includes comprehensive diagnostic logging for debugging purposes.
@MainActor
class PhotosAssetLoader {

    // MARK: - Properties
    private static let logger = Logger(subsystem: "com.breakingflashcards", category: "🖼️ PHOTOS_ASSET_LOADER")

    // MARK: - Public API

    /// Fetch an AVAsset from the Photos library using its local identifier
    /// - Parameter identifier: The Photos library local identifier string
    /// - Returns: AVAsset if found and accessible, nil otherwise
    static func fetchAsset(with identifier: String) async -> AVAsset? {
        logger.info("🖼️ PHOTOS_ASSET_LOADER: 🚀 Starting asset fetch for identifier: \(identifier)")

        // Step 1: Validate input parameters
        guard !identifier.isEmpty else {
            logger.error("🖼️ PHOTOS_ASSET_LOADER: ❌ Empty identifier provided")
            return nil
        }

        // Step 2: Check Photos library authorization status
        let authorizationStatus = PHPhotoLibrary.authorizationStatus(for: PHAccessLevel.readWrite)
        logger.info("🖼️ PHOTOS_ASSET_LOADER: 📋 Photo library authorization status: \(authorizationStatus.rawValue)")

        guard authorizationStatus == PHAuthorizationStatus.authorized else {
            logger.error("🖼️ PHOTOS_ASSET_LOADER: ❌ Photo library access not authorized")
            logger.error("🖼️ PHOTOS_ASSET_LOADER: ❌ Current status: \(authorizationStatus.rawValue)")
            return nil
        }

        // Step 3: Fetch the PHAsset using the local identifier
        logger.info("🖼️ PHOTOS_ASSET_LOADER: 🔍 Fetching PHAsset with identifier: \(identifier)")

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        logger.info("🖼️ PHOTOS_ASSET_LOADER:  Fetch result count: \(fetchResult.count)")

        guard let asset = fetchResult.firstObject else {
            logger.error("🖼️ PHOTOS_ASSET_LOADER: ❌ No PHAsset found for identifier: \(identifier)")
            logger.error("🖼️ PHOTOS_ASSET_LOADER: ❌ This could indicate the asset was deleted from Photos library")
            return nil
        }

        logger.info("🖼️ PHOTOS_ASSET_LOADER: ✅ PHAsset found successfully")
        logger.info("🖼️ PHOTOS_ASSET_LOADER:  Asset media type: \(asset.mediaType.rawValue)")
        logger.info("🖼️ PHOTOS_ASSET_LOADER:  Asset duration: \(asset.duration)")

        // Step 4: Configure video request options for optimal performance
        let options = PHVideoRequestOptions()
        options.version = .original
        options.deliveryMode = .automatic
        options.isNetworkAccessAllowed = true

        logger.info("🖼️ PHOTOS_ASSET_LOADER: ⚙️ Video request options configured:")
        logger.info("🖼️ PHOTOS_ASSET_LOADER:   - Version: original")
        logger.info("🖼️ PHOTOS_ASSET_LOADER:   - Delivery mode: automatic")
        logger.info("🖼️ PHOTOS_ASSET_LOADER:   - Network access: allowed")

        // Step 5: Request the AVAsset asynchronously using continuation
        logger.info("🖼️ PHOTOS_ASSET_LOADER: ⏳ Requesting AVAsset from PHImageManager")

        do {
            let avAsset = try await withCheckedThrowingContinuation { continuation in
                PHImageManager.default().requestAVAsset(
                    forVideo: asset,
                    options: options
                ) { avAsset, audioMix, info in
                    // Log the completion info for debugging
                    if let info = info {
                        Logger(subsystem: "com.breakingflashcards", category: "🖼️ PHOTOS_ASSET_LOADER").info("🖼️ PHOTOS_ASSET_LOADER: 📋 AVAsset request info: \(info)")
                    }

                    if let avAsset = avAsset {
                        Logger(subsystem: "com.breakingflashcards", category: "🖼️ PHOTOS_ASSET_LOADER").info("🖼️ PHOTOS_ASSET_LOADER: ✅ AVAsset received successfully")
                        Logger(subsystem: "com.breakingflashcards", category: "🖼️ PHOTOS_ASSET_LOADER").info("🖼️ PHOTOS_ASSET_LOADER:  AVAsset duration: \(CMTimeGetSeconds(avAsset.duration))")
                        Logger(subsystem: "com.breakingflashcards", category: "🖼️ PHOTOS_ASSET_LOADER").info("🖼️ PHOTOS_ASSET_LOADER:  AVAsset is playable: \(avAsset.isPlayable)")
                        Logger(subsystem: "com.breakingflashcards", category: "🖼️ PHOTOS_ASSET_LOADER").info("🖼️ PHOTOS_ASSET_LOADER:  AVAsset tracks: \(avAsset.tracks.count)")
                        continuation.resume(returning: avAsset)
                    } else {
                        let error = NSError(
                            domain: "PhotosAssetLoader",
                            code: 1001,
                            userInfo: [NSLocalizedDescriptionKey: "AVAsset request returned nil"]
                        )
                        Logger(subsystem: "com.breakingflashcards", category: "🖼️ PHOTOS_ASSET_LOADER").error("🖼️ PHOTOS_ASSET_LOADER: ❌ AVAsset request returned nil")
                        continuation.resume(throwing: error)
                    }
                }
            }

            logger.info("🖼️ PHOTOS_ASSET_LOADER: 🎉 Asset fetch completed successfully")
            return avAsset

        } catch {
            logger.error("🖼️ PHOTOS_ASSET_LOADER: ❌ Failed to fetch AVAsset: \(error.localizedDescription)")
            logger.error("🖼️ PHOTOS_ASSET_LOADER: ❌ Error type: \(type(of: error))")
            return nil
        }
    }

    /// Check if an asset exists in the Photos library without loading it
    /// - Parameter identifier: The Photos library local identifier string
    /// - Returns: Boolean indicating if the asset exists
    static func assetExists(with identifier: String) -> Bool {
        logger.info("🖼️ PHOTOS_ASSET_LOADER: 🔍 Checking if asset exists: \(identifier)")

        guard !identifier.isEmpty else {
            logger.error("🖼️ PHOTOS_ASSET_LOADER: ❌ Empty identifier provided for existence check")
            return false
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        let exists = fetchResult.count > 0

        logger.info("🖼️ PHOTOS_ASSET_LOADER:  Asset exists check result: \(exists)")
        return exists
    }

    /// Get basic asset metadata without loading the full AVAsset
    /// - Parameter identifier: The Photos library local identifier string
    /// - Returns: Dictionary containing asset metadata if found
    static func getAssetMetadata(for identifier: String) -> [String: Any]? {
        logger.info("🖼️ PHOTOS_ASSET_LOADER:  Getting metadata for asset: \(identifier)")

        guard !identifier.isEmpty else {
            logger.error("🖼️ PHOTOS_ASSET_LOADER: ❌ Empty identifier provided for metadata request")
            return nil
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            logger.error("🖼️ PHOTOS_ASSET_LOADER: ❌ No PHAsset found for metadata request: \(identifier)")
            return nil
        }

        let metadata: [String: Any] = [
            "mediaType": asset.mediaType.rawValue,
            "duration": asset.duration,
            "creationDate": asset.creationDate ?? Date(),
            "modificationDate": asset.modificationDate ?? Date(),
            "isFavorite": asset.isFavorite,
            "isHidden": asset.isHidden,
            "pixelWidth": asset.pixelWidth,
            "pixelHeight": asset.pixelHeight
        ]

        logger.info("🖼️ PHOTOS_ASSET_LOADER: ✅ Metadata retrieved successfully")
        logger.info("🖼️ PHOTOS_ASSET_LOADER:  Media type: \(asset.mediaType.rawValue)")
        logger.info("🖼️ PHOTOS_ASSET_LOADER:  Duration: \(asset.duration)")
        logger.info("🖼️ PHOTOS_ASSET_LOADER:  Dimensions: \(asset.pixelWidth)x\(asset.pixelHeight)")

        return metadata
    }
}