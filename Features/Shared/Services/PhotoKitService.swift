//
//  PhotoKitService.swift
//  BreakingFlashcards
//
//  Created by Claude on 9/26/25.
//

import Foundation
import Photos
import AVFoundation
import OSLog

/// Errors that can occur during PhotoKit operations
enum PhotoKitError: Error, LocalizedError {
    case albumCreationFailed
    case albumNotFoundAfterCreation
    case assetCreationFailed
    case assetIdentifierUnavailable
    case permissionDenied
    case invalidFileURL
    case saveOperationFailed
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .albumCreationFailed:
            return "Failed to create photo album"
        case .albumNotFoundAfterCreation:
            return "Album was created but could not be found afterward"
        case .assetCreationFailed:
            return "Failed to create video asset"
        case .assetIdentifierUnavailable:
            return "Asset identifier is not available"
        case .permissionDenied:
            return "Photo library access denied"
        case .invalidFileURL:
            return "Invalid video file URL"
        case .saveOperationFailed:
            return "Photo save operation failed"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

/// Atomic PhotoKit service for saving videos to albums
/// MARK: - SINGLETON: Ensures centralized photo operations with atomic guarantees
/// 🔄 ATOMIC: Prevents empty albums by performing album creation and asset addition in same transaction
///  LOGGING: Comprehensive OSLog integration for debugging
@MainActor
class PhotoKitService {

    // MARK: - Properties
    static let shared = PhotoKitService()
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "PhotoKitService")
    private let albumName = "BreakDex"

    // MARK: - Initialization
    private init() {
        logger.info("📸 PHOTOKIT: Service initialized")
    }

    // MARK: - Public API

    /// Save video to album atomically
    /// This is the main entry point for saving videos to the BreakDex album
    /// MARK: - ATOMIC: Creates album and adds asset in single performChanges block
    /// 🔄 IDEMPOTENT: Will reuse existing album if available
    // MARK: - FUNC
    func saveVideoToBreakDexAlbum(_ fileURL: URL) async throws -> String {
        logger.info("📸 PHOTOKIT: 🔄 Starting atomic save to BreakDex album")
        logger.info("📸 PHOTOKIT: File URL: \(fileURL.lastPathComponent)")

        // ✅ VALIDATION: Check file URL before making expensive calls
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.error("📸 PHOTOKIT: ❌ File does not exist at URL: \(fileURL.path)")
            throw PhotoKitError.invalidFileURL
        }

