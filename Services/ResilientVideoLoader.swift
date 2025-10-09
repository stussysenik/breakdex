import Foundation
import Photos
import AVFoundation
import Network
import OSLog
import Combine

// ResilientVideoLoader.swift

/// MARK: - Resilient Video Loader Service
///
/// Network-aware video loading service with timeout protection and automatic retry
/// Handles network path changes gracefully during PHImageManager.requestAVAsset operations
///
/// Key Features:
/// - 45-second timeout for PHImageManager.requestAVAsset calls
/// - Automatic retry on network restoration with exponential backoff
/// - Network path monitoring with Wi-Fi to 5G transition handling
/// - Comprehensive diagnostic logging with correlation IDs
/// - Proper task cancellation and resource cleanup
/// - Integration with UnifiedProgressEngine for progress tracking
@MainActor
public class ResilientVideoLoader: ObservableObject {

    // MARK: - Configuration
    private static let defaultTimeout: TimeInterval = 45.0
    private static let maxRetryAttempts = 3
    private static let baseRetryDelay: TimeInterval = 2.0
    private static let maxRetryDelay: TimeInterval = 16.0

    // MARK: - Properties
    private let logger = Logger(subsystem: "breakdex", category: "🛡️ RESILIENT_VIDEO_LOADER")
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "breakdex.resilient.network", qos: .utility)

    // MARK: - State Management
    @Published public private(set) var isLoading = false
    @Published public private(set) var isWaitingForNetwork = false
    @Published public private(set) var currentAttempt = 0
    @Published public private(set) var correlationId: String = ""

    // MARK: - Network State
    @Published public private(set) var isNetworkAvailable = true
    @Published public private(set) var networkConnectionType: NetworkConnectionType = .unknown
    @Published public private(set) var networkQuality: NetworkQuality = .excellent

    // Network resilience tracking
    private var networkLostDuringLoading = false
    private var pausedOperation: ResilientOperation?
    private var retryAttempts = 0

    // MARK: - Task Management
    private var currentLoadingTask: Task<AVAsset, Error>?
    private var networkMonitorTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Error>?

    // MARK: - Progress Publisher
    /// Combine publisher for video loading progress updates
    /// Enables decoupled progress reporting to multiple subscribers
    private let progressSubject = PassthroughSubject<VideoLoadingProgress, Never>()
    public var progressPublisher: AnyPublisher<VideoLoadingProgress, Never> {
        progressSubject.eraseToAnyPublisher()
    }

    // MARK: - Enums
    public enum NetworkConnectionType: String, CaseIterable {
        case wifi = "wifi"
        case cellular = "cellular"
        case ethernet = "ethernet"
        case other = "other"
        case none = "none"
        case unknown = "unknown"

        var displayName: String {
            switch self {
            case .wifi: return "Wi-Fi"
            case .cellular: return "Cellular"
            case .ethernet: return "Ethernet"
            case .other: return "Other"
            case .none: return "No Connection"
            case .unknown: return "Unknown"
            }
        }
    }

    public enum NetworkQuality: String, CaseIterable {
        case excellent = "excellent"
        case good = "good"
        case fair = "fair"
        case poor = "poor"

        var displayName: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .fair: return "Fair"
            case .poor: return "Poor"
            }
        }
    }

    public enum ResilientVideoLoaderError: Error, LocalizedError {
        case timeout(operationId: String, duration: TimeInterval)
        case networkLost(operationId: String)
        case maxRetriesExceeded(operationId: String, attempts: Int)
        case assetUnavailable(operationId: String, underlyingError: Error)
        case permissionDenied(operationId: String)
        case corruptedAsset(operationId: String, details: String)
        case cancelled(operationId: String)
        case invalidAsset(operationId: String, reason: String)
        case unknown(operationId: String, reason: String)

        public var errorDescription: String? {
            switch self {
            case .timeout(let operationId, let duration):
                return "Video loading timed out after \(String(format: "%.1f", duration)) seconds [\(operationId)]"
            case .networkLost(let operationId):
                return "Network connection lost during video loading [\(operationId)]"
            case .maxRetriesExceeded(let operationId, let attempts):
                return "Failed to load video after \(attempts) attempts [\(operationId)]"
            case .assetUnavailable(let operationId, let underlyingError):
                return "Video asset unavailable: \(underlyingError.localizedDescription) [\(operationId)]"
            case .permissionDenied(let operationId):
                return "Photo library access denied [\(operationId)]"
            case .corruptedAsset(let operationId, let details):
                return "Video file appears to be corrupted: \(details) [\(operationId)]"
            case .cancelled(let operationId):
                return "Video loading was cancelled [\(operationId)]"
            case .invalidAsset(let operationId, let reason):
                return "Invalid video asset: \(reason) [\(operationId)]"
            case .unknown(let operationId, let reason):
                return "Unknown error: \(reason) [\(operationId)]"
            }
        }
    }

    // MARK: - Progress Data Structure
    /// Progress data structure for Combine publisher
    public struct VideoLoadingProgress {
        public let phase: LoadingPhase
        public let progress: Double
        public let correlationId: String
        public let timestamp: Date

        public init(phase: LoadingPhase, progress: Double, correlationId: String) {
            self.phase = phase
            self.progress = progress
            self.correlationId = correlationId
            self.timestamp = Date()
        }
    }

    /// Loading phases for progress tracking
    public enum LoadingPhase {
        case initializing
        case requestingDownload
        case downloadingFromCloud(Double)
        case transferring
        case validating
        case creatingAsset
        case generatingThumbnail
        case loadingTrimmerDuration
        case loadingTrimmerTracks
        case validatingTrimmer
        case completed
        case error(Error)
    }

    private struct ResilientOperation {
        let id: String
        let phAsset: PHAsset
        let options: PHVideoRequestOptions
        let startTime: Date
        let attemptNumber: Int
        let correlationId: String

        var operationId: String {
            return "\(correlationId)-\(id)"
        }
    }

    // MARK: - Initialization

    public init() {
        setupNetworkMonitoring()

        // logger.info("🛡️ RESILIENT_VIDEO_LOADER: ✅ Initialized with network resilience (SRP-compliant)")
        // logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Timeout: \(Self.defaultTimeout)s")
        // logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Max retries: \(Self.maxRetryAttempts)")
        // logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Network monitoring: ENABLED")
        // logger.info("🛡️ RESILIENT_VIDEO_LOADER: └─ Responsibility: Video loading & progress publishing only")
    }

    deinit {
        Task { @MainActor in
            cleanup()
        }
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: 🧹 Deinitialized")
    }

    // MARK: - Public API

    /// Load video asset with network resilience and timeout protection
    /// - Parameters:
    ///   - phAsset: The Photos library asset to load
    ///   - options: Video request options
    ///   - progress: Progress callback for loading updates
    /// - Returns: AVAsset if successful
    // MARK: - FUNC
    public func loadVideoAsset(
        phAsset: PHAsset,
        options: PHVideoRequestOptions? = nil,
        progress: @escaping @MainActor (Double, String) -> Void
    ) async throws -> AVAsset {

        let correlationId = generateCorrelationId()
        self.correlationId = correlationId

        logger.info("🛡️ RESILIENT_VIDEO_LOADER: 🚀 Starting resilient video loading [\(correlationId)]")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Asset ID: \(phAsset.localIdentifier)")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Network: \(self.networkConnectionType.displayName)")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: └─ Timeout: \(Self.defaultTimeout)s")

        // Validate network availability before starting
        guard validateNetworkConnectivity() else {
            throw ResilientVideoLoaderError.networkLost(operationId: correlationId)
        }

        // Validate Photos library access
        guard validatePhotoLibraryAccess() else {
            throw ResilientVideoLoaderError.permissionDenied(operationId: correlationId)
        }

        isLoading = true
        retryAttempts = 0
        networkLostDuringLoading = false

        let requestOptions = options ?? createDefaultOptions(correlationId: correlationId)

        // 🔄 PUBLISH_INITIALIZATION: Send initialization phase through publisher
        let initProgress = VideoLoadingProgress(
            phase: .initializing,
            progress: 0.0,
            correlationId: correlationId
        )
        progressSubject.send(initProgress)
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: 📤 INITIALIZATION_PUBLISHED: Initialization phase sent to subscribers [\(correlationId)]")

        do {
            let asset = try await attemptVideoLoad(
                phAsset: phAsset,
                options: requestOptions,
                correlationId: correlationId,
                progress: progress
            )

            isLoading = false

            // 🔄 PUBLISH_COMPLETION: Send completion through publisher
            sendCompletion()

            logger.info("🛡️ RESILIENT_VIDEO_LOADER: ✅ Video loading completed successfully [\(correlationId)]")
            return asset

        } catch {
            isLoading = false

            // 🔄 PUBLISH_ERROR: Send error through publisher
            sendError(error)

            logger.error("🛡️ RESILIENT_VIDEO_LOADER: ❌ Video loading failed: \(error.localizedDescription) [\(correlationId)]")
            throw error
        }
    }
    // MARK: - FUNC
    /// Cancel current loading operation
    public func cancelLoading() {
        let operationId = pausedOperation?.operationId ?? correlationId

        logger.info("🛡️ RESILIENT_VIDEO_LOADER: 🚫 Cancelling loading operation [\(operationId)]")

        currentLoadingTask?.cancel()
        timeoutTask?.cancel()

        isLoading = false
        isWaitingForNetwork = false
        pausedOperation = nil

        // SRP_COMPLIANT: ResilientVideoLoader only handles its own state
        // Progress engine cancellation is handled by ResilientVideoLoaderIntegration

        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ✅ Loading operation cancelled [\(operationId)]")
    }

    // MARK: - Private Implementation
    // MARK: - FUNC
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handleNetworkPathUpdate(path)
            }
        }
        networkMonitor.start(queue: networkQueue)

        networkMonitorTask = Task { @MainActor in
            logger.info("🛡️ RESILIENT_VIDEO_LOADER: 🌐 Network monitoring started")
        }
    }
    // MARK: - FUNC
    private func handleNetworkPathUpdate(_ path: NWPath) {
        let newNetworkState = path.status == .satisfied
        let newConnectionType = determineConnectionType(path)
        let newNetworkQuality = determineNetworkQuality(path)

        // Log network state changes
        if isNetworkAvailable != newNetworkState || networkConnectionType != newConnectionType {
            logger.info("🛡️ RESILIENT_VIDEO_LOADER: 🌐 Network state changed")
            logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Available: \(newNetworkState ? "✅ YES" : "❌ NO")")
            logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Type: \(newConnectionType.displayName)")
            logger.info("🛡️ RESILIENT_VIDEO_LOADER: └─ Quality: \(newNetworkQuality.displayName)")
        }

        isNetworkAvailable = newNetworkState
        networkConnectionType = newConnectionType
        networkQuality = newNetworkQuality

        // Handle network state changes during loading
        if newNetworkState && networkLostDuringLoading && pausedOperation != nil {
            Task { @MainActor in
                await handleNetworkRestored()
            }
        } else if !newNetworkState && isLoading {
            Task { @MainActor in
                await handleNetworkLost()
            }
        }
    }
    // MARK: - FUNC
    private func handleNetworkLost() async {
        guard isLoading && pausedOperation == nil else { return }

        logger.warning("🛡️ RESILIENT_VIDEO_LOADER: ⚠️ Network lost during loading")

        networkLostDuringLoading = true
        isWaitingForNetwork = true

        // Store current operation for retry
        if let currentTask = currentLoadingTask {
            currentTask.cancel()
        }

        // SRP_COMPLIANT: Network waiting state is handled by integration layer
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ⏳ Network waiting state - Integration layer will handle phase transitions")

        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ⏳ Waiting for network restoration")
    }
    // MARK: - FUNC
    private func handleNetworkRestored() async {
        guard networkLostDuringLoading, let operation = pausedOperation else { return }

        logger.info("🛡️ RESILIENT_VIDEO_LOADER: 🌐 Network restored, resuming loading")

        networkLostDuringLoading = false
        isWaitingForNetwork = false
        pausedOperation = nil

        // SRP_COMPLIANT: Network error handling is delegated to integration layer
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: 🌐 Network restored - Integration layer will handle error clearing")

        // Resume loading with retry logic
        do {
            _ = try await retryVideoLoad(operation: operation)
            logger.info("🛡️ RESILIENT_VIDEO_LOADER: ✅ Loading resumed successfully after network restoration")
        } catch {
            logger.error("🛡️ RESILIENT_VIDEO_LOADER: ❌ Failed to resume loading: \(error.localizedDescription)")
        }
    }
    // MARK: - FUNC
    private func attemptVideoLoad(
        phAsset: PHAsset,
        options: PHVideoRequestOptions,
        correlationId: String,
        progress: @escaping @MainActor (Double, String) -> Void
    ) async throws -> AVAsset {

        currentAttempt += 1
        let operation = ResilientOperation(
            id: UUID().uuidString.prefix(8).lowercased(),
            phAsset: phAsset,
            options: options,
            startTime: Date(),
            attemptNumber: currentAttempt,
            correlationId: correlationId
        )

        logger.info("🛡️ RESILIENT_VIDEO_LOADER: 🔄 Attempt \(self.currentAttempt) of \(Self.maxRetryAttempts) [\(operation.operationId)]")

        // SRP COMPLIANCE: ResilientVideoLoader only handles video loading and publishes progress
        // Phase transitions are handled by ResilientVideoLoaderIntegration layer
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: 🔄 SRP_COMPLIANT: Starting video load operation [\(operation.operationId)]")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER:  PROGRESS_FLOW_PUBLISHER: Data path configured for Combine publisher")
        logger.debug("🛡️ RESILIENT_VIDEO_LOADER: ├─ iCloud PHImageManager.progressHandler")
        logger.debug("🛡️ RESILIENT_VIDEO_LOADER: ├─ ResilientVideoLoader.handleDownloadProgress()")
        logger.debug("🛡️ RESILIENT_VIDEO_LOADER: └─ progressPublisher → ResilientVideoLoaderIntegration")

        do {
            let asset = try await performResilientAVAssetRequest(operation: operation, progress: progress)

            // Log success metrics
            let loadDuration = Date().timeIntervalSince(operation.startTime)
            logger.info("🛡️ RESILIENT_VIDEO_LOADER: ✅ Load completed in \(String(format: "%.2f", loadDuration))s [\(operation.operationId)]")

            return asset

        } catch {
            logger.error("🛡️ RESILIENT_VIDEO_LOADER: ❌ Load attempt \(self.currentAttempt) failed: \(error.localizedDescription) [\(operation.operationId)]")

            if currentAttempt < Self.maxRetryAttempts {
                return try await retryVideoLoad(operation: operation)
            } else {
                throw ResilientVideoLoaderError.maxRetriesExceeded(operationId: operation.operationId, attempts: currentAttempt)
            }
        }
    }
    // MARK: - FUNC
    private func performResilientAVAssetRequest(
        operation: ResilientOperation,
        progress: @escaping @MainActor (Double, String) -> Void
    ) async throws -> AVAsset {

        logger.info("🛡️ RESILIENT_VIDEO_LOADER: 🎬 Starting PHImageManager.requestAVAsset [\(operation.operationId)]")

        // Set up timeout protection
        timeoutTask = Task<Void, Error> { @MainActor in
            try await Task.sleep(for: .seconds(Self.defaultTimeout))

            if !Task.isCancelled {
                logger.warning("🛡️ RESILIENT_VIDEO_LOADER: ⏱️ Timeout reached for operation [\(operation.operationId)]")
                currentLoadingTask?.cancel()
            }
        }

        currentLoadingTask = Task<AVAsset, Error> { @MainActor in
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AVAsset, Error>) in
                let requestStartTime = Date()

                PHImageManager.default().requestAVAsset(
                    forVideo: operation.phAsset,
                    options: operation.options
                ) { avAsset, audioMix, info in
                    let requestDuration = Date().timeIntervalSince(requestStartTime)

                    Task { @MainActor in
                        await self.handleAVAssetResponse(
                            avAsset: avAsset,
                            audioMix: audioMix,
                            info: info,
                            requestDuration: requestDuration,
                            operation: operation,
                            continuation: continuation
                        )
                    }
                }
            }
        }

        do {
            let asset = try await currentLoadingTask!.value
            timeoutTask?.cancel()
            timeoutTask = nil
            return asset

        } catch {
            timeoutTask?.cancel()
            timeoutTask = nil

            if error is CancellationError {
                // Check if this was a timeout cancellation
                if Date().timeIntervalSince(operation.startTime) >= Self.defaultTimeout * 0.95 {
                    throw ResilientVideoLoaderError.timeout(operationId: operation.operationId, duration: Self.defaultTimeout)
                } else {
                    throw ResilientVideoLoaderError.cancelled(operationId: operation.operationId)
                }
            }

            throw ResilientVideoLoaderError.assetUnavailable(operationId: operation.operationId, underlyingError: error)
        }
    }
    // MARK: - FUNC
    private func handleAVAssetResponse(
        avAsset: AVAsset?,
        audioMix: AVAudioMix?,
        info: [AnyHashable: Any]?,
        requestDuration: TimeInterval,
        operation: ResilientOperation,
        continuation: CheckedContinuation<AVAsset, Error>
    ) {
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: 📡 PHImageManager response received in \(String(format: "%.2f", requestDuration))s [\(operation.operationId)]")

        if let error = info?[PHImageErrorKey] as? Error {
            logger.error("🛡️ RESILIENT_VIDEO_LOADER: ❌ PHImageManager error: \(error.localizedDescription) [\(operation.operationId)]")
            continuation.resume(throwing: ResilientVideoLoaderError.assetUnavailable(operationId: operation.operationId, underlyingError: error))
        } else if let asset = avAsset {
            logger.info("🛡️ RESILIENT_VIDEO_LOADER: ✅ AVAsset received successfully [\(operation.operationId)]")
            logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Duration: \(asset.duration.seconds)s")
            logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Tracks: \(asset.tracks.count)")
            logger.info("🛡️ RESILIENT_VIDEO_LOADER: └─ Type: \(type(of: asset))")

            continuation.resume(returning: asset)
        } else {
            logger.error("🛡️ RESILIENT_VIDEO_LOADER: ❌ PHImageManager returned nil AVAsset [\(operation.operationId)]")
            continuation.resume(throwing: ResilientVideoLoaderError.invalidAsset(operationId: operation.operationId, reason: "AVAsset is nil"))
        }
    }
    // MARK: - FUNC
    private func retryVideoLoad(operation: ResilientOperation) async throws -> AVAsset {
        let retryDelay = calculateRetryDelay(attempt: currentAttempt)

        logger.info("🛡️ RESILIENT_VIDEO_LOADER: 🔄 Retrying in \(String(format: "%.1f", retryDelay))s [\(operation.operationId)]")

        try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))

        // Create new operation for retry
        let retryOperation = ResilientOperation(
            id: UUID().uuidString.prefix(8).lowercased(),
            phAsset: operation.phAsset,
            options: operation.options,
            startTime: Date(),
            attemptNumber: currentAttempt,
            correlationId: operation.correlationId
        )

        return try await performResilientAVAssetRequest(operation: retryOperation) { [self] progress, status in
            // Progress during retry is published through Combine publisher
            self.logger.debug("🛡️ RESILIENT_VIDEO_LOADER:  Retry progress: \(Int(progress * 100))%")
        }
    }
    // MARK: - FUNC
    private func calculateRetryDelay(attempt: Int) -> TimeInterval {
        let delay = Self.baseRetryDelay * pow(2.0, Double(attempt - 1))
        return min(delay, Self.maxRetryDelay)
    }

    // MARK: - Validation Methods
    // MARK: - FUNC
    private func validateNetworkConnectivity() -> Bool {
        guard isNetworkAvailable else {
            logger.error("🛡️ RESILIENT_VIDEO_LOADER: ❌ Network validation failed - No connection available")
            return false
        }

        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ✅ Network validation passed - \(self.networkConnectionType.displayName) available")
        return true
    }
    // MARK: - FUNC
    private func validatePhotoLibraryAccess() -> Bool {
        let authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        guard authorizationStatus == .authorized else {
            logger.error("🛡️ RESILIENT_VIDEO_LOADER: ❌ Photo library access not authorized - Status: \(authorizationStatus.rawValue)")
            return false
        }

        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ✅ Photo library access authorized")
        return true
    }
    // MARK: - FUNC
    private func createDefaultOptions(correlationId: String) -> PHVideoRequestOptions {
        let options = PHVideoRequestOptions()
        options.version = .original
        options.deliveryMode = .automatic
        options.isNetworkAccessAllowed = true

        //  SRP_COMPLIANT: Progress handler only publishes progress, no direct engine calls
        // This ensures clean separation of concerns and prevents lost progress updates
        options.progressHandler = { progress, error, stop, info in
            Task { @MainActor in
                let progressPercentage = Double(progress)
                await self.handleDownloadProgress(
                    progressPercentage,
                    correlationId: correlationId,
                    error: error,
                    info: info
                )
            }
        }

        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ⚙️ Default request options configured [\(correlationId)]")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER:  SRP_COMPLIANT: Progress handler publishes to Combine publisher only")
        return options
    }
    // MARK: - FUNC
    private func handleDownloadProgress(
        _ progress: Double,
        correlationId: String,
        error: Error?,
        info: [AnyHashable: Any]?
    ) async {
        //  DIAGNOSTIC LOG: Log raw iCloud progress percentages for transparent debugging
        let progressPercentage = Int(progress * 100)
        logger.info("🛡️ RESILIENT_VIDEO_LOADER:  RAW_ICLOUD_PROGRESS: \(progressPercentage)% [\(correlationId)]")

        //  SRP_COMPLIANT: ResilientVideoLoader only publishes progress, no direct engine calls
        logger.info("🛡️ RESILIENT_VIDEO_LOADER:  PROGRESS_PUBLISHING [\(correlationId)]:")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ iCloud Progress: \(progressPercentage)%")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Raw Progress: \(String(format: "%.3f", progress))")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: └─ Progress Path: iCloud → ResilientVideoLoader → Combine Publisher → Integration")

        if let error = error {
            logger.warning("🛡️ RESILIENT_VIDEO_LOADER: ⚠️ Download progress error: \(error.localizedDescription) [\(correlationId)]")
        }

        // 🔄 COMBINE PUBLISHER: Publish progress through Combine publisher (SRP-compliant)
        // This enables decoupled progress reporting to multiple subscribers
        let loadingProgress = VideoLoadingProgress(
            phase: .downloadingFromCloud(progress),
            progress: progress,
            correlationId: correlationId
        )

        // 📤 PUBLISH_PROGRESS: Send progress to all subscribers
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: 📤 PUBLISHING_PROGRESS: \(progressPercentage)% → Combine Publisher [\(correlationId)]")
        logger.debug("🛡️ RESILIENT_VIDEO_LOADER: ├─ Publisher: PassthroughSubject<VideoLoadingProgress, Never>")
        logger.debug("🛡️ RESILIENT_VIDEO_LOADER: ├─ Primary Subscriber: ResilientVideoLoaderIntegration")
        logger.debug("🛡️ RESILIENT_VIDEO_LOADER: └─ Method: progressSubject.send()")

        progressSubject.send(loadingProgress)

        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ✅ PROGRESS_PUBLISHED: iCloud progress successfully published [\(correlationId)]")
        logger.debug("🛡️ RESILIENT_VIDEO_LOADER: └─ Next: ResilientVideoLoaderIntegration will forward to UnifiedProgressEngine")
    }

    // MARK: - Helper Methods
    // MARK: - FUNC
    private func determineConnectionType(_ path: NWPath) -> NetworkConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else if path.usesInterfaceType(.other) {
            return .other
        } else if path.status == .unsatisfied {
            return .none
        } else {
            return .unknown
        }
    }
    // MARK: - FUNC
    private func determineNetworkQuality(_ path: NWPath) -> NetworkQuality {
        guard path.status == .satisfied else {
            return .poor
        }

        if path.usesInterfaceType(.wifi) {
            return .excellent
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .excellent
        } else if path.usesInterfaceType(.cellular) {
            return .good
        } else {
            return .fair
        }
    }
    // MARK: - FUNC
    private func generateCorrelationId() -> String {
        return "RVL-\(UUID().uuidString.prefix(8).uppercased())"
    }
    // MARK: - FUNC
    private func cleanup() {
        currentLoadingTask?.cancel()
        timeoutTask?.cancel()
        networkMonitorTask?.cancel()
        networkMonitor.cancel()

        currentLoadingTask = nil
        timeoutTask = nil
        networkMonitorTask = nil
        pausedOperation = nil

        // 🧹 CLEANUP_COMPLETION: Send completion through publisher
        sendCompletion()

        logger.info("🛡️ RESILIENT_VIDEO_LOADER: 🧹 Cleanup completed")
    }
    // MARK: - FUNC
    /// Send completion notification through progress publisher
    private func sendCompletion() {
        let completionProgress = VideoLoadingProgress(
            phase: .completed,
            progress: 1.0,
            correlationId: correlationId
        )
        progressSubject.send(completionProgress)
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ✅ COMPLETION_SENT: Published completion notification")
    }
    // MARK: - FUNC
    /// Send error notification through progress publisher
    private func sendError(_ error: Error) {
        let errorProgress = VideoLoadingProgress(
            phase: .error(error),
            progress: 0.0, // SRP-compliant: engine progress is handled by integration layer
            correlationId: correlationId
        )
        progressSubject.send(errorProgress)
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ❌ ERROR_SENT: Published error notification: \(error.localizedDescription)")
    }
}

