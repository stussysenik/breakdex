import AVFoundation
import PhotosUI
import OSLog

// MARK: - VideoLoader
/// Clean service for loading videos from Photos picker
@MainActor
class VideoLoader: ObservableObject {
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "VideoLoader")

    // MARK: - Published Properties
    @Published private(set) var isLoading = false
    @Published private(set) var progress = 0.0
    @Published private(set) var statusMessage = ""

    // MARK: - Loading Methods

    /// Load video from PhotosPickerItem
    /// - Parameter item: The Photos picker item to load
    /// - Returns: AVAsset if successful
    /// - Throws: VideoLoaderError if loading fails
    func loadVideo(from item: PhotosPickerItem) async throws -> AVAsset {
        logger.info("📹 Starting video loading from Photos picker")

        await MainActor.run {
            isLoading = true
            progress = 0.0
            statusMessage = "Loading video..."
        }

        do {
            // Update progress for loading transferable
            await updateProgress(0.2, status: "Loading video data...")

            // Load the video data
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw VideoLoaderError.failedToLoadData
            }

            await updateProgress(0.5, status: "Processing video...")

            // Create temporary file
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
            try data.write(to: tempURL)

            await updateProgress(0.8, status: "Creating video asset...")

            // Create AVAsset
            let asset = AVAsset(url: tempURL)

            // Validate asset
            guard asset.isReadable else {
                throw VideoLoaderError.assetNotReadable
            }

            await updateProgress(1.0, status: "Video loaded successfully")

            logger.info("✅ Video loaded successfully")
            return asset

        } catch {
            await MainActor.run {
                isLoading = false
                statusMessage = "Loading failed: \(error.localizedDescription)"
            }
            logger.error("❌ Video loading failed: \(error.localizedDescription)")
            throw VideoLoaderError.loadingFailed(underlying: error)
        }
    }

    /// Load video from PHAsset (alternative method)
    /// - Parameters:
    ///   - asset: The Photos library asset
    ///   - options: Optional video request options
    /// - Returns: AVAsset if successful
    /// - Throws: VideoLoaderError if loading fails
    func loadVideo(from asset: PHAsset, options: PHVideoRequestOptions? = nil) async throws -> AVAsset {
        logger.info("📹 Starting video loading from PHAsset")

        await MainActor.run {
            isLoading = true
            progress = 0.0
            statusMessage = "Loading video from Photos..."
        }

        return try await withCheckedThrowingContinuation { continuation in
            let options = options ?? PHVideoRequestOptions()
            options.deliveryMode = .automatic

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, audioMix, info in
                Task { @MainActor in
                    do {
                        guard let asset = avAsset else {
                            throw VideoLoaderError.assetNotAvailable
                        }

                        await self.updateProgress(1.0, status: "Video loaded successfully")
                        logger.info("✅ PHAsset video loaded successfully")
                        continuation.resume(returning: asset)

                    } catch {
                        await MainActor.run {
                            self.isLoading = false
                            self.statusMessage = "Loading failed: \(error.localizedDescription)"
                        }
                        logger.error("❌ PHAsset video loading failed: \(error.localizedDescription)")
                        continuation.resume(throwing: VideoLoaderError.loadingFailed(underlying: error))
                    }
                }
            }
        }
    }

    // MARK: - Private Methods

    private func updateProgress(_ progress: Double, status: String) async {
        await MainActor.run {
            self.progress = progress
            self.statusMessage = status

            if progress >= 1.0 {
                isLoading = false
            }
        }
    }
}

// MARK: - VideoLoaderError

enum VideoLoaderError: LocalizedError {
    case failedToLoadData
    case assetNotReadable
    case assetNotAvailable
    case loadingFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .failedToLoadData:
            return "Failed to load video data"
        case .assetNotReadable:
            return "Video asset is not readable"
        case .assetNotAvailable:
            return "Video asset is not available"
        case .loadingFailed(let error):
            return "Loading failed: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .failedToLoadData:
            return "Please try selecting the video again"
        case .assetNotReadable:
            return "Please select a different video file"
        case .assetNotAvailable:
            return "Please check if the video is still available in Photos"
        case .loadingFailed:
            return "Please try again or check your network connection"
        }
    }
}