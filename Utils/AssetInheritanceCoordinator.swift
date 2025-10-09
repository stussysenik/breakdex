import Foundation
import AVFoundation
import AVKit
import Combine
import OSLog

/// Advanced asset inheritance coordinator that manages seamless transformation
/// of video assets between trimming and naming views with proper state management
@MainActor
public final class AssetInheritanceCoordinator: ObservableObject {

    // MARK: - Transformation State
    public enum TransformationState {
        case idle
        case preparing(progress: Double, status: String)
        case transforming(progress: Double, status: String)
        case validating(progress: Double, status: String)
        case ready
        case error(String)
    }

    // MARK: - Published Properties
    @Published public private(set) var state: TransformationState = .idle
    @Published public private(set) var progress: Double = 0.0
    @Published public private(set) var status: String = ""
    @Published public private(set) var isAssetReady: Bool = false
    @Published public private(set) var transformedAsset: AVAsset?
    @Published public private(set) var transformedPlayerItem: AVPlayerItem?

    // MARK: - Configuration
    public struct Configuration {
        let enableOptimization: Bool          // Reuse existing assets when possible
        let enableValidation: Bool            // Validate transformation results
        let enablePerformanceLogging: Bool     // Log performance metrics
        let timeoutInterval: TimeInterval     // Maximum time for transformation

        public static let `default` = Configuration(
            enableOptimization: true,
            enableValidation: true,
            enablePerformanceLogging: true,
            timeoutInterval: 30.0
        )

        public static let fast = Configuration(
            enableOptimization: true,
            enableValidation: false,
            enablePerformanceLogging: false,
            timeoutInterval: 15.0
        )

        public static let thorough = Configuration(
            enableOptimization: false,
            enableValidation: true,
            enablePerformanceLogging: true,
            timeoutInterval: 60.0
        )
    }

    // MARK: - Performance Metrics
    public struct TransformationMetrics {
        let preparationTime: TimeInterval
        let transformationTime: TimeInterval
        let validationTime: TimeInterval
        let totalTime: TimeInterval
        let assetSizeBytes: Int64
        let memoryUsage: Double
        let cpuUsage: Double
    }

    // MARK: - Private Properties
    private let configuration: Configuration
    private let videoTransformBuilder = VideoTransformBuilder.self
    private var transformationTask: Task<AVAsset, Error>?
    private var performanceTimers: [String: TimeInterval] = [:]

    // MARK: - Enhanced Diagnostic Logging
    private let diagnosticLogger = DiagnosticLoggingHelper(category: "AssetInheritanceCoordinator")

    // MARK: - Initialization
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
        self.state = .idle

