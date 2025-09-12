import Foundation
import AVKit
import PhotosUI
import Photos
import Combine

/// Service responsible for loading and processing videos from Photos library
/// Handles the complex video loading pipeline safely in the background
@MainActor
class VideoLoaderService: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var status: String = ""
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var result: Result<LoadedVideo, Error>?

    // MARK: - Types
    struct LoadedVideo {
        let asset: AVAsset
        let identifier: String
        let filename: String
    }

    // MARK: - Private Properties
    private var assetCache: [String: AVAsset] = [:]
    private var currentTask: Task<Void, Never>?

    // MARK: - Public API

    /// Load video from PhotosPickerItem
    /// - Parameter item: The selected PhotosPickerItem
    func loadVideo(from item: PhotosPickerItem) {
        // Cancel any previous task
        currentTask?.cancel()

        // Set initial loading state
        isLoading = true
        status = "Preparing to load video..."
        progress = 0.0
        result = nil

        // Start the loading task
        currentTask = Task {
            await performVideoLoading(item: item)
        }
    }

    /// Cancel current loading operation
    func cancelLoading() {
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
        result = nil
    }

    // MARK: - Private Methods

    private func performVideoLoading(item: PhotosPickerItem) async {
        do {
            // Initial progress update
            await updateProgress(to: 0.1, status: "Analyzing video properties...")

            // Check if we have a Photos identifier
            if let identifier = item.itemIdentifier {
                // Load from Photos library
                let phAsset = try await loadAsset(from: identifier)
                await updateProgress(to: 0.4, status: "Loading video from Photos library...")

                let avAsset = try await createAVAsset(from: phAsset)
                await updateProgress(to: 0.8, status: "Finalizing video preview...")

                let filename = try await extractFilename(from: phAsset)
                let loadedVideo = LoadedVideo(
                    asset: avAsset,
                    identifier: identifier,
                    filename: filename
                )

                // Cache the asset
                assetCache[identifier] = avAsset

                await updateProgress(to: 1.0, status: "Video loaded successfully! 🎬")
                result = .success(loadedVideo)

            } else {
                // Load directly from PhotosPickerItem data
                await updateProgress(to: 0.3, status: "Preparing to download video...")

                let avAsset = try await loadAVAssetDirectlyFromPhotosPickerItem(item)
                await updateProgress(to: 0.8, status: "Finalizing video preview...")

                let tempIdentifier = "temp-\(UUID().uuidString)"
                let loadedVideo = LoadedVideo(
                    asset: avAsset,
                    identifier: tempIdentifier,
                    filename: "Selected Video"
                )

                result = .success(loadedVideo)
                await updateProgress(to: 1.0, status: "Video loaded successfully! 🎬")
            }

        } catch {
            result = .failure(error)
            status = "Failed to load video: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func updateProgress(to value: Double, status: String) async {
        self.progress = value
        self.status = status
    }

    // MARK: - Photos Asset Loading Methods

    private func loadAsset(from identifier: String) async throws -> PHAsset {
        return try await withCheckedThrowingContinuation { continuation in
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)

            if let asset = fetchResult.firstObject {
                continuation.resume(returning: asset)
            } else {
                continuation.resume(throwing: NSError(
                    domain: "VideoLoaderService",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Could not find asset in Photos library."]
                ))
            }
        }
    }

    private func createAVAsset(from asset: PHAsset) async throws -> AVAsset {
        // First attempt with immediate response
        do {
            return try await attemptAVAssetCreation(from: asset)
        } catch let error as NSError where error.domain == "PHPhotosErrorDomain" && error.code == 3164 {
            // iCloud download failure - try retry mechanism
            return try await retryAVAssetCreation(from: asset, originalError: error)
        }
    }

    private func attemptAVAssetCreation(from asset: PHAsset) async throws -> AVAsset {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, audioMix, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    continuation.resume(throwing: NSError(
                        domain: "VideoLoaderService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Request cancelled"]
                    ))
                    return
                }

                guard let avAsset = avAsset else {
                    continuation.resume(throwing: NSError(
                        domain: "VideoLoaderService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No asset returned"]
                    ))
                    return
                }

                continuation.resume(returning: avAsset)
            }
        }
    }

    private func retryAVAssetCreation(from asset: PHAsset, originalError: NSError) async throws -> AVAsset {
        // Basic retry mechanism for iCloud downloads
        // In a full implementation, this would include iCloud status checks
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        return try await attemptAVAssetCreation(from: asset)
    }

    private func loadAVAssetDirectlyFromPhotosPickerItem(_ item: PhotosPickerItem) async throws -> AVAsset {
        return try await withCheckedThrowingContinuation { continuation in
            item.loadTransferable(type: Data.self) { result in
                Task {
                    switch result {
                    case .success(let data):
                        guard let videoData = data else {
                            continuation.resume(throwing: NSError(
                                domain: "VideoLoaderService",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "No video data received"]
                            ))
                            return
                        }

                        do {
                            // Calculate data size for feedback
                            let dataSizeMB = Double(videoData.count) / (1024.0 * 1024.0)
                            let sizeDescription = dataSizeMB > 100.0 ? ">100MB" : String(format: "%.1fMB", dataSizeMB)

                            // Create a temporary file URL for the video data
                            let tempDirectory = FileManager.default.temporaryDirectory
                            let tempURL = tempDirectory.appendingPathComponent("temp_video_\(UUID().uuidString).mov")

                            // Write the data to a temporary file
                            try videoData.write(to: tempURL)

                            // Create AVAsset from the temporary file
                            let asset = AVURLAsset(url: tempURL)
                            continuation.resume(returning: asset)

                        } catch {
                            continuation.resume(throwing: error)
                        }

                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func extractFilename(from asset: PHAsset) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let resources = PHAssetResource.assetResources(for: asset)
            if let resource = resources.first(where: { $0.type == .video }) {
                continuation.resume(returning: resource.originalFilename)
            } else {
                continuation.resume(returning: "Video")
            }
        }
    }
}
