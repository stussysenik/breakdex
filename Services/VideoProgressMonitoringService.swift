import Foundation
import Combine
import OSLog

// VideoProgressMonitoringService.swift

/// Service responsible for monitoring video loading progress and managing subscriptions
/// Extracted from AddMoveUnifiedState to follow Single Responsibility Principle
@MainActor
public class VideoProgressMonitoringService {

    // MARK: - Properties

    private let logger = Logger(subsystem: "BreakingFlashcards", category: "🎬 VIDEO_PROGRESS")
    private let modernVideoLoadingService: ModernVideoLoadingServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var progressMonitoringTask: Task<Void, Never>?

    // MARK: - Callbacks

    /// Callback for progress updates
    public var onProgressUpdate: ((VideoLoadingProgress) -> Void)?
    /// Callback for completion events
    public var onCompletion: ((Subscribers.Completion<Never>) -> Void)?

    // MARK: - Initialization

    @MainActor
    public init(modernVideoLoadingService: ModernVideoLoadingServiceProtocol) {
        self.modernVideoLoadingService = modernVideoLoadingService
        // logger.info("🎬 VIDEO_PROGRESS: ✅ Service initialized")
    }

    // MARK: - Public Methods
    // MARK: - FUNC
    /// Starts monitoring video loading progress
    public func startMonitoring() {
        // logger.info("🎬 VIDEO_PROGRESS: ⚙️ Setting up progress subscription")

        // MARK: - CRITICAL FIX: Validate callback setup before starting
        if onProgressUpdate == nil {
            logger.error("🎬 VIDEO_PROGRESS: ❌ Progress update callback not set - monitoring will not work")
            return
        }

        // Cancel any existing monitoring task
        progressMonitoringTask?.cancel()
        cancellables.removeAll()

        // MARK: - STRATEGIC FIX: Enhanced publisher setup with validation
        // logger.info("🎬 VIDEO_PROGRESS: 📡 Creating publisher from video loading service")

        let publisher: AnyPublisher<VideoLoadingProgress, Never> = modernVideoLoadingService.progressPublisher
            .receive(on: DispatchQueue.main)
            .handleEvents(
                receiveSubscription: { [weak self] subscription in
                    self?.logger.info("🎬 VIDEO_PROGRESS: ✅ Subscription received from video loading service")
                },
                receiveCancel: { [weak self] in
                    self?.logger.warning("🎬 VIDEO_PROGRESS: ⚠️ Subscription cancelled")
                },
                receiveRequest: { [weak self] demand in
                    self?.logger.info("🎬 VIDEO_PROGRESS:  Demand requested: \(demand)")
                }
            )
            .eraseToAnyPublisher()

        // MARK: - CRITICAL FIX: Enhanced subscription setup with error handling
        let subscription = publisher.sink(
            receiveCompletion: { [weak self] completion in
                self?.handleCompletion(completion)
            },
            receiveValue: { [weak self] progress in
                self?.handleProgressUpdate(progress)
            }
        )

        // Add subscription to cancellables
        self.cancellables.insert(subscription)
        // logger.info("🎬 VIDEO_PROGRESS: ✅ Progress monitoring started successfully | subscription count: \(self.cancellables.count)")

        // MARK: - STRATEGIC FIX: Log service state for diagnostics
        logServiceState()
        logMemoryUsage()
    }
    // MARK: - FUNC
    /// Stops monitoring video loading progress
    public func stopMonitoring() {
        // logger.info("🎬 VIDEO_PROGRESS: 🛑 Stopping progress monitoring")

        progressMonitoringTask?.cancel()
        progressMonitoringTask = nil
        cancellables.removeAll()

        // logger.info("🎬 VIDEO_PROGRESS: ✅ Progress monitoring stopped")
    }

