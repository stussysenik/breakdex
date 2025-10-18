import Foundation
import OSLog
import Combine

// MARK: - Progress Debouncer
/// Implements progress update debouncing to prevent UI update storms and race conditions
/// Provides correlation ID based state tracking and ensures atomic progress updates
@MainActor
public class ProgressDebouncer: ObservableObject {

    // MARK: - Properties
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "📊 ProgressDebouncer")
    private let debounceInterval: TimeInterval
    private var pendingUpdates: [String: PendingProgressUpdate] = [:]
    private var debounceTimers: [String: Timer] = [:]
    private let updateQueue = DispatchQueue(label: "breakdex.progress.debouncer", qos: .userInitiated)

    // Progress tracking
    @Published private(set) var lastProcessedUpdate: ProgressUpdate?
    @Published private(set) var updateStatistics = UpdateStatistics()

    // MARK: - Progress Update Structure
    public struct ProgressUpdate {
        public let correlationId: String
        public let phase: VideoLoadingProgress.LoadingPhase
        public let progress: Double
        public let timestamp: Date
        public let metadata: [String: Any]

        public init(correlationId: String, phase: VideoLoadingProgress.LoadingPhase, progress: Double, metadata: [String: Any] = [:]) {
            self.correlationId = correlationId
            self.phase = phase
            self.progress = progress
            self.timestamp = Date()
            self.metadata = metadata
        }
    }

    private struct PendingProgressUpdate {
        let update: ProgressUpdate
        let completion: (ProgressUpdate) -> Void
        let timestamp: Date
    }

    public struct UpdateStatistics {
        public let totalUpdates: Int
        public let debouncedUpdates: Int
        public let droppedUpdates: Int
        public let averageUpdateTime: TimeInterval

        public init(totalUpdates: Int = 0, debouncedUpdates: Int = 0, droppedUpdates: Int = 0, averageUpdateTime: TimeInterval = 0.0) {
            self.totalUpdates = totalUpdates
            self.debouncedUpdates = debouncedUpdates
            self.droppedUpdates = droppedUpdates
            self.averageUpdateTime = averageUpdateTime
        }
    }

    // MARK: - Initialization
    public init(debounceInterval: TimeInterval = 0.1) {
        self.debounceInterval = debounceInterval
        logger.info("📊 ProgressDebouncer initialized with interval: \(debounceInterval)s")
    }

    // MARK: - Debounced Progress Updates

    /// Submit progress update for debouncing with correlation ID tracking
    /// - Parameters:
    ///   - correlationId: Unique identifier for operation tracking
    ///   - phase: Loading phase
    ///   - progress: Progress value (0.0-1.0)
    ///   - metadata: Additional metadata for the update
    ///   - completion: Completion handler for the debounced update
    public func submitProgressUpdate(
        correlationId: String,
        phase: VideoLoadingProgress.LoadingPhase,
        progress: Double,
        metadata: [String: Any] = [:],
        completion: @escaping (ProgressUpdate) -> Void
    ) {
        let update = ProgressUpdate(
            correlationId: correlationId,
            phase: phase,
            progress: progress,
            metadata: metadata
        )

        updateQueue.async { [weak self] in
            self?.handleProgressUpdate(update, completion: completion)
        }
    }

    private func handleProgressUpdate(_ update: ProgressUpdate, completion: @escaping (ProgressUpdate) -> Void) {
        let correlationId = update.correlationId

        // Cancel existing timer for this correlation ID
        debounceTimers[correlationId]?.invalidate()
        debounceTimers.removeValue(forKey: correlationId)

        // Store pending update
        pendingUpdates[correlationId] = PendingProgressUpdate(
            update: update,
            completion: completion,
            timestamp: Date()
        )

        // Schedule debounced update
        let timer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.executePendingUpdate(correlationId: correlationId)
            }
        }

        debounceTimers[correlationId] = timer

        logger.debug("📊 Progress update queued [\(correlationId)]: \(update.phase) (\(Int(update.progress * 100))%)")
    }

    private func executePendingUpdate(correlationId: String) async {
        guard let pendingUpdate = pendingUpdates[correlationId] else {
            logger.warning("⚠️ No pending update found for correlation ID: \(correlationId)")
            return
        }

        // Remove from pending updates and timers
        pendingUpdates.removeValue(forKey: correlationId)
        debounceTimers[correlationId]?.invalidate()
        debounceTimers.removeValue(forKey: correlationId)

        let update = pendingUpdate.update
        let startTime = Date()

        // Execute the completion handler
        pendingUpdate.completion(update)

        // Update tracking
        lastProcessedUpdate = update
        updateStatistics = UpdateStatistics(
            totalUpdates: updateStatistics.totalUpdates + 1,
            debouncedUpdates: updateStatistics.debouncedUpdates + 1,
            droppedUpdates: updateStatistics.droppedUpdates,
            averageUpdateTime: calculateAverageUpdateTime(
                current: updateStatistics.averageUpdateTime,
                new: Date().timeIntervalSince(startTime)
            )
        )

        logger.info("📊 Progress update executed [\(correlationId)]: \(update.phase) (\(Int(update.progress * 100))%)")
    }

    // MARK: - Priority Updates

    /// Submit high-priority update that bypasses debouncing
    /// Used for critical state changes like completion or errors
    public func submitPriorityUpdate(
        correlationId: String,
        phase: VideoLoadingProgress.LoadingPhase,
        progress: Double,
        metadata: [String: Any] = [:],
        completion: @escaping (ProgressUpdate) -> Void
    ) {
        let update = ProgressUpdate(
            correlationId: correlationId,
            phase: phase,
            progress: progress,
            metadata: metadata
        )

        logger.info("🚨 Priority update bypassing debounce [\(correlationId)]: \(update.phase)")

        // Cancel any pending debounced updates for this correlation ID
        cancelPendingUpdates(correlationId: correlationId)

        // Execute immediately
        Task { @MainActor in
            completion(update)
            lastProcessedUpdate = update

            updateStatistics = UpdateStatistics(
                totalUpdates: updateStatistics.totalUpdates + 1,
                debouncedUpdates: updateStatistics.debouncedUpdates,
                droppedUpdates: updateStatistics.droppedUpdates,
                averageUpdateTime: updateStatistics.averageUpdateTime
            )
        }
    }

    // MARK: - Batch Updates

    /// Submit multiple progress updates as a batch
    /// Useful for coordinating updates from multiple sources
    public func submitBatchUpdates(
        updates: [(correlationId: String, phase: VideoLoadingProgress.LoadingPhase, progress: Double, metadata: [String: Any])],
        completion: @escaping ([ProgressUpdate]) -> Void
    ) {
        let batchCorrelationId = "BATCH-\(UUID().uuidString.prefix(8))"

        updateQueue.async { [weak self] in
            let progressUpdates = updates.map { update in
                ProgressUpdate(
                    correlationId: update.correlationId,
                    phase: update.phase,
                    progress: update.progress,
                    metadata: update.metadata
                )
            }

            Task { @MainActor [weak self] in
                completion(progressUpdates)
                self?.handleBatchCompletion(updates: progressUpdates, batchId: batchCorrelationId)
            }
        }

        logger.info("📦 Batch update submitted [\(batchCorrelationId)]: \(updates.count) updates")
    }

    private func handleBatchCompletion(updates: [ProgressUpdate], batchId: String) {
        if let lastUpdate = updates.last {
            lastProcessedUpdate = lastUpdate
        }

        updateStatistics = UpdateStatistics(
            totalUpdates: updateStatistics.totalUpdates + updates.count,
            debouncedUpdates: updateStatistics.debouncedUpdates,
            droppedUpdates: updateStatistics.droppedUpdates,
            averageUpdateTime: updateStatistics.averageUpdateTime
        )

        logger.info("📦 Batch update completed [\(batchId)]: \(updates.count) updates processed")
    }

    // MARK: - Correlation ID Management

    /// Cancel all pending updates for a specific correlation ID
    public func cancelPendingUpdates(correlationId: String) {
        updateQueue.async { [weak self] in
            self?.pendingUpdates.removeValue(forKey: correlationId)
            self?.debounceTimers[correlationId]?.invalidate()
            self?.debounceTimers.removeValue(forKey: correlationId)
        }

        logger.debug("🚫 Pending updates cancelled for correlation ID: \(correlationId)")
    }

    /// Cancel all pending updates across all correlation IDs
    public func cancelAllPendingUpdates() {
        updateQueue.async { [weak self] in
            self?.pendingUpdates.removeAll()
            self?.debounceTimers.values.forEach { $0.invalidate() }
            self?.debounceTimers.removeAll()
        }

        logger.info("🚫 All pending updates cancelled")
    }

    /// Get list of active correlation IDs
    public var activeCorrelationIds: [String] {
        return Array(pendingUpdates.keys)
    }

    /// Check if there are pending updates for a correlation ID
    public func hasPendingUpdates(correlationId: String) -> Bool {
        return pendingUpdates[correlationId] != nil
    }

    // MARK: - Statistics and Diagnostics

    private func calculateAverageUpdateTime(current: TimeInterval, new: TimeInterval) -> TimeInterval {
        if updateStatistics.totalUpdates == 0 {
            return new
        }
        return (current * Double(updateStatistics.totalUpdates) + new) / Double(updateStatistics.totalUpdates + 1)
    }

    /// Reset statistics
    public func resetStatistics() {
        updateStatistics = UpdateStatistics()
        logger.debug("📊 Progress debouncer statistics reset")
    }

    /// Get diagnostic information
    public func getDiagnosticInfo() -> [String: Any] {
        return [
            "pendingUpdates": pendingUpdates.count,
            "activeTimers": debounceTimers.count,
            "activeCorrelationIds": activeCorrelationIds,
            "statistics": [
                "totalUpdates": updateStatistics.totalUpdates,
                "debouncedUpdates": updateStatistics.debouncedUpdates,
                "droppedUpdates": updateStatistics.droppedUpdates,
                "averageUpdateTime": updateStatistics.averageUpdateTime
            ],
            "debounceInterval": debounceInterval
        ]
    }

    // MARK: - Cleanup

    deinit {
        // Clean up all timers
        debounceTimers.values.forEach { $0.invalidate() }
        debounceTimers.removeAll()
        pendingUpdates.removeAll()

        logger.debug("📊 ProgressDebouncer deallocated")
    }
}

// MARK: - Progress Update Extensions
extension ProgressDebouncer.ProgressUpdate {
    /// Check if this is a completion update
    public var isCompletion: Bool {
        return phase == .completed || phase == .complete
    }

    /// Check if this is an error update
    public var isError: Bool {
        return phase.isError
    }

    /// Get display percentage
    public var displayPercentage: Int {
        return Int(progress * 100)
    }

    /// Get formatted metadata description
    public var metadataDescription: String {
        if metadata.isEmpty {
            return "No metadata"
        }
        return "\(metadata.count) metadata items"
    }
}

// MARK: - Loading Phase Extensions
extension VideoLoadingProgress.LoadingPhase {
    /// Check if phase should bypass debouncing (high priority)
    public var shouldBypassDebounce: Bool {
        switch self {
        case .completed, .complete, .error, .timeout:
            return true
        default:
            return false
        }
    }
}