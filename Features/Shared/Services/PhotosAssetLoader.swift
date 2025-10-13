import Foundation
import Photos
import AVKit
import OSLog

// MARK: - Photos Asset Loader Service
/// Minimal implementation for loading video assets from Photos library
@MainActor
class PhotosAssetLoader {

    /// Fetch an AVAsset from the Photos library using its local identifier
    /// - Parameter identifier: The Photos library local identifier string
    /// - Returns: AVAsset if found and accessible, nil otherwise
    static func fetchAsset(with identifier: String) async -> AVAsset? {
        guard !identifier.isEmpty else {
            return nil
        }

        let authorizationStatus = PHPhotoLibrary.authorizationStatus(for: PHAccessLevel.readWrite)
        guard authorizationStatus == PHAuthorizationStatus.authorized else {
            return nil
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let phAsset = fetchResult.firstObject else {
            return nil
        }

        let options = PHVideoRequestOptions()
        options.version = .original
        options.deliveryMode = .automatic
        options.isNetworkAccessAllowed = true

        do {
            return try await withCheckedThrowingContinuation { continuation in
                PHImageManager.default().requestAVAsset(
                    forVideo: phAsset,
                    options: options
                ) { avAsset, _, info in
                    if let avAsset = avAsset {
                        continuation.resume(returning: avAsset)
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "PhotosAssetLoader",
                            code: 1001,
                            userInfo: [NSLocalizedDescriptionKey: "AVAsset request returned nil"]
                        ))
                    }
                }
            }
        } catch {
            return nil
        }
    }

    /// Check if an asset exists in the Photos library without loading it
    /// - Parameter identifier: The Photos library local identifier string
    /// - Returns: Boolean indicating if the asset exists
    static func assetExists(with identifier: String) -> Bool {
        guard !identifier.isEmpty else {
            return false
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return fetchResult.count > 0
    }
}