@preconcurrency import Foundation
@preconcurrency import Photos
import AVFoundation
import Combine

/// Actor-based Photos client for typed, cancelable PhotoKit operations
@globalActor actor PhotosClient {
    static let shared = PhotosClient()

    // MARK: - Types
    enum AssetHandle {
        case file(URL)
        case composed(AVAsset)

        var asset: AVAsset {
            switch self {
            case .file(let url):
                return AVURLAsset(url: url)
            case .composed(let asset):
                return asset
            }
        }

        var identifier: String {
            switch self {
            case .file(let url):
                return url.lastPathComponent
            case .composed(let asset):
                return asset.description
            }
        }

        var isFileBacked: Bool {
            switch self {
            case .file:
                return true
            case .composed:
                return false
            }
        }
    }

    enum PhotosError: LocalizedError {
        case permissionDenied
        case assetNotFound
        case networkRequired
        case cancelled
        case unknown(Error)

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Photos permission denied"
            case .assetNotFound:
                return "Photo asset not found"
            case .networkRequired:
                return "Network access required for iCloud asset"
            case .cancelled:
                return "Operation cancelled"
            case .unknown(let error):
                return "Photos error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Private Properties
    private var activeRequests = Set<PHImageRequestID>()
    private let requestQueue = DispatchQueue(label: "com.breakingflashcards.photosclient", qos: .userInitiated)

    // MARK: - Public API

    /// Resolve a Photos asset with network access allowed
    /// - Parameters:
    ///   - asset: PHAsset to resolve
    ///   - allowNetwork: Whether to allow network access for iCloud assets
    /// - Returns: AssetHandle with resolved asset
    func resolveAsset(for asset: PHAsset, allowNetwork: Bool = true) async throws -> AssetHandle {
        try await withTaskCancellationHandler {
            try await _resolveAsset(for: asset, allowNetwork: allowNetwork)
        } onCancel: {
            Task { await self.cancelAllRequests() }
        }
    }

    /// Resolve asset with progress reporting
    /// - Parameters:
    ///   - asset: PHAsset to resolve
    ///   - allowNetwork: Whether to allow network access for iCloud assets
    /// - Returns: Tuple of AssetHandle and progress stream
    func resolveAssetWithProgress(for asset: PHAsset, allowNetwork: Bool = true) async throws -> (AssetHandle, AsyncStream<Double>) {
        let progressSubject = PassthroughSubject<Double, Never>()
        let progressStream = AsyncStream<Double> { continuation in
            let cancellable = progressSubject.sink { progress in
                continuation.yield(progress)
            }
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }

        let handle = try await withTaskCancellationHandler {
            try await _resolveAsset(for: asset, allowNetwork: allowNetwork, progressSubject: progressSubject)
        } onCancel: {
            Task { await self.cancelAllRequests() }
        }

        return (handle, progressStream)
    }

    // MARK: - Private Implementation

    private func _resolveAsset(for phAsset: PHAsset, allowNetwork: Bool, progressSubject: PassthroughSubject<Double, Never>? = nil) async throws -> AssetHandle {
        // Request AVAsset
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = allowNetwork
        options.deliveryMode = .highQualityFormat
        options.version = .current

        if let progressSubject = progressSubject {
            options.progressHandler = { progress, error, stop, info in
                progressSubject.send(progress)
                if error != nil {
                    progressSubject.send(completion: .finished)
                }
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            requestQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: PhotosError.cancelled)
                    return
                }

                let requestID = PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { asset, audioMix, info in
                    Task { @MainActor in
                        // Remove from active requests (must be done on actor)
                        await self.removeRequest(requestID)

                        if let error = info?[PHImageErrorKey] as? Error {
                            continuation.resume(throwing: PhotosError.unknown(error))
                            return
                        }

                        if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                            continuation.resume(throwing: PhotosError.cancelled)
                            return
                        }

                        if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded {
                            // For now, we'll accept degraded results
                            // In production, you might want to wait for the final result
                        }

                        guard let asset = asset else {
                            continuation.resume(throwing: PhotosError.assetNotFound)
                            return
                        }

                        let handle: AssetHandle
                        if let urlAsset = asset as? AVURLAsset {
                            handle = .file(urlAsset.url)
                        } else {
                            handle = .composed(asset)
                        }

                        continuation.resume(returning: handle)
                    }
                }

                // Track the request for cancellation
                Task { await self.addRequest(requestID) }
            }
        }
    }

    /// Cancel all active requests
    private func cancelAllRequests() {
        Task { @MainActor in
            for requestID in await activeRequests {
                PHImageManager.default().cancelImageRequest(requestID)
            }
            await clearAllRequests()
        }
    }

    /// Add a specific request (actor-isolated)
    private func addRequest(_ requestID: PHImageRequestID) {
        activeRequests.insert(requestID)
    }

    /// Remove a specific request (actor-isolated)
    private func removeRequest(_ requestID: PHImageRequestID) {
        activeRequests.remove(requestID)
    }

    /// Clear all requests (actor-isolated)
    private func clearAllRequests() {
        activeRequests.removeAll()
    }

    /// Cancel specific request
    private func cancelRequest(_ requestID: PHImageRequestID) {
        PHImageManager.default().cancelImageRequest(requestID)
        Task { await removeRequest(requestID) }
    }
}