        // ✅ PERMISSIONS: Check authorization status first
        let authorizationStatus = await checkPhotoLibraryAuthorization()
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            logger.error("📸 PHOTOKIT: ❌ Photo library permission denied - status: \(String(describing: authorizationStatus))")
            throw PhotoKitError.permissionDenied
        }

        // ✅ ATOMIC: Perform save operation in single transaction
        let localIdentifier = try await atomicSaveVideo(fileURL: fileURL, albumName: albumName)

        logger.info("📸 PHOTOKIT: ✅ Atomic save completed successfully")
        logger.info("📸 PHOTOKIT:  Asset identifier: \(localIdentifier)")

        return localIdentifier
    }

    /// Get or create the BreakDex album idempotently
    /// 🔄 IDEMPOTENT: No matter how many times it's called, result is single album
    // MARK: - FUNC
    func getOrCreateBreakDexAlbum() async throws -> PHAssetCollection {
        logger.info("📸 PHOTOKIT: 🔍 Getting or creating BreakDex album")

        // Try to find existing album first
        if let existingAlbum = await findAlbum(named: albumName) {
            logger.info("📸 PHOTOKIT: ✅ Found existing BreakDex album")
            return existingAlbum
        }

        // Create new album if it doesn't exist
        logger.info("📸 PHOTOKIT: 🆕 Creating new BreakDex album")
        return try await createAlbum(named: albumName)
    }

    // MARK: - Private Methods

    /// Atomic save operation that creates album and adds asset in single transaction
    /// MARK: - ATOMIC: This is the core function that prevents empty albums
    // MARK: - FUNC
    private func atomicSaveVideo(fileURL: URL, albumName: String) async throws -> String {
        logger.info("📸 PHOTOKIT: ⚡ Performing atomic save operation")

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: PhotoKitError.saveOperationFailed)
                return
            }

            var assetPlaceholder: PHObjectPlaceholder?
            var albumPlaceholder: PHObjectPlaceholder?

            PHPhotoLibrary.shared().performChanges({
                // Step 1: Find or create album within the change block
                let fetchOptions = PHFetchOptions()
                fetchOptions.predicate = NSPredicate(format: "title == %@", albumName)
                let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

                var albumChangeRequest: PHAssetCollectionChangeRequest?

                if let existingAlbum = collections.firstObject {
                    // Use existing album
                    albumChangeRequest = PHAssetCollectionChangeRequest(for: existingAlbum)
                    self.logger.info("📸 PHOTOKIT: 📂 Using existing album in atomic operation")
                } else {
                    // Create new album
                    let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                    albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
                    albumChangeRequest = createAlbumRequest
                    self.logger.info("📸 PHOTOKIT: 🆕 Creating new album in atomic operation")
                }

                // Step 2: Create video asset
                guard let assetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL) else {
                    self.logger.error("📸 PHOTOKIT: ❌ Failed to create asset request")
                    continuation.resume(throwing: PhotoKitError.assetCreationFailed)
                    return
                }

                assetPlaceholder = assetRequest.placeholderForCreatedAsset

                // Step 3: Add asset to album in same transaction
                guard let albumChangeRequest = albumChangeRequest,
                      let assetPlaceholder = assetPlaceholder else {
                    self.logger.error("📸 PHOTOKIT: ❌ Failed to create album or asset placeholder")
                    continuation.resume(throwing: PhotoKitError.saveOperationFailed)
                    return
                }

                albumChangeRequest.addAssets([assetPlaceholder] as NSArray)
                self.logger.info("📸 PHOTOKIT: 🔗 Asset added to album in atomic operation")

            }) { [weak self] success, error in
                guard let self = self else { return }

                if success {
                    self.logger.info("📸 PHOTOKIT: ✅ Atomic operation completed successfully")

                    // Handle album placeholder if we created a new album
                    if let albumPlaceholder = albumPlaceholder {
                        self.logger.info("📸 PHOTOKIT: 🆕 New album created with placeholder")
                    }

                    // Return the asset identifier
                    if let localIdentifier = assetPlaceholder?.localIdentifier {
                        self.logger.info("📸 PHOTOKIT: ✅ Asset saved with identifier: \(localIdentifier)")
                        continuation.resume(returning: localIdentifier)
                    } else {
                        self.logger.error("📸 PHOTOKIT: ❌ Asset identifier not available after save")
                        continuation.resume(throwing: PhotoKitError.assetIdentifierUnavailable)
                    }
                } else {
                    let saveError = error ?? NSError(domain: "PhotoKitService", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Unknown error during atomic save"
                    ])

                    self.logger.error("📸 PHOTOKIT: ❌ Atomic save operation failed")
                    self.logger.error("📸 PHOTOKIT: ❌ Error: \(saveError.localizedDescription)")
                    self.logger.error("📸 PHOTOKIT: ❌ Error type: \(type(of: saveError))")

                    continuation.resume(throwing: PhotoKitError.unknown(saveError))
                }
            }
        }
    }
    // MARK: - FUNC
    /// Find album by name
    private func findAlbum(named name: String) async -> PHAssetCollection? {
        logger.info("📸 PHOTOKIT: 🔍 Searching for album: \(name)")

        return await withCheckedContinuation { continuation in
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "title == %@", name)

            let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

            if let album = collections.firstObject {
                logger.info("📸 PHOTOKIT: ✅ Found album: \(album)")
                continuation.resume(returning: album)
            } else {
                logger.info("📸 PHOTOKIT: ❌ Album not found: \(name)")
                continuation.resume(returning: nil)
            }
        }
    }

    /// Create new album by name
    private func createAlbum(named name: String) async throws -> PHAssetCollection {
        logger.info("📸 PHOTOKIT: 🆕 Creating album: \(name)")

        return try await withCheckedThrowingContinuation { continuation in
            var collectionPlaceholder: PHObjectPlaceholder?

            PHPhotoLibrary.shared().performChanges {
                let createRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                collectionPlaceholder = createRequest.placeholderForCreatedAssetCollection
            } completionHandler: { success, error in
                if success, let collectionPlaceholder = collectionPlaceholder {
                    let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionPlaceholder.localIdentifier], options: nil)

                    if let album = fetchResult.firstObject {
                        Logger(subsystem: "com.breakingflashcards", category: "PhotoKitService").info("📸 PHOTOKIT: ✅ Album created successfully: \(album)")
                        continuation.resume(returning: album)
                    } else {
                        Logger(subsystem: "com.breakingflashcards", category: "PhotoKitService").error("📸 PHOTOKIT: ❌ Album placeholder found but album not accessible")
                        continuation.resume(throwing: PhotoKitError.albumNotFoundAfterCreation)
                    }
                } else {
                    let createError = error ?? NSError(domain: "PhotoKitService", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Unknown error during album creation"
                    ])

                    Logger(subsystem: "com.breakingflashcards", category: "PhotoKitService").error("📸 PHOTOKIT: ❌ Album creation failed: \(createError.localizedDescription)")
                    continuation.resume(throwing: PhotoKitError.albumCreationFailed)
                }
            }
        }
    }
    // MARK: - FUNC
    /// Check photo library authorization status
    private func checkPhotoLibraryAuthorization() async -> PHAuthorizationStatus {
        logger.info("📸 PHOTOKIT: 🔍 Checking photo library authorization")

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }
    // MARK: - FUNC
    /// Get human-readable description of authorization status
    private func authorizationStatusDescription(_ status: PHAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .limited:
            return "Limited"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - Convenience Extensions

extension PhotoKitService {
    // MARK: - FUNC
    /// Check if BreakDex album exists
    func breakDexAlbumExists() async -> Bool {
        do {
            _ = try await getOrCreateBreakDexAlbum()
            return true
        } catch {
            logger.error("📸 PHOTOKIT: ❌ BreakDex album check failed: \(error.localizedDescription)")
            return false
        }
    }
    // MARK: - FUNC
    /// Get all videos in BreakDex album
    func getAllVideosInBreakDex() async -> [PHAsset] {
        logger.info("📸 PHOTOKIT: 📂 Fetching all videos from BreakDex album")

        do {
            let album = try await getOrCreateBreakDexAlbum()

            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

            let fetchResult = PHAsset.fetchAssets(in: album, options: fetchOptions)
            var assets: [PHAsset] = []

            fetchResult.enumerateObjects { asset, _, _ in
                assets.append(asset)
            }

            logger.info("📸 PHOTOKIT: ✅ Found \(assets.count) videos in BreakDex album")
            return assets

        } catch {
            logger.error("📸 PHOTOKIT: ❌ Failed to fetch videos from BreakDex album: \(error.localizedDescription)")
            return []
        }
    }
    // MARK: - FUNC
    /// Delete asset from BreakDex album by local identifier
    func deleteVideoFromBreakDex(localIdentifier: String) async throws {
        logger.info("📸 PHOTOKIT: 🗑️ Deleting video from BreakDex album: \(localIdentifier)")

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            logger.error("📸 PHOTOKIT: ❌ Asset not found for deletion: \(localIdentifier)")
            throw PhotoKitError.assetCreationFailed
        }

        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            } completionHandler: { success, error in
                if success {
                    Logger(subsystem: "com.breakingflashcards", category: "PhotoKitService").info("📸 PHOTOKIT: ✅ Video deleted successfully: \(localIdentifier)")
                    continuation.resume()
                } else {
                    let deleteError = error ?? NSError(domain: "PhotoKitService", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Unknown error during asset deletion"
                    ])

                    Logger(subsystem: "com.breakingflashcards", category: "PhotoKitService").error("📸 PHOTOKIT: ❌ Video deletion failed: \(deleteError.localizedDescription)")
                    continuation.resume(throwing: PhotoKitError.unknown(deleteError))
                }
            }
        }
    }
}