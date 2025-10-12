import Foundation
import Combine
import OSLog

// MARK: - Unified Progress Engine
/// Essentialist unified progress engine - simple implementation
/// Follows YAGNI principle - only what's needed for current functionality
public class UnifiedProgressEngine: ObservableObject {

    // MARK: - Published Properties
    @Published public private(set) var currentProgress: Double = 0.0
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var currentPhase: ProgressPhase = .idle

    // MARK: - Additional Properties for VideoLoadingServiceResilient Compatibility
    @Published public private(set) var unifiedProgress: Double = 0.0
    @Published public private(set) var unifiedStatus: String = "Ready"
    @Published public private(set) var currentError: Error? = nil

    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "📊 UnifiedProgressEngine")
    private var progressSubject = PassthroughSubject<Double, Never>()

    // MARK: - Initialization
    public init() {
        logger.info("🚀 UnifiedProgressEngine initialized")
    }

    // MARK: - Progress Publishing
    /// Publish progress updates - main interface for progress reporting
    public func publishProgress(_ progress: Double) {
        DispatchQueue.main.async {
            self.currentProgress = max(0.0, min(1.0, progress)) // Clamp between 0.0 and 1.0
            self.progressSubject.send(self.currentProgress)
            self.logger.debug("Progress updated: \(Int(self.currentProgress * 100))%")
        }
    }

    /// Publish progress with loading state
    public func publishProgress(_ progress: Double, isLoading: Bool) {
        DispatchQueue.main.async {
            self.isLoading = isLoading
            self.publishProgress(progress)
        }
    }

    /// Increment progress by a specific amount
    public func incrementProgress(by amount: Double) {
        DispatchQueue.main.async {
            let newProgress = self.currentProgress + amount
            self.publishProgress(newProgress)
        }
    }

    /// Reset progress to initial state
    public func reset() {
        DispatchQueue.main.async {
            self.currentProgress = 0.0
            self.unifiedProgress = 0.0
            self.currentPhase = .idle
            self.unifiedStatus = "Ready"
            self.currentError = nil
            self.isLoading = false
            self.progressSubject.send(0.0)
            self.logger.info("Progress reset to initial state")
        }
    }

    /// Set progress to complete
    public func complete() {
        DispatchQueue.main.async {
            self.currentProgress = 1.0
            self.isLoading = false
            self.progressSubject.send(1.0)
            self.logger.info("Progress marked as complete")
        }
    }

    // MARK: - Combine Integration
    /// Progress publisher for Combine integration
    public var progressPublisher: AnyPublisher<Double, Never> {
        progressSubject
            .prepend(0.0) // Provide initial value
            .eraseToAnyPublisher()
    }

    /// Combined publisher for both progress and loading state
    public var combinedPublisher: AnyPublisher<(progress: Double, isLoading: Bool), Never> {
        Publishers.CombineLatest(
            $currentProgress,
            $isLoading
        )
        .map { (progress, isLoading) in
            (progress: progress, isLoading: isLoading)
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Convenience Methods
    /// Start loading with initial progress
    public func startLoading() {
        publishProgress(0.0, isLoading: true)
        logger.info("📥 Loading started")
    }

    /// Stop loading and mark as complete
    public func stopLoading() {
        complete()
        logger.info("✅ Loading stopped and marked complete")
    }

    /// Update progress with optional loading state
    public func updateProgress(_ progress: Double, isLoading: Bool? = nil) {
        if let isLoading = isLoading {
            publishProgress(progress, isLoading: isLoading)
        } else {
            publishProgress(progress)
        }
    }

    /// Update progress with phase and status
    public func updateProgress(_ progress: Double, phase: ProgressPhase, status: String) {
        DispatchQueue.main.async {
            self.currentProgress = progress
            self.unifiedProgress = progress
            self.currentPhase = phase
            self.unifiedStatus = status
            self.progressSubject.send(progress)
            self.logger.debug("Progress updated: \(Int(progress * 100))%, Phase: \(phase.rawValue), Status: \(status)")
        }
    }

    /// Set error state
    public func setError(_ error: Error) {
        DispatchQueue.main.async {
            self.currentError = error
            self.currentPhase = .error
            self.unifiedStatus = error.localizedDescription
            self.isLoading = false
            self.logger.error("Progress error: \(error.localizedDescription)")
        }
    }

    /// Clear error state
    public func clearError() {
        DispatchQueue.main.async {
            self.currentError = nil
            if self.currentPhase == .error {
                self.currentPhase = .idle
                self.unifiedStatus = "Ready"
            }
            self.logger.info("Progress error cleared")
        }
    }

    // MARK: - ResilientVideoLoaderIntegration Compatibility Methods

    /// Begin loading operation
    public func beginLoading() {
        DispatchQueue.main.async {
            self.isLoading = true
            self.currentProgress = 0.0
            self.unifiedProgress = 0.0
            self.unifiedStatus = "Loading..."
            self.logger.info("Loading operation begun")
        }
    }

    /// Complete loading operation
    public func completeLoading() {
        DispatchQueue.main.async {
            self.isLoading = false
            self.currentProgress = 1.0
            self.unifiedProgress = 1.0
            self.currentPhase = .complete
            self.unifiedStatus = "Complete"
            self.progressSubject.send(1.0)
            self.logger.info("Loading operation completed")
        }
    }

    /// Cancel loading operation
    public func cancelLoading() {
        DispatchQueue.main.async {
            self.isLoading = false
            self.currentPhase = .idle
            self.unifiedStatus = "Cancelled"
            self.logger.info("Loading operation cancelled")
        }
    }

    /// Transition to specific phase
    public func transitionToPhase(_ phase: ProgressPhase) {
        DispatchQueue.main.async {
            self.currentPhase = phase
            self.unifiedProgress = phase.defaultProgress
            self.currentProgress = phase.defaultProgress
            self.unifiedStatus = phase.rawValue
            self.progressSubject.send(phase.defaultProgress)
            self.logger.debug("Transitioned to phase: \(phase.rawValue)")
        }
    }

    /// Update download progress (for cloud downloads)
    public func updateDownloadProgress(_ downloadProgress: Double) {
        DispatchQueue.main.async {
            // Weight the download progress appropriately (45% of total progress)
            let baseProgress = 0.03 // initializing phase progress
            let downloadWeight = 0.45
            let weightedProgress = baseProgress + (downloadProgress * downloadWeight)

            self.unifiedProgress = weightedProgress
            self.currentProgress = weightedProgress
            self.progressSubject.send(weightedProgress)
            self.logger.debug("Download progress updated: \(Int(downloadProgress * 100))% (weighted: \(Int(weightedProgress * 100))%)")
        }
    }

    /// Handle error with progress error type
    public func handleError(_ error: ProgressError) {
        DispatchQueue.main.async {
            self.currentError = error
            self.currentPhase = .error
            self.unifiedStatus = error.localizedDescription
            self.isLoading = false
            self.logger.error("Progress error: \(error.localizedDescription)")
        }
    }

    // MARK: - Deinit
    deinit {
        progressSubject.send(completion: .finished)
        logger.info("🗑️ UnifiedProgressEngine deinitialized")
    }
}

// MARK: - Progress Engine Extensions
public extension UnifiedProgressEngine {

    /// Create a progress engine with predefined configuration
    static var shared: UnifiedProgressEngine {
        UnifiedProgressEngine()
    }

    /// Create progress engine for video operations
    static func forVideoOperations() -> UnifiedProgressEngine {
        let engine = UnifiedProgressEngine()
        engine.logger.info("🎥 Video operations progress engine created")
        return engine
    }

    /// Create progress engine for general operations
    static func forGeneralOperations() -> UnifiedProgressEngine {
        let engine = UnifiedProgressEngine()
        engine.logger.info("⚙️ General operations progress engine created")
        return engine
    }
}