        diagnosticLogger.logInfo("🏗️ AssetInheritanceCoordinator initialized", metadata: [
            "enable_optimization": "\(configuration.enableOptimization)",
            "enable_validation": "\(configuration.enableValidation)",
            "timeout_interval": "\(configuration.timeoutInterval)"
        ])
    }

    deinit {
        Task { @MainActor in
            cancelTransformation()
            diagnosticLogger.logInfo("🗑️ AssetInheritanceCoordinator deinitialized")
        }
    }

    // MARK: - Public API

    /// Start the asset transformation process
    public func startTransformation(
        sourceAsset: AVAsset,
        trimRange: CMTimeRange,
        rotationQuarterTurns: Int,
        targetPlayerViewModel: UnifiedVideoPlayerViewModel?
    ) async throws -> AVAsset {
        diagnosticLogger.startTiming("asset_transformation")

        // Cancel any existing transformation
        cancelTransformation()

        // Reset state
        await resetState()

        let duration = try await sourceAsset.load(.duration)
        diagnosticLogger.logInfo("🚀 Starting asset transformation", metadata: [
            "source_duration": "\(duration.seconds)",
            "trim_range": "\(trimRange.start.seconds)-\(trimRange.end.seconds)",
            "rotation": "\(rotationQuarterTurns)",
            "enable_optimization": "\(configuration.enableOptimization)"
        ])

        // Check for optimization opportunities
        if configuration.enableOptimization,
           let optimizedAsset = try await checkOptimizationOpportunities(
            sourceAsset: sourceAsset,
            trimRange: trimRange,
            rotationQuarterTurns: rotationQuarterTurns
           ) {
            diagnosticLogger.logInfo("✅ Using optimized asset path")
            transformedAsset = optimizedAsset
            state = .ready
            isAssetReady = true
            return optimizedAsset
        }

        // Start full transformation process
        return try await performFullTransformation(
            sourceAsset: sourceAsset,
            trimRange: trimRange,
            rotationQuarterTurns: rotationQuarterTurns,
            targetPlayerViewModel: targetPlayerViewModel
        )
    }

    /// Get the current transformation metrics
    public func getTransformationMetrics() -> TransformationMetrics? {
        guard case .ready = state else { return nil }

        let prepTime = performanceTimers["preparation"] ?? 0.0
        let transformTime = performanceTimers["transformation"] ?? 0.0
        let validationTime = performanceTimers["validation"] ?? 0.0

        return TransformationMetrics(
            preparationTime: prepTime,
            transformationTime: transformTime,
            validationTime: validationTime,
            totalTime: prepTime + transformTime + validationTime,
            assetSizeBytes: transformedAsset?.estimatedFileSize ?? 0,
            memoryUsage: getCurrentMemoryUsage(),
            cpuUsage: getCurrentCPUUsage()
        )
    }

    /// Cancel the current transformation
    public func cancelTransformation() {
        transformationTask?.cancel()
        transformationTask = nil

        diagnosticLogger.logInfo("⏹️ Transformation cancelled")
    }

    /// Reset the coordinator state
    public func reset() async {
        await resetState()
        diagnosticLogger.logInfo("🔄 AssetInheritanceCoordinator state reset")
    }

    // MARK: - Private Implementation

    private func resetState() async {
        state = .idle
        progress = 0.0
        status = ""
        isAssetReady = false
        transformedAsset = nil
        transformedPlayerItem = nil
        performanceTimers.removeAll()
    }

    private func checkOptimizationOpportunities(
        sourceAsset: AVAsset,
        trimRange: CMTimeRange,
        rotationQuarterTurns: Int
    ) async throws -> AVAsset? {
        diagnosticLogger.startTiming("optimization_check")

        // Check if transformation is actually needed
        let needsTrimming = trimRange.start != .zero || trimRange.duration != sourceAsset.duration
        let needsRotation = rotationQuarterTurns > 0

        if !needsTrimming && !needsRotation {
            diagnosticLogger.logDebug("⚡ No transformation needed - using source asset")
            diagnosticLogger.stopTiming("optimization_check")
            return sourceAsset
        }

        // Check if we have a previously transformed asset that matches
        if let cachedAsset = transformedAsset,
           await isAssetEquivalent(cachedAsset, to: sourceAsset, with: trimRange, rotation: rotationQuarterTurns) {
            diagnosticLogger.logDebug("⚡ Using cached transformed asset")
            diagnosticLogger.stopTiming("optimization_check")
            return cachedAsset
        }

        diagnosticLogger.stopTiming("optimization_check")
        return nil
    }

    private func performFullTransformation(
        sourceAsset: AVAsset,
        trimRange: CMTimeRange,
        rotationQuarterTurns: Int,
        targetPlayerViewModel: UnifiedVideoPlayerViewModel?
    ) async throws -> AVAsset {
        transformationTask = Task<AVAsset, Error> {
            do {
                // Phase 1: Preparation
                try await prepareTransformation(sourceAsset: sourceAsset)

                // Phase 2: Transformation
                try await executeTransformation(
                    sourceAsset: sourceAsset,
                    trimRange: trimRange,
                    rotationQuarterTurns: rotationQuarterTurns
                )

                // Phase 3: Validation
                if configuration.enableValidation {
                    try await validateTransformation()
                }

                // Phase 4: Integration
                try await integrateWithPlayer(targetPlayerViewModel)

                // Complete transformation
                await completeTransformation()

                guard let finalAsset = transformedAsset else {
                    throw NSError(domain: "AssetInheritanceCoordinator", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Transformation completed but no asset was generated"
                    ])
                }

                diagnosticLogger.stopTiming("asset_transformation")
                return finalAsset

            } catch {
                await handleTransformationError(error)
                throw error
            }
        }

        return try await withTimeout(seconds: configuration.timeoutInterval) {
            try await self.transformationTask?.value ?? {
                throw NSError(domain: "AssetInheritanceCoordinator", code: -2, userInfo: [
                    NSLocalizedDescriptionKey: "Transformation task did not complete"
                ])
            }()
        }
    }

    private func prepareTransformation(sourceAsset: AVAsset) async throws {
        diagnosticLogger.startTiming("preparation")
        state = .preparing(progress: 0.0, status: "Preparing asset transformation...")

        // Validate source asset
        let duration = try await sourceAsset.load(.duration)
        guard duration.seconds > 0 else {
            throw NSError(domain: "AssetInheritanceCoordinator", code: -3, userInfo: [
                NSLocalizedDescriptionKey: "Source asset has invalid duration"
            ])
        }

        await updateProgress(0.2, status: "Validating source asset...")
        try await Task.sleep(nanoseconds: 100_000_000) // Simulate preparation work

        await updateProgress(0.5, status: "Preparing transformation pipeline...")
        try await Task.sleep(nanoseconds: 100_000_000)

        await updateProgress(0.8, status: "Finalizing preparation...")
        try await Task.sleep(nanoseconds: 100_000_000)

        await updateProgress(1.0, status: "Preparation complete!")

        diagnosticLogger.stopTiming("preparation")
        diagnosticLogger.logInfo("✅ Asset preparation completed")
    }

    private func executeTransformation(
        sourceAsset: AVAsset,
        trimRange: CMTimeRange,
        rotationQuarterTurns: Int
    ) async throws {
        diagnosticLogger.startTiming("transformation")
        state = .transforming(progress: 0.0, status: "Building video composition...")

        // Use VideoTransformBuilder to create transformed composition
        let result = try await VideoTransformBuilder.build(
            asset: sourceAsset,
            trimRange: trimRange,
            quarterTurns: rotationQuarterTurns
        )

        await updateProgress(0.3, status: "Composition built successfully...")
        try await Task.sleep(nanoseconds: 200_000_000)

        // Create transformed asset reference
        let transformedComposition = result.composition
        transformedAsset = transformedComposition

        await updateProgress(0.6, status: "Creating player item...")
        try await Task.sleep(nanoseconds: 100_000_000)

        // Create player item if needed
        let playerItem = AVPlayerItem(asset: transformedComposition)
        transformedPlayerItem = playerItem

        await updateProgress(0.9, status: "Finalizing transformation...")
        try await Task.sleep(nanoseconds: 100_000_000)

        await updateProgress(1.0, status: "Transformation complete!")

        diagnosticLogger.stopTiming("transformation")
        diagnosticLogger.logInfo("✅ Asset transformation completed", metadata: [
            "duration_seconds": "\(transformedComposition.duration.seconds)",
            "has_video_composition": "\(result.videoComposition != nil)",
            "trim_range": "\(trimRange.start.seconds)-\(trimRange.end.seconds)",
            "rotation": "\(rotationQuarterTurns)"
        ])
    }

    private func validateTransformation() async throws {
        diagnosticLogger.startTiming("validation")
        state = .validating(progress: 0.0, status: "Validating transformation result...")

        guard let asset = transformedAsset else {
            throw NSError(domain: "AssetInheritanceCoordinator", code: -4, userInfo: [
                NSLocalizedDescriptionKey: "No transformed asset available for validation"
            ])
        }

        await updateProgress(0.3, status: "Checking asset integrity...")

        // Validate asset duration
        let duration = try await asset.load(.duration)
        guard duration.seconds > 0 else {
            throw NSError(domain: "AssetInheritanceCoordinator", code: -5, userInfo: [
                NSLocalizedDescriptionKey: "Transformed asset has invalid duration"
            ])
        }

        await updateProgress(0.6, status: "Validating video tracks...")

        // Validate video tracks
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            throw NSError(domain: "AssetInheritanceCoordinator", code: -6, userInfo: [
                NSLocalizedDescriptionKey: "Transformed asset has no video tracks"
            ])
        }

        await updateProgress(0.9, status: "Completing validation...")

        await updateProgress(1.0, status: "Validation complete!")

        diagnosticLogger.stopTiming("validation")
        diagnosticLogger.logInfo("✅ Asset validation completed", metadata: [
            "duration_seconds": "\(duration.seconds)",
            "video_tracks": "\(videoTracks.count)"
        ])
    }

    private func integrateWithPlayer(_ targetPlayerViewModel: UnifiedVideoPlayerViewModel?) async throws {
        guard let playerViewModel = targetPlayerViewModel,
              let playerItem = transformedPlayerItem else {
            return
        }

        diagnosticLogger.logInfo("🔗 Integrating with player view model")

        // Replace player item with transformed asset
        try await playerViewModel.replacePlayerItemAndWaitForReady(playerItem)

        diagnosticLogger.logInfo("✅ Player integration completed")
    }

    private func completeTransformation() async {
        state = .ready
        isAssetReady = true

        // Log performance metrics if enabled
        if configuration.enablePerformanceLogging,
           let metrics = getTransformationMetrics() {
            diagnosticLogger.logInfo(" Transformation performance metrics", metadata: [
                "total_time_ms": "\(metrics.totalTime * 1000)",
                "preparation_time_ms": "\(metrics.preparationTime * 1000)",
                "transformation_time_ms": "\(metrics.transformationTime * 1000)",
                "validation_time_ms": "\(metrics.validationTime * 1000)",
                "asset_size_mb": "\(Double(metrics.assetSizeBytes) / (1024 * 1024))",
                "memory_usage_mb": "\(metrics.memoryUsage)"
            ])
        }

        diagnosticLogger.logInfo("🎉 Asset transformation pipeline completed successfully")
    }

    private func handleTransformationError(_ error: Error) async {
        let errorMessage = error.localizedDescription
        state = .error(errorMessage)
        isAssetReady = false

        diagnosticLogger.logError("Asset transformation failed", error: error, metadata: [
            "error_message": errorMessage,
            "transformation_state": "\(String(describing: state))",
            "memory_usage_mb": "\(getCurrentMemoryUsage())"
        ])
    }

    // MARK: - Helper Methods

    private func updateProgress(_ progress: Double, status: String) async {
        await MainActor.run {
            self.progress = progress
            self.status = status

            // Update state based on current phase
            switch self.state {
            case .preparing:
                self.state = .preparing(progress: progress, status: status)
            case .transforming:
                self.state = .transforming(progress: progress, status: status)
            case .validating:
                self.state = .validating(progress: progress, status: status)
            default:
                break
            }
        }
    }

    private func isAssetEquivalent(
        _ asset: AVAsset,
        to otherAsset: AVAsset,
        with trimRange: CMTimeRange,
        rotation: Int
    ) async -> Bool {
        // This is a simplified equivalence check
        // In a real implementation, you might compare asset identifiers, timestamps, etc.
        return false
    }

    private func getCurrentMemoryUsage() -> Double {
        let memoryInfo = DiagnosticLoggingHelper(category: "temp").getMemoryInfo()
        return memoryInfo.used
    }

    private func getCurrentCPUUsage() -> Double {
        // Implement CPU usage monitoring
        return 0.0  // Placeholder
    }

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async rethrows -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "AssetInheritanceCoordinator", code: -7, userInfo: [
                    NSLocalizedDescriptionKey: "Operation timed out"
                ])
            }

            for try await result in group {
                group.cancelAll()
                return result
            }

            throw NSError(domain: "AssetInheritanceCoordinator", code: -8, userInfo: [
                NSLocalizedDescriptionKey: "Task group completed without result"
            ])
        }
    }
}

// MARK: - Convenience Extensions

extension AssetInheritanceCoordinator {

    /// Create coordinator for fast operations (quick asset swaps)
    public static func forFastOperations() -> AssetInheritanceCoordinator {
        return AssetInheritanceCoordinator(configuration: .fast)
    }

    /// Create coordinator for thorough operations (quality-focused)
    public static func forThoroughOperations() -> AssetInheritanceCoordinator {
        return AssetInheritanceCoordinator(configuration: .thorough)
    }

    /// Create coordinator with default balanced configuration
    public static func forDefaultOperations() -> AssetInheritanceCoordinator {
        return AssetInheritanceCoordinator(configuration: .default)
    }
}

// MARK: - AVAsset Extension for File Size Estimation

extension AVAsset {
    var estimatedFileSize: Int64 {
        // This is a rough estimation - in a real implementation, you might
        // get the actual file size from the file system or use more sophisticated estimation
        let duration = duration.seconds
        let estimatedBitrate: Double = 5_000_000 // 5 Mbps estimation
        return Int64(duration * estimatedBitrate / 8)
    }
}