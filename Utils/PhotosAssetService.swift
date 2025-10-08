//
//  PhotosAssetService.swift
//  BreakingFlashcards
//
//  Created by Claude on 9/25/25.
//

import Foundation
import Photos
import AVFoundation
import OSLog

/// Errors that can occur during asset fetching
enum AssetError: Error, LocalizedError {
    case assetNotFound
    case videoRequestFailed
    case permissionDenied
    case invalidIdentifier

    var errorDescription: String? {
        switch self {
        case .assetNotFound:
            return "Asset not found in Photos library"
        case .videoRequestFailed:
            return "Failed to load video from Photos library"
        case .permissionDenied:
            return "Photo library access denied"
        case .invalidIdentifier:
            return "Invalid photo identifier"
        }
    }
}

/// Service for fetching video assets from Photos library
/// MARK: - SINGLETON: Ensures centralized asset loading with proper error handling
@MainActor
class PhotosAssetService {

    // MARK: - Properties
    static let shared = PhotosAssetService()
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "PhotosAssetService")

    // MARK: - Initialization
    private init() {
        logger.info("📸 PHOTOS_ASSET: Service initialized")
    }

    // MARK: - Public API

    /// Fetch AVAsset from Photos library using local identifier
    /// MARK: - ASYNC: Proper async/await with structured concurrency
    /// 📊 METRICS: Logs performance and error states
    // MARK: - FUNC
    func fetchAVAsset(with localIdentifier: String) async throws -> AVAsset {
        logger.info("📸 PHOTOS_ASSET: 🔄 Fetching AVAsset for identifier: \(localIdentifier.prefix(8))...")

        // ✅ VALIDATION: Check identifier before making expensive calls
        guard !localIdentifier.isEmpty else {
            logger.error("📸 PHOTOS_ASSET: ❌ Empty photo identifier provided")
            throw AssetError.invalidIdentifier
        }

        // ✅ PERMISSIONS: Check authorization status first
        let authorizationStatus = await checkPhotoLibraryAuthorization()
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            logger.error("📸 PHOTOS_ASSET: ❌ Photo library permission denied - status: \(String(describing: authorizationStatus))")
            throw AssetError.permissionDenied
        }

        // ✅ FETCH: Use Photos framework to find the asset
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            logger.error("📸 PHOTOS_ASSET: ❌ Asset not found for identifier: \(localIdentifier.prefix(8))...")
            throw AssetError.assetNotFound
        }

        logger.info("📸 PHOTOS_ASSET: ✅ Found PHAsset: \(asset)")

        // ✅ CONFIGURE: Set up video request options for optimal performance
        let options = PHVideoRequestOptions()
        options.version = .original
        options.deliveryMode = .automatic
        options.isNetworkAccessAllowed = true // Essential for iCloud photos
        options.progressHandler = { [weak self] progress, _, _, _ in
            self?.logger.info("📸 PHOTOS_ASSET: 📊 Download progress: \(Int(progress * 100))%")
        }

        // ✅ ASYNC: Use structured concurrency with continuation
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { [weak self] avAsset, audioMix, info in
                Task { @MainActor in
                    guard let self = self else { return }

                    if let asset = avAsset {
                        self.logger.info("📸 PHOTOS_ASSET: ✅ Successfully fetched AVAsset: \(asset)")
                        self.logger.info("📸 PHOTOS_ASSET: 📊 Asset duration: \(CMTimeGetSeconds(asset.duration))s")
                        self.logger.info("📸 PHOTOS_ASSET: 📊 Audio mix available: \(audioMix != nil)")

                        if let info = info {
                            self.logger.info("📸 PHOTOS_ASSET: 📊 Request info: \(info)")

                            // Check for download degradation
                            if let isDegraded = info[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                                self.logger.warning("📸 PHOTOS_ASSET: ⚠️ Asset is degraded (low quality)")
                            }

                            // Check for cloud download
                            if let isInCloud = info[PHImageResultIsInCloudKey] as? Bool, isInCloud {
                                self.logger.info("📸 PHOTOS_ASSET: ☁️ Asset was downloaded from iCloud")
                            }
                        }

                        continuation.resume(returning: asset)
                    } else {
                        let error = info?[PHImageErrorKey] as? Error
                        self.logger.error("📸 PHOTOS_ASSET: ❌ Failed to fetch AVAsset")
                        self.logger.error("📸 PHOTOS_ASSET: ❌ Error details: \(error?.localizedDescription ?? "Unknown error")")
                        continuation.resume(throwing: AssetError.videoRequestFailed)
                    }
                }
            }
        }
    }

    // MARK: - Private Methods

    /// Check current photo library authorization status
    /// MARK: - ASYNC: Proper async authorization check
    // MARK: - FUNC
    private func checkPhotoLibraryAuthorization() async -> PHAuthorizationStatus {
        logger.info("📸 PHOTOS_ASSET: 🔍 Checking photo library authorization status")

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// Get human-readable description of authorization status
    /// 📊 METRICS: Useful for debugging permission issues
    // MARK: - FUNC
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

extension PhotosAssetService {

    /// Check if a video asset is available for a given identifier
    /// MARK: - BOOL: Simple boolean check for UI state management
    // MARK: - FUNC
    func isVideoAvailable(for localIdentifier: String) async -> Bool {
        do {
            _ = try await fetchAVAsset(with: localIdentifier)
            return true
        } catch {
            logger.warning("📸 PHOTOS_ASSET: ⚠️ Video not available for identifier: \(localIdentifier.prefix(8))... - \(error.localizedDescription)")
            return false
        }
    }

    /// Pre-warm asset cache by fetching metadata only
    /// 🚀 PERFORMANCE: Optimizes subsequent asset loading
    // MARK: - FUNC
    func prefetchAssetMetadata(for localIdentifier: String) async {
        logger.info("📸 PHOTOS_ASSET: 🔄 Prefetching metadata for: \(localIdentifier.prefix(8))...")

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            logger.warning("📸 PHOTOS_ASSET: ⚠️ Cannot prefetch - asset not found")
            return
        }

        // Request just the player item (lighter than full asset)
        let options = PHVideoRequestOptions()
        options.version = .original
        options.deliveryMode = .automatic

        PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { playerItem, _ in
            Task { @MainActor in
                if let playerItem = playerItem {
                    self.logger.info("📸 PHOTOS_ASSET: ✅ Metadata prefetched successfully: \(playerItem)")
                } else {
                    self.logger.warning("📸 PHOTOS_ASSET: ⚠️ Failed to prefetch metadata")
                }
            }
        }
    }
}