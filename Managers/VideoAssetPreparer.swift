import SwiftUI
import PhotosUI
import AVKit
import OSLog
import Foundation

// MARK: - VideoAssetPreparer Protocol
public protocol VideoAssetPreparerProtocol {
    func prepareVideo(from item: PhotosPickerItem) async throws -> PreparedVideoResult
    func prepareAssetForDisplay(asset: AVAsset, photosIdentifier: String) async throws -> PreparedVideoResult
}

// MARK: - Prepared Video Result
public struct PreparedVideoResult {
    let asset: AVAsset
    let photosIdentifier: String?
    let filename: String
    let playerViewModel: any VideoPlayerViewModelProtocol
    let temporaryFileURL: URL?
}

// MARK: - Video Asset Preparer
@MainActor
class VideoAssetPreparer: VideoAssetPreparerProtocol {

    // MARK: - Dependencies
    private let videoLoader: AddMoveVideoLoader
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "VideoAssetPreparer")
    private let diagnosticLogger: DiagnosticLoggingHelper
    private let memoryLogger = CentralizedMemoryLogger.shared

    // MARK: - Performance Tracking
    private var operationTimings: [String: TimeInterval] = [:]
    private var currentCorrelationId: String?

    // MARK: - Initialization
    init(videoLoader: AddMoveVideoLoader = AddMoveVideoLoader()) {
        self.videoLoader = videoLoader
        // Initialize diagnostic logger using a non-main approach
        self.diagnosticLogger = DiagnosticLoggingHelper(
            category: "VideoAssetPreparer",
            enablePerformanceTracking: false,  // Disable to avoid main actor issues
            enableResourceMonitoring: false,    // Disable to avoid main actor issues
            enableDetailedContext: false         // Disable to avoid main actor issues
        )

        logger.info("🎬 VIDEO_PREPARER: 🚀 Initialized with enhanced logging capabilities")
        // Note: async logger calls removed from init - will be logged on first operation
    }
    
    // MARK: - Public API
    
    /// Single Responsibility: Prepare video asset and create player view model
    func prepareVideo(from item: PhotosPickerItem) async throws -> PreparedVideoResult {
        // Generate correlation ID for this operation
        currentCorrelationId = memoryLogger.generateCorrelationId(for: "prepareVideo")
        let correlationId = currentCorrelationId!

        logger.info("🎬 VIDEO_PREPARER: 🚀 prepareVideo called [\(correlationId)]")
        await diagnosticLogger.startTiming("total_video_preparation")

        // Extract information from the custom PhotosPickerItem wrapper
        let itemIdentifier = extractItemIdentifier(from: item)
        let supportedContentTypes = extractSupportedContentTypes(from: item)

        // VideoLoadingStart(correlationID: correlationId, source: "PhotosPicker")
        await diagnosticLogger.logInfo("Starting video preparation", metadata: [
            "correlation_id": correlationId,
            "item_identifier": itemIdentifier ?? "nil",
            "supported_content_types": supportedContentTypes,
            "thread": "Main"
        ])

        // Log initial memory state
        memoryLogger.logMemoryState(context: "Before Loading", correlationId: correlationId, component: "VideoAssetPreparer")

        // Load video asset using VideoLoader
        logger.info("🎬 VIDEO_PREPARER:  Memory before loading: \(MemoryHelper.getDetailedMemoryInfo().available) MB available")
        await diagnosticLogger.startTiming("video_loading_phase")

        let loaderResult = try await loadVideoWithRetry(from: item)

        await diagnosticLogger.stopTiming("video_loading_phase")
        logger.info("🎬 VIDEO_PREPARER:  Memory after loading: \(MemoryHelper.getDetailedMemoryInfo().available) MB available")
        memoryLogger.logMemoryState(context: "After Loading", correlationId: correlationId, component: "VideoAssetPreparer")

        // Extract async calls to avoid autoclosure concurrency issues
        await diagnosticLogger.startTiming("asset_metadata_extraction")
        let duration = try await loaderResult.asset.load(.duration).seconds
        let tracksCount = try await loaderResult.asset.load(.tracks).count
        await diagnosticLogger.stopTiming("asset_metadata_extraction")

        logger.info("🎬 VIDEO_PREPARER:  Asset details - duration: \(duration)s, tracks: \(tracksCount)")
        // AssetLoadingSuccess(correlationID: correlationId, asset: loaderResult.asset, loadTime: operationTimings["video_loading_phase"] ?? 0)

        // Create player view model
        logger.info("🎬 VIDEO_PREPARER: Creating UnifiedVideoPlayerViewModel synchronously")
        await diagnosticLogger.startTiming("player_creation")

        // MARK: - CRITICAL FIX: Add diagnostic logging to track health monitor coordination
        logger.info("🎬 VIDEO_PREPARER: 🏥 Health monitor coordination - preparing player creation")
        await diagnosticLogger.logInfo("Player creation started", metadata: [
            "correlation_id": correlationId,
            "asset_duration": "\(duration)",
            "asset_tracks": "\(tracksCount)"
        ])

        let playerViewModel = UnifiedVideoPlayerViewModel(
            player: AVPlayer(playerItem: AVPlayerItem(asset: loaderResult.asset)),
            mode: .main,
            appContainer: AppContainer.shared
        )

        await diagnosticLogger.stopTiming("player_creation")
        logger.info("🎬 VIDEO_PREPARER: 🏥 Health monitor coordination - player created successfully")
        if let player = playerViewModel.avPlayer {
            // PlayerInitializationSuccess(correlationID: correlationId, player: player, initTime: operationTimings["player_creation"] ?? 0)
        }
        logger.info("🎬 VIDEO_PREPARER:  Memory after creating player VM: \(MemoryHelper.getDetailedMemoryInfo().available) MB available")
        memoryLogger.logMemoryState(context: "After Player Creation", correlationId: correlationId, component: "VideoAssetPreparer")

        // Wait for player to be ready using robust monitoring
        logger.info("🎬 VIDEO_PREPARER: ⏳ Robustly waiting for player item to be ready and buffered...")
        await diagnosticLogger.startTiming("player_readiness_wait")
        let readyStartTime = Date()

        // Use the robust monitor to wait for the item's actual status to be .readyToPlay
        if let playerItem = playerViewModel.playerItem {
            let monitor = PlayerItemStatusMonitor(playerItem: playerItem)
            try await monitor.awaitReadyAndBuffered(timeout: 15.0)
        } else {
            // Fallback in case the item is nil, though this should not happen in a normal flow
            logger.warning("🎬 VIDEO_PREPARER: Player item was nil during readiness check. Using a fallback delay.")
            await diagnosticLogger.logWarning("Player item was nil during readiness check, using fallback", metadata: [
                "correlation_id": correlationId,
                "fallback_delay_ms": "200"
            ])
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        let readyTime = Date().timeIntervalSince(readyStartTime)
        await diagnosticLogger.stopTiming("player_readiness_wait")
        logger.info("🎬 VIDEO_PREPARER: ✅ Player item is confirmed ready (took \(String(format: "%.2f", readyTime))s)")
        // PlayerReadinessSuccess(correlationID: correlationId, waitTime: readyTime)
        logger.info("🎬 VIDEO_PREPARER:  Memory after player ready: \(MemoryHelper.getDetailedMemoryInfo().available) MB available")
        memoryLogger.logMemoryState(context: "After Player Readiness", correlationId: correlationId, component: "VideoAssetPreparer")

        let result = PreparedVideoResult(
            asset: loaderResult.asset,
            photosIdentifier: loaderResult.photosIdentifier,
            filename: loaderResult.filename,
            playerViewModel: playerViewModel,
            temporaryFileURL: loaderResult.temporaryFileURL
        )

        await diagnosticLogger.stopTiming("total_video_preparation")
        logger.info("🎬 VIDEO_PREPARER: ✅ Video preparation completed successfully")
        logger.info("🎬 VIDEO_PREPARER:  Result details - filename: \(result.filename), photosID: \(result.photosIdentifier ?? "nil")")

        // Log final summary
        await diagnosticLogger.logInfo("Video preparation completed", metadata: [
            "correlation_id": correlationId,
            "total_duration_ms": "\(String(format: "%.1f", (operationTimings["total_video_preparation"] ?? 0) * 1000))",
            "loading_duration_ms": "\(String(format: "%.1f", (operationTimings["video_loading_phase"] ?? 0) * 1000))",
            "player_creation_ms": "\(String(format: "%.1f", (operationTimings["player_creation"] ?? 0) * 1000))",
            "readiness_wait_ms": "\(String(format: "%.1f", readyTime * 1000))",
            "result_filename": result.filename,
            "result_photos_id": result.photosIdentifier ?? "nil"
        ])

        // Clean up correlation ID
        memoryLogger.clearCorrelationId(for: "prepareVideo")
        currentCorrelationId = nil

        return result
    }
    
    /// Prepare asset for display without PhotosPickerItem
    func prepareAssetForDisplay(asset: AVAsset, photosIdentifier: String) async throws -> PreparedVideoResult {
        // Generate correlation ID for this operation
        currentCorrelationId = memoryLogger.generateCorrelationId(for: "prepareAssetForDisplay")
        let correlationId = currentCorrelationId!

        logger.info("🎬 VIDEO_PREPARER: 🚀 prepareAssetForDisplay called [\(correlationId)]")
        await diagnosticLogger.startTiming("asset_display_preparation")

        await diagnosticLogger.logInfo("Starting asset preparation for display", metadata: [
            "correlation_id": correlationId,
            "photos_identifier": photosIdentifier,
            "thread": "Main"
        ])

        // Log initial memory state
        memoryLogger.logMemoryState(context: "Before Asset Display", correlationId: correlationId, component: "VideoAssetPreparer")

        // Extract asset metadata
        await diagnosticLogger.startTiming("asset_metadata_extraction")
        let duration = try await asset.load(.duration).seconds
        let tracksCount = try await asset.load(.tracks).count
        await diagnosticLogger.stopTiming("asset_metadata_extraction")

        logger.info("🎬 VIDEO_PREPARER:  Asset details - duration: \(duration)s, tracks: \(tracksCount)")
        // AssetLoadingStart(correlationID: correlationId, source: "DirectAsset")

        // Create player view model
        logger.info("🎬 VIDEO_PREPARER: Creating UnifiedVideoPlayerViewModel synchronously")
        await diagnosticLogger.startTiming("player_creation")

        await diagnosticLogger.logInfo("Player creation started for asset display", metadata: [
            "correlation_id": correlationId,
            "asset_duration": "\(duration)",
            "asset_tracks": "\(tracksCount)",
            "photos_identifier": photosIdentifier
        ])

        let playerViewModel = UnifiedVideoPlayerViewModel(
            player: AVPlayer(playerItem: AVPlayerItem(asset: asset)),
            mode: .main,
            appContainer: AppContainer.shared
        )

        await diagnosticLogger.stopTiming("player_creation")
        if let player = playerViewModel.avPlayer {
            // PlayerInitializationSuccess(correlationID: correlationId, player: player, initTime: operationTimings["player_creation"] ?? 0)
        }
        memoryLogger.logMemoryState(context: "After Player Creation", correlationId: correlationId, component: "VideoAssetPreparer")

        // Wait for player to be ready using robust monitoring
        logger.info("🎬 VIDEO_PREPARER: ⏳ Robustly waiting for player item to be ready and buffered...")
        await diagnosticLogger.startTiming("player_readiness_wait")
        let readyStartTime = Date()

        // Use the robust monitor to wait for the item's actual status to be .readyToPlay
        if let playerItem = playerViewModel.playerItem {
            let monitor = PlayerItemStatusMonitor(playerItem: playerItem)
            try await monitor.awaitReadyAndBuffered(timeout: 15.0)
        } else {
            // Fallback in case the item is nil, though this should not happen in a normal flow
            logger.warning("🎬 VIDEO_PREPARER: Player item was nil during readiness check. Using a fallback delay.")
            await diagnosticLogger.logWarning("Player item was nil during readiness check, using fallback", metadata: [
                "correlation_id": correlationId,
                "fallback_delay_ms": "200"
            ])
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        let readyTime = Date().timeIntervalSince(readyStartTime)
        await diagnosticLogger.stopTiming("player_readiness_wait")
        logger.info("🎬 VIDEO_PREPARER: ✅ Player item is confirmed ready (took \(String(format: "%.2f", readyTime))s)")
        // PlayerReadinessSuccess(correlationID: correlationId, waitTime: readyTime)
        memoryLogger.logMemoryState(context: "After Player Readiness", correlationId: correlationId, component: "VideoAssetPreparer")

        let result = PreparedVideoResult(
            asset: asset,
            photosIdentifier: photosIdentifier,
            filename: "Video",
            playerViewModel: playerViewModel,
            temporaryFileURL: nil
        )

        await diagnosticLogger.stopTiming("asset_display_preparation")
        logger.info("🎬 VIDEO_PREPARER: ✅ Asset preparation completed successfully")

        // Log final summary
        await diagnosticLogger.logInfo("Asset preparation for display completed", metadata: [
            "correlation_id": correlationId,
            "total_duration_ms": "\(String(format: "%.1f", (operationTimings["asset_display_preparation"] ?? 0) * 1000))",
            "player_creation_ms": "\(String(format: "%.1f", (operationTimings["player_creation"] ?? 0) * 1000))",
            "readiness_wait_ms": "\(String(format: "%.1f", readyTime * 1000))",
            "asset_duration": "\(duration)",
            "asset_tracks": "\(tracksCount)"
        ])

        // Clean up correlation ID
        memoryLogger.clearCorrelationId(for: "prepareAssetForDisplay")
        currentCorrelationId = nil

        return result
    }
    
    // MARK: - Private Methods

    /// Extract item identifier from custom PhotosPickerItem wrapper
    private func extractItemIdentifier(from item: PhotosPickerItem) -> String? {
        // Use the itemIdentifier property from our custom wrapper
        return item.itemIdentifier
    }

    /// Extract supported content types from custom PhotosPickerItem wrapper
    private func extractSupportedContentTypes(from item: PhotosPickerItem) -> String {
        // Use the supportedContentTypes property from our custom wrapper
        return "\(item.supportedContentTypes)"
    }

    /// Load video with retry logic
    private func loadVideoWithRetry(from item: PhotosPickerItem) async throws -> AddMoveVideoLoaderResult {
        let correlationId = currentCorrelationId ?? "unknown"

        logger.info("🎬 VIDEO_PREPARER: 🔄 Starting video loading retry loop [\(correlationId)]")
        await diagnosticLogger.startTiming("retry_loading_operation")

        var lastError: Error?
        let maxRetries = 3
        var retryCount = 0

        await diagnosticLogger.logInfo("Starting retry loading operation", metadata: [
            "correlation_id": correlationId,
            "max_retries": "\(maxRetries)",
            "retry_strategy": "exponential_backoff"
        ])

        // Log initial memory state before retry loop
        memoryLogger.logMemoryState(context: "Before Retry Loop", correlationId: correlationId, component: "VideoAssetPreparer")

        while retryCount < maxRetries {
            let attemptStartTime = Date()
            retryCount += 1

            logger.info("🎬 VIDEO_PREPARER: 🔄 Attempt #\(retryCount) of \(maxRetries) [\(correlationId)]")
            // RecoveryAttemptStart(correlationID: correlationId, attempt: retryCount, maxAttempts: maxRetries)

            // Check memory before each attempt
            memoryLogger.logMemoryState(context: "Before Retry Attempt #\(retryCount)", correlationId: correlationId, component: "VideoAssetPreparer")

            do {
                // Exponential backoff for retries
                if retryCount > 1 {
                    let delay = pow(2.0, Double(retryCount - 1))
                    logger.info("🎬 VIDEO_PREPARER: ⏳ Retry attempt #\(retryCount) after \(delay) seconds delay [\(correlationId)]")
                    await diagnosticLogger.logInfo("Applying exponential backoff delay", metadata: [
                        "correlation_id": correlationId,
                        "attempt": "\(retryCount)",
                        "delay_seconds": "\(delay)"
                    ])
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }

                logger.info("🎬 VIDEO_PREPARER: Calling VideoLoader.loadVideo() (Attempt #\(retryCount)) [\(correlationId)]")
                await diagnosticLogger.logInfo("Attempting video loader call", metadata: [
                    "correlation_id": correlationId,
                    "attempt": "\(retryCount)",
                    "loader_type": "\(type(of: videoLoader))"
                ])

                let result = try await videoLoader.loadVideo(from: item)

                let attemptDuration = Date().timeIntervalSince(attemptStartTime)
                logger.info("🎬 VIDEO_PREPARER: ✅ Video loading successful on attempt #\(retryCount) [\(correlationId)]")

                // RecoverySuccess(correlationID: correlationId, recoveryMessage: "Video loading succeeded on attempt #\(retryCount)", recoveryTime: attemptDuration)

                await diagnosticLogger.logInfo("Video loading succeeded after retry", metadata: [
                    "correlation_id": correlationId,
                    "successful_attempt": "\(retryCount)",
                    "total_attempts": "\(retryCount)",
                    "attempt_duration_ms": "\(String(format: "%.1f", attemptDuration * 1000))",
                    "result_filename": result.filename,
                    "result_photos_id": result.photosIdentifier
                ])

                // Log memory state after successful retry
                memoryLogger.logMemoryState(context: "After Successful Retry", correlationId: correlationId, component: "VideoAssetPreparer")

                await diagnosticLogger.stopTiming("retry_loading_operation")
                return result

            } catch {
                let attemptDuration = Date().timeIntervalSince(attemptStartTime)

                if Task.isCancelled {
                    logger.info("🎬 VIDEO_PREPARER: Video loading task was cancelled during retry [\(correlationId)]")
                    // ErrorHandlingStart(correlationID: correlationId, error: CancellationError(), severity: "task_cancelled")
                    throw CancellationError()
                }

                lastError = error

                // Enhanced error logging with recovery context
                logger.error("🎬 VIDEO_PREPARER: ❌ Video loading failed (Attempt #\(retryCount)) [\(correlationId)]")
                // ErrorHandlingStart(correlationID: correlationId, error: error, severity: retryCount == maxRetries ? "final_failure" : "recoverable_error")

                await diagnosticLogger.logError("Video loading attempt failed", error: error, metadata: [
                    "correlation_id": correlationId,
                    "attempt": "\(retryCount)",
                    "attempt_duration_ms": "\(String(format: "%.1f", attemptDuration * 1000))",
                    "error_type": "\(type(of: error))",
                    "error_domain": (error as NSError).domain,
                    "error_code": "\((error as NSError).code)"
                ])

                // Log memory state after error
                memoryLogger.logMemoryState(context: "After Failed Attempt #\(retryCount)", correlationId: correlationId, component: "VideoAssetPreparer")

                if retryCount < maxRetries {
                    let nextDelay = pow(2.0, Double(retryCount))
                    logger.info("🎬 VIDEO_PREPARER: ⏳ Will retry after \(nextDelay) seconds (Attempt \(retryCount) of \(maxRetries)) [\(correlationId)]")
                    await diagnosticLogger.logInfo("Scheduling next retry attempt", metadata: [
                        "correlation_id": correlationId,
                        "next_attempt": "\(retryCount + 1)",
                        "delay_seconds": "\(nextDelay)",
                        "remaining_attempts": "\(maxRetries - retryCount)"
                    ])
                }
            }
        }

        // All retries failed - comprehensive failure analysis
        await diagnosticLogger.stopTiming("retry_loading_operation")
        logger.error("🎬 VIDEO_PREPARER: ❌ Video loading retry loop completed without success [\(correlationId)]")

        if let error = lastError {
            // RecoveryFailure(correlationID: correlationId, failureMessage: "All retry attempts exhausted")

            await diagnosticLogger.logCritical("All retry attempts failed", error: error, metadata: [
                "correlation_id": correlationId,
                "total_attempts": "\(maxRetries)",
                "total_retry_duration_ms": "\(String(format: "%.1f", (operationTimings["retry_loading_operation"] ?? 0) * 1000))",
                "error_type": "\(type(of: error))",
                "error_domain": (error as NSError).domain,
                "error_code": "\((error as NSError).code)",
                "user_impact": "Video loading failed completely - user cannot proceed with this video"
            ])

            // Final memory state at failure
            memoryLogger.logMemoryError(
                message: "All retry attempts failed for video loading",
                correlationId: correlationId,
                component: "VideoAssetPreparer",
                metadata: [
                    "total_attempts": "\(maxRetries)",
                    "error_type": "\(type(of: error))",
                    "error_code": "\((error as NSError).code)"
                ]
            )

            throw error
        } else {
            // This should never happen, but we need to handle it
            let unknownError = NSError(domain: "VideoAssetPreparer", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Video loading failed for unknown reasons - no error recorded"
            ])

            await diagnosticLogger.logCritical("Unknown failure during video loading", error: unknownError, metadata: [
                "correlation_id": correlationId,
                "total_attempts": "\(maxRetries)",
                "user_impact": "Video loading failed with unknown error - user cannot proceed"
            ])

            throw unknownError
        }
    }
}