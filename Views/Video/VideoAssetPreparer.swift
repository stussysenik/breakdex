import AVFoundation
import OSLog
import Photos

private let logger = Logger(subsystem: "com.breakingflashcards", category: "VideoAssetPreparer")

/// Single Responsibility: Prepare video assets for display
/// Handles all async video processing and provides display-ready components
@MainActor
final class VideoAssetPreparer {

    /// Result of video asset preparation
    struct PreparationResult {
        let viewModel: any VideoPlayerViewModelProtocol
        let filename: String
        let photosIdentifier: String?
    }

    /// Prepare a video asset for display with rotation
    /// - Parameters:
    ///   - asset: The source AVAsset
    ///   - photosIdentifier: Photos library identifier (optional)
    ///   - rotationQuarterTurns: Number of quarter turns for rotation
    /// - Returns: Display-ready components
    static func prepareForDisplay(
        asset: AVAsset,
        photosIdentifier: String?,
        rotationQuarterTurns: Int
    ) async throws -> PreparationResult {
        logger.info("🎬 ASSET_PREPARER: prepareForDisplay called")
        logger.info("🎬 ASSET_PREPARER: Asset type: \(type(of: asset))")
        logger.info("🎬 ASSET_PREPARER: Photos ID: \(photosIdentifier ?? "nil")")
        logger.info("🎬 ASSET_PREPARER: Rotation: \(rotationQuarterTurns)°")

        // Step 1: Validate asset
        try await validateAsset(asset)

        // Step 2: Get filename
        let filename = try await extractFilename(from: asset, photosIdentifier: photosIdentifier)
        logger.info("🎬 ASSET_PREPARER: Filename extracted: \(filename)")

        // Step 3: Create display-ready VideoPlayerViewModel
        let viewModel = try await createVideoPlayerViewModel(
            with: asset,
            rotationQuarterTurns: rotationQuarterTurns
        )

        logger.info("🎬 ASSET_PREPARER: ✅ Preparation completed successfully")
        return PreparationResult(
            viewModel: viewModel,
            filename: filename,
            photosIdentifier: photosIdentifier
        )
    }

    // MARK: - Private Methods

    private static func validateAsset(_ asset: AVAsset) async throws {
        logger.info("🎬 ASSET_PREPARER: Validating asset")

        let duration = try await asset.load(.duration)
        logger.info("🎬 ASSET_PREPARER: Asset duration: \(duration.seconds) seconds")

        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard !tracks.isEmpty else {
            logger.error("🎬 ASSET_PREPARER: No video tracks found")
            throw NSError(domain: "VideoAssetPreparer", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "No video tracks found"])
        }

        logger.info("🎬 ASSET_PREPARER: Asset validation passed")
    }

    private static func extractFilename(from asset: AVAsset, photosIdentifier: String?) async throws -> String {
        logger.info("🎬 ASSET_PREPARER: Extracting filename")

        if let photosIdentifier = photosIdentifier {
            // Try to get filename from Photos library
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [photosIdentifier], options: nil)
            if let phAsset = result.firstObject {
                let resources = PHAssetResource.assetResources(for: phAsset)
                if let videoResource = resources.first(where: { $0.type == .video }) {
                    let filename = videoResource.originalFilename
                    logger.info("🎬 ASSET_PREPARER: Photos filename: \(filename)")
                    return filename
                }
            }
        }

        // Fallback: try to extract from asset URL
        if let urlAsset = asset as? AVURLAsset {
            let filename = urlAsset.url.lastPathComponent
            logger.info("🎬 ASSET_PREPARER: URL filename: \(filename)")
            return filename
        }

        // Final fallback
        logger.info("🎬 ASSET_PREPARER: Using default filename")
        return "video.mp4"
    }

    private static func createVideoPlayerViewModel(with asset: AVAsset, rotationQuarterTurns: Int) async throws -> any VideoPlayerViewModelProtocol {
        logger.info("🎬 ASSET_PREPARER: Creating VideoPlayerViewModel")

        // Create the view model with synchronous initialization
        let viewModel = UpdatedVideoPlayerViewModel(asset: asset, rotationQuarterTurns: rotationQuarterTurns, appContainer: AppContainer.shared)

        // Wait for the view model to be fully ready
        // Note: The refactored VideoPlayerViewModel doesn't have a waitForReady method
        // Instead, we can check the isPlayerReady property
        while !viewModel.isPlayerReady {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }

        logger.info("🎬 ASSET_PREPARER: VideoPlayerViewModel created and ready")
        return viewModel
    }
}