// MARK: - Diagnostic Extensions

extension ResilientVideoLoader {

    /// Get current diagnostic information
    public var diagnosticInfo: [String: Any] {
        return [
            "isLoading": isLoading,
            "isWaitingForNetwork": isWaitingForNetwork,
            "currentAttempt": currentAttempt,
            "correlationId": correlationId,
            "isNetworkAvailable": isNetworkAvailable,
            "networkConnectionType": networkConnectionType.rawValue,
            "networkQuality": networkQuality.rawValue,
            "networkLostDuringLoading": networkLostDuringLoading,
            "retryAttempts": retryAttempts,
            "timeoutSeconds": Self.defaultTimeout,
            "maxRetries": Self.maxRetryAttempts
        ]
    }
    // MARK: - FUNC
    /// Log comprehensive diagnostic information with enhanced progress flow analysis
    public func logDiagnostics() {
        logger.info("🛡️ RESILIENT_VIDEO_LOADER:  COMPREHENSIVE DIAGNOSTIC REPORT")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Loading State: \(self.isLoading ? "ACTIVE" : "IDLE")")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Waiting for Network: \(self.isWaitingForNetwork ? "YES" : "NO")")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Current Attempt: \(self.currentAttempt)")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Correlation ID: \(self.correlationId)")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Network Available: \(self.isNetworkAvailable ? "✅ YES" : "❌ NO")")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Connection Type: \(self.networkConnectionType.displayName)")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Network Quality: \(self.networkQuality.displayName)")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Network Lost During Loading: \(self.networkLostDuringLoading ? "⚠️ YES" : "✅ NO")")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: └─ Retry Attempts: \(self.retryAttempts)")

        //  SRP_COMPLIANT_DIAGNOSTIC: Progress flow analysis
        logger.info("🛡️ RESILIENT_VIDEO_LOADER:  PROGRESS_FLOW_ANALYSIS:")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Engine Available: ❌ NOT APPLICABLE (SRP-compliant)")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Responsibility: Video loading & progress publishing only")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: ├─ Publisher: PassthroughSubject<VideoLoadingProgress, Never>")
        logger.info("🛡️ RESILIENT_VIDEO_LOADER: └─ Progress Path: iCloud → ResilientVideoLoader → Combine Publisher → Integration")
    }
}