    // MARK: - Private Methods
    // MARK: - FUNC
    private func handleCompletion(_ completion: Subscribers.Completion<Never>) {
        // logger.info("🎬 VIDEO_PROGRESS: 🔄 COMPLETION HANDLER TRIGGERED")
        // logger.info("🎬 VIDEO_PROGRESS:  Completion type: \((completion == .finished) ? "finished" : "failure")")
        // logger.info("🎬 VIDEO_PROGRESS:  Callback configured: \(self.onCompletion != nil)")

        switch completion {
        case .finished:
            // logger.info("🎬 VIDEO_PROGRESS: ✅ Progress monitoring completed successfully")
            // logger.info("🎬 VIDEO_PROGRESS: 🚀 Triggering completion callback for atomic transformation")

            // MARK: - ENHANCED DIAGNOSTIC: Log completion callback state
            if let completionCallback = self.onCompletion {
                // logger.info("🎬 VIDEO_PROGRESS: 📡 Executing completion callback")
                completionCallback(completion)
                // logger.info("🎬 VIDEO_PROGRESS: ✅ Completion callback executed")
            } else {
                logger.warning("🎬 VIDEO_PROGRESS: ⚠️ No completion callback configured")
            }

            // MARK: - CRITICAL DIAGNOSTIC: Also trigger a final completion progress update if needed
            if let progressCallback = self.onProgressUpdate {
                // logger.info("🎬 VIDEO_PROGRESS:  Sending final completion progress update at creatingAsset phase")
                let finalProgress = VideoLoadingProgress(phase: .creatingAsset, correlationId: "completion_\(UUID().uuidString)")
                progressCallback(finalProgress)
                // logger.info("🎬 VIDEO_PROGRESS: ✅ Final completion progress update sent")
            } else {
                logger.warning("🎬 VIDEO_PROGRESS: ⚠️ No progress callback configured for final update")
            }

        case .failure(let error):
            logger.error("🎬 VIDEO_PROGRESS: ❌ Progress monitoring failed: \(error.localizedDescription)")
            if let completionCallback = self.onCompletion {
                completionCallback(completion)
            } else {
                logger.warning("🎬 VIDEO_PROGRESS: ⚠️ No completion callback configured for error")
            }
        }

        // MARK: - DIAGNOSTIC: Log final state
        // logger.info("🎬 VIDEO_PROGRESS: 📈 Final state after completion handling")
        // logger.info("🎬 VIDEO_PROGRESS:   - Progress callback: \(self.onProgressUpdate != nil)")
        // logger.info("🎬 VIDEO_PROGRESS:   - Completion callback: \(self.onCompletion != nil)")
        // logger.info("🎬 VIDEO_PROGRESS:   - Active subscriptions: \(self.cancellables.count)")
    }
    // MARK: - FUNC
    private func handleProgressUpdate(_ progress: VideoLoadingProgress) {
        let timestamp = Date()
        // logger.info("🎬 VIDEO_PROGRESS:  Received progress update: \(String(describing: progress.phase)) | timestamp: \(timestamp)")

        // Forward progress to callback
        onProgressUpdate?(progress)

        logger.debug("🎬 VIDEO_PROGRESS: ✅ Progress update forwarded to callback")
    }
    // MARK: - FUNC
    private func logMemoryUsage() {
        let memoryUsage = ProcessInfo.processInfo.physicalMemory
        let memoryUsed = memoryUsage / (1024 * 1024) // Convert to MB
        logger.debug("🎬 VIDEO_PROGRESS: 🧠 Memory usage after setup | available: \(String(format: "%.1f", Double(memoryUsed)))MB")
    }
    // MARK: - FUNC
    /// Log current service state for diagnostics
    private func logServiceState() {
        // logger.info("🎬 VIDEO_PROGRESS:  Service state logging:")
        // logger.info("🎬 VIDEO_PROGRESS:   - Callback configured: \(self.onProgressUpdate != nil)")
        // logger.info("🎬 VIDEO_PROGRESS:   - Completion callback: \(self.onCompletion != nil)")
        // logger.info("🎬 VIDEO_PROGRESS:   - Active subscriptions: \(self.cancellables.count)")
        // logger.info("🎬 VIDEO_PROGRESS:   - Video loading service: available")
    }

    // MARK: - Cleanup

    deinit {
        // logger.info("🎬 VIDEO_PROGRESS: 🧹 Service deallocating, cleaning up resources")
        // Clean up synchronously in deinit
        progressMonitoringTask?.cancel()
        progressMonitoringTask = nil
        cancellables.removeAll()
    }
}

// MARK: - Progress Monitoring State

/// Enum representing the current state of progress monitoring
public enum ProgressMonitoringState {
    case idle
    case monitoring(correlationId: String)
    case completed
    case failed(String)
}

// MARK: - Progress Monitoring Configuration

/// Configuration for progress monitoring behavior
public struct ProgressMonitoringConfiguration {
    public let enableLogging: Bool
    public let logMemoryUsage: Bool
    public let updateInterval: TimeInterval?

    public init(
        enableLogging: Bool = true,
        logMemoryUsage: Bool = true,
        updateInterval: TimeInterval? = nil
    ) {
        self.enableLogging = enableLogging
        self.logMemoryUsage = logMemoryUsage
        self.updateInterval = updateInterval
    }
}