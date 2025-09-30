//
//  VideoProgressMonitoringService.swift
//  BreakingFlashcards
//
//  Created by Claude Code on 9/28/25.
//

import Foundation
import Combine
import OSLog

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
        logger.info("🎬 VIDEO_PROGRESS: ✅ Service initialized")
    }

    // MARK: - Public Methods

    /// Starts monitoring video loading progress
    public func startMonitoring() {
        logger.info("🎬 VIDEO_PROGRESS: ⚙️ Setting up progress subscription")

        // 🎯 CRITICAL FIX: Validate callback setup before starting
        if onProgressUpdate == nil {
            logger.error("🎬 VIDEO_PROGRESS: ❌ Progress update callback not set - monitoring will not work")
            return
        }

        // Cancel any existing monitoring task
        progressMonitoringTask?.cancel()
        cancellables.removeAll()

        // 🎯 STRATEGIC FIX: Enhanced publisher setup with validation
        logger.info("🎬 VIDEO_PROGRESS: 📡 Creating publisher from video loading service")

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
                    self?.logger.info("🎬 VIDEO_PROGRESS: 📊 Demand requested: \(demand)")
                }
            )
            .eraseToAnyPublisher()

        // 🎯 CRITICAL FIX: Enhanced subscription setup with error handling
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
        logger.info("🎬 VIDEO_PROGRESS: ✅ Progress monitoring started successfully | subscription count: \(self.cancellables.count)")

        // 🎯 STRATEGIC FIX: Log service state for diagnostics
        logServiceState()
        logMemoryUsage()
    }

    /// Stops monitoring video loading progress
    public func stopMonitoring() {
        logger.info("🎬 VIDEO_PROGRESS: 🛑 Stopping progress monitoring")

        progressMonitoringTask?.cancel()
        progressMonitoringTask = nil
        cancellables.removeAll()

        logger.info("🎬 VIDEO_PROGRESS: ✅ Progress monitoring stopped")
    }

    // MARK: - Private Methods

    private func handleCompletion(_ completion: Subscribers.Completion<Never>) {
        switch completion {
        case .finished:
            logger.info("🎬 VIDEO_PROGRESS: ✅ Progress monitoring completed successfully")
            logger.info("🎬 VIDEO_PROGRESS: 🚀 Triggering completion callback for natural transformation")

            // 🎯 CRITICAL FIX: Ensure completion callback is called immediately
            // This is essential for the loading → previewing natural transformation
            onCompletion?(completion)

            // 🎯 ENHANCEMENT: Also trigger a final completion progress update if needed
            // This provides redundancy to ensure the natural transformation executes
            if onProgressUpdate != nil {
                logger.info("🎬 VIDEO_PROGRESS: 📊 Sending final completion progress update at creatingAsset phase")
                let finalProgress = VideoLoadingProgress(phase: .creatingAsset, correlationId: "completion")
                onProgressUpdate?(finalProgress)
            }

        case .failure(let error):
            logger.error("🎬 VIDEO_PROGRESS: ❌ Progress monitoring failed: \(error.localizedDescription)")
            onCompletion?(completion)
        }
    }

    private func handleProgressUpdate(_ progress: VideoLoadingProgress) {
        let timestamp = Date()
        logger.info("🎬 VIDEO_PROGRESS: 📊 Received progress update: \(String(describing: progress.phase)) | timestamp: \(timestamp)")

        // Forward progress to callback
        onProgressUpdate?(progress)

        logger.debug("🎬 VIDEO_PROGRESS: ✅ Progress update forwarded to callback")
    }

    private func logMemoryUsage() {
        let memoryUsage = ProcessInfo.processInfo.physicalMemory
        let memoryUsed = memoryUsage / (1024 * 1024) // Convert to MB
        logger.debug("🎬 VIDEO_PROGRESS: 🧠 Memory usage after setup | available: \(String(format: "%.1f", Double(memoryUsed)))MB")
    }

    /// Log current service state for diagnostics
    private func logServiceState() {
        logger.info("🎬 VIDEO_PROGRESS: 📊 Service state logging:")
        logger.info("🎬 VIDEO_PROGRESS:   - Callback configured: \(self.onProgressUpdate != nil)")
        logger.info("🎬 VIDEO_PROGRESS:   - Completion callback: \(self.onCompletion != nil)")
        logger.info("🎬 VIDEO_PROGRESS:   - Active subscriptions: \(self.cancellables.count)")
        logger.info("🎬 VIDEO_PROGRESS:   - Video loading service: available")
    }

    // MARK: - Cleanup

    deinit {
        logger.info("🎬 VIDEO_PROGRESS: 🧹 Service deallocating, cleaning up resources")
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