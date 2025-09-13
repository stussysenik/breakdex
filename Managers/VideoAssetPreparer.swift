import SwiftUI
import PhotosUI
import AVKit
import OSLog

// MARK: - VideoAssetPreparer Protocol
protocol VideoAssetPreparerProtocol {
    func prepareVideo(from item: PhotosPickerItem) async throws -> PreparedVideoResult
}

// MARK: - Prepared Video Result
struct PreparedVideoResult {
    let asset: AVAsset
    let photosIdentifier: String?
    let filename: String
    let playerViewModel: any VideoPlayerViewModelProtocol
}

// MARK: - Video Asset Preparer
@MainActor
class VideoAssetPreparer: VideoAssetPreparerProtocol {
    
    // MARK: - Dependencies
    private let videoLoader: AddMoveVideoLoader
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "VideoAssetPreparer")
    
    // MARK: - Initialization
    init(videoLoader: AddMoveVideoLoader = AddMoveVideoLoader()) {
        self.videoLoader = videoLoader
        logger.info("🎬 VIDEO_PREPARER: Initialized")
    }
    
    // MARK: - Public API
    
    /// Single Responsibility: Prepare video asset and create player view model
    func prepareVideo(from item: PhotosPickerItem) async throws -> PreparedVideoResult {
        logger.info("🎬 VIDEO_PREPARER: prepareVideo called")
        logger.info("🎬 VIDEO_PREPARER: Item ID: \(item.itemIdentifier ?? "nil")")
        logger.info("🎬 VIDEO_PREPARER: Supported content types: \(item.supportedContentTypes)")
        logger.info("🎬 VIDEO_PREPARER: Thread: \(Thread.current.isMainThread ? "Main" : "Background")")
        
        // Load video asset using VideoLoader
        logger.info("🎬 VIDEO_PREPARER: 📊 Memory before loading: \(os_proc_available_memory() / (1024*1024)) MB available")
        let loaderResult = try await loadVideoWithRetry(from: item)
        logger.info("🎬 VIDEO_PREPARER: 📊 Memory after loading: \(os_proc_available_memory() / (1024*1024)) MB available")
        
        // Extract async calls to avoid autoclosure concurrency issues
        let duration = try await loaderResult.asset.load(.duration).seconds
        let tracksCount = try await loaderResult.asset.load(.tracks).count
        logger.info("🎬 VIDEO_PREPARER: 📊 Asset details - duration: \(duration)s, tracks: \(tracksCount)")
        
        // Create player view model
        logger.info("🎬 VIDEO_PREPARER: Creating UpdatedVideoPlayerViewModel synchronously")
        let playerViewModel = UpdatedVideoPlayerViewModel(
            asset: loaderResult.asset, 
            rotationQuarterTurns: 0, 
            appContainer: AppContainer.shared
        )
        logger.info("🎬 VIDEO_PREPARER: 📊 Memory after creating player VM: \(os_proc_available_memory() / (1024*1024)) MB available")
        
        // Wait for player to be ready
        logger.info("🎬 VIDEO_PREPARER: ⏳ Waiting for UpdatedVideoPlayerViewModel to become ready...")
        let readyStartTime = Date()
        while !playerViewModel.isPlayerReady {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            if Task.isCancelled {
                logger.info("🎬 VIDEO_PREPARER: Video preparation task was cancelled during player readiness wait")
                throw CancellationError()
            }
        }
        let readyTime = Date().timeIntervalSince(readyStartTime)
        logger.info("🎬 VIDEO_PREPARER: ✅ UpdatedVideoPlayerViewModel is ready (took \(String(format: "%.2f", readyTime))s)")
        logger.info("🎬 VIDEO_PREPARER: 📊 Memory after player ready: \(os_proc_available_memory() / (1024*1024)) MB available")
        
        let result = PreparedVideoResult(
            asset: loaderResult.asset,
            photosIdentifier: loaderResult.photosIdentifier,
            filename: loaderResult.filename,
            playerViewModel: playerViewModel
        )
        
        logger.info("🎬 VIDEO_PREPARER: ✅ Video preparation completed successfully")
        logger.info("🎬 VIDEO_PREPARER: 📊 Result details - filename: \(result.filename), photosID: \(result.photosIdentifier ?? "nil")")
        
        return result
    }
    
    // MARK: - Private Methods
    
    /// Load video with retry logic
    private func loadVideoWithRetry(from item: PhotosPickerItem) async throws -> AddMoveVideoLoaderResult {
        logger.info("🎬 VIDEO_PREPARER: 🔄 Starting video loading retry loop")
        
        var lastError: Error?
        let maxRetries = 3
        var retryCount = 0
        
        logger.info("🎬 VIDEO_PREPARER: 🔄 Starting retry loop (max retries: \(maxRetries))")
        
        while retryCount < maxRetries {
            logger.info("🎬 VIDEO_PREPARER: 🔄 Attempt #\(retryCount + 1) of \(maxRetries)")
            
            do {
                if retryCount > 0 {
                    let delay = pow(2.0, Double(retryCount)) * 1_000_000_000 // Exponential backoff in nanoseconds
                    logger.info("🎬 VIDEO_PREPARER: Retry attempt #\(retryCount + 1) after \(delay / 1_000_000_000) seconds delay")
                    try await Task.sleep(nanoseconds: UInt64(delay))
                }
                
                logger.info("🎬 VIDEO_PREPARER: Calling VideoLoader.loadVideo() (Attempt #\(retryCount + 1))")
                let result = try await videoLoader.loadVideo(from: item)
                
                logger.info("🎬 VIDEO_PREPARER: ✅ Video loading successful on attempt #\(retryCount + 1)")
                return result
                
            } catch {
                if Task.isCancelled {
                    logger.info("🎬 VIDEO_PREPARER: Video loading task was cancelled (error handling)")
                    throw CancellationError()
                }
                
                retryCount += 1
                lastError = error
                
                logger.error("🎬 VIDEO_PREPARER: ❌ Video loading failed (Attempt #\(retryCount))")
                logger.error("🎬 VIDEO_PREPARER: Error type: \(type(of: error))")
                logger.error("🎬 VIDEO_PREPARER: Error details: \(error.localizedDescription)")
                logger.error("🎬 VIDEO_PREPARER: 📊 Memory after error: \(os_proc_available_memory() / (1024*1024)) MB available")
                
                if retryCount < maxRetries {
                    let delay = pow(2.0, Double(retryCount))
                    logger.info("🎬 VIDEO_PREPARER: ⏳ Will retry after \(delay) seconds (Attempt \(retryCount) of \(maxRetries))")
                }
            }
        }
        
        // All retries failed
        logger.error("🎬 VIDEO_PREPARER: ❌ Video loading loop completed without success")
        if let error = lastError {
            logger.error("🎬 VIDEO_PREPARER: ❌ All \(maxRetries) retry attempts failed")
            logger.error("🎬 VIDEO_PREPARER: Final error: \(error.localizedDescription)")
            logger.error("🎬 VIDEO_PREPARER: 📊 Memory at failure: \(os_proc_available_memory() / (1024*1024)) MB available")
            logger.error("🎬 VIDEO_PREPARER: 🔍 Detailed error info: \(String(describing: error))")
            throw error
        } else {
            logger.error("🎬 VIDEO_PREPARER: ❌ No error recorded but video loading failed")
            throw NSError(domain: "VideoAssetPreparer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video loading failed for unknown reasons"])
        }
    }
}