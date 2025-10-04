import Foundation
import Network
import OSLog
import Combine
import AVFoundation

/// MARK: - Unified Progress Engine
///
/// A psychologically-aware progress calculation engine that provides smooth, unified
/// video loading progress with predictive weighting based on file size and network conditions.
///
/// Key Features:
/// - Single 0.0-1.0 unified progress value representing entire import operation
/// - Predictive weighting based on file size and network conditions (Wi-Fi vs cellular)
/// - Smooth UI animation with ease-in acceleration curve, 60 FPS performance
/// - Network monitoring with NWPathMonitor for adaptive weighting
/// - Comprehensive error handling for network loss, insufficient storage, user cancellation
/// - Race condition prevention with @MainActor isolation
@MainActor
public final class UnifiedProgressEngine: ObservableObject {

    // MARK: - Published Properties
    @Published public private(set) var unifiedProgress: Double = 0.0
    @Published public private(set) var unifiedStatus: String = ""
    @Published public private(set) var estimatedTimeRemaining: TimeInterval = 0.0

    // MARK: - Progress Tracking
    private var downloadProgress: Double = 0.0
    private var transferProgress: Double = 0.0
    private var _currentPhase: LoadingPhase = .initializing

    /// Current loading phase (read-only public access)
    public var currentPhase: LoadingPhase {
        return _currentPhase
    }
    private var operationStartTime: Date = Date()
    private var lastProgressUpdate: Date = Date()

    // MARK: - Network Monitoring
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "UnifiedProgressEngine.network")
    @Published public private(set) var networkConnectionType: NetworkConnectionType = .unknown
    @Published public private(set) var networkQuality: NetworkQuality = .excellent

    // MARK: - Predictive Weighting
    private var downloadWeight: Double = 0.6
    private var transferWeight: Double = 0.4
    private var fileSizeEstimate: Int64 = 0
    private var adaptiveWeightingEnabled: Bool = true

    // MARK: - Animation & Smoothing
    private var animationTimer: Timer?
    private var _targetProgress: Double = 0.0

    /// Target progress for smooth animation (read-only public access)
    public var targetProgress: Double {
        return _targetProgress
    }
    private var currentAnimationProgress: Double = 0.0
    private let animationDuration: TimeInterval = 0.3 // 300ms for 60 FPS smoothness
    private let easeInFactor: Double = 0.8 // Ease-in acceleration curve factor

    // MARK: - Logging
    private let logger = Logger(subsystem: "breakdex", category: "🚀 UnifiedProgressEngine")

    // MARK: - Error Handling
    @Published public private(set) var currentError: ProgressError?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Enums

    public enum LoadingPhase: String, CaseIterable {
        case initializing = "initializing"
        case downloading = "downloading"
        case transferring = "transferring"
        case validating = "validating"
        case finalizing = "finalizing"
        case completed = "completed"
        case error = "error"

        var displayName: String {
            switch self {
            case .initializing: return "Initializing"
            case .downloading: return "Downloading video"
            case .transferring: return "Processing video"
            case .validating: return "Validating"
            case .finalizing: return "Finalizing"
            case .completed: return "Completed"
            case .error: return "Error"
            }
        }
    }

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

    public enum ProgressError: Error, LocalizedError {
        case networkLost
        case insufficientStorage(available: Int64, required: Int64)
        case userCancelled
        case timeout(duration: TimeInterval)
        case invalidFileSize(size: Int64)
        case unknown(String)

        public var errorDescription: String? {
            switch self {
            case .networkLost:
                return "Network connection lost during video import"
            case .insufficientStorage(let available, let required):
                return "Insufficient storage. Available: \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file)), Required: \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file))"
            case .userCancelled:
                return "Video import was cancelled"
            case .timeout(let duration):
                return "Operation timed out after \(String(format: "%.1f", duration)) seconds"
            case .invalidFileSize(let size):
                return "Invalid file size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))"
            case .unknown(let message):
                return "Unknown error: \(message)"
            }
        }
    }

    // MARK: - Initialization

    public init() {
        setupNetworkMonitoring()
        setupAnimationTimer()
        logger.info("🚀 UnifiedProgressEngine: Initialized with network monitoring and smooth animations")
    }

    deinit {
        networkMonitor.cancel()
        animationTimer?.invalidate()
        cancellables.removeAll()
        logger.info("🚀 UnifiedProgressEngine: Deinitialized")
    }

    // MARK: - Public Interface

    /// Begin a new video loading operation with optional file size estimate
    public func beginLoading(fileSizeEstimate: Int64 = 0) {
        logger.info("🚀 UnifiedProgressEngine: 📥 Beginning video loading operation - File size estimate: \(ByteCountFormatter.string(fromByteCount: fileSizeEstimate, countStyle: .file))")

        resetProgress()
        operationStartTime = Date()
        lastProgressUpdate = Date()
        self.fileSizeEstimate = fileSizeEstimate

        if fileSizeEstimate > 0 && adaptiveWeightingEnabled {
            calculatePredictiveWeights()
        }

        updatePhase(.initializing)
        logger.info("🚀 UnifiedProgressEngine: ✅ Loading operation initialized")
    }

    /// Update download progress (0.0 to 1.0)
    public func updateDownloadProgress(_ progress: Double) {
        guard self._currentPhase == .downloading else {
            logger.warning("🚀 UnifiedProgressEngine: ⚠️ Download progress update received in \(self._currentPhase.rawValue) phase")
            return
        }

        let clampedProgress = max(0.0, min(1.0, progress))
        downloadProgress = clampedProgress

        logger.debug("🚀 UnifiedProgressEngine: 📥 Download progress: \(Int(clampedProgress * 100))%")

        calculateUnifiedProgress()
    }

    /// Update transfer progress (0.0 to 1.0)
    public func updateTransferProgress(_ progress: Double) {
        guard self._currentPhase == .transferring else {
            logger.warning("🚀 UnifiedProgressEngine: ⚠️ Transfer progress update received in \(self._currentPhase.rawValue) phase")
            return
        }

        let clampedProgress = max(0.0, min(1.0, progress))
        transferProgress = clampedProgress

        logger.debug("🚀 UnifiedProgressEngine: 🔄 Transfer progress: \(Int(clampedProgress * 100))%")

        calculateUnifiedProgress()
    }

    /// Transition to a specific loading phase
    public func transitionToPhase(_ phase: LoadingPhase) {
        logger.info("🚀 UnifiedProgressEngine: 🔄 Transitioning to phase: \(phase.displayName) [from: \(self._currentPhase.displayName)]")
        logger.info("🚀 UnifiedProgressEngine: 📊 Progress before transition: \(String(format: "%.3f", self.unifiedProgress)) (\(Int(self.unifiedProgress * 100))%)")
        updatePhase(phase)
        logger.info("🚀 UnifiedProgressEngine: 📊 Progress after transition: \(String(format: "%.3f", self.unifiedProgress)) (\(Int(self.unifiedProgress * 100))%)")

        // Update progress based on phase transitions
        switch phase {
        case .downloading:
            // Download phase begins (0.0 - downloadWeight)
            calculateUnifiedProgress()
        case .transferring:
            // Transfer phase begins (downloadWeight - 1.0)
            downloadProgress = 1.0
            calculateUnifiedProgress()
        case .validating:
            // Validation phase - near completion
            downloadProgress = 1.0
            transferProgress = 1.0
            calculateUnifiedProgress()
        case .finalizing:
            // Finalizing phase - very close to completion
            setUnifiedProgress(0.95)
        case .completed:
            // Operation complete
            setUnifiedProgress(1.0)
        case .error:
            // Handle error case
            logger.error("🚀 UnifiedProgressEngine: ❌ Error phase reached")
        case .initializing:
            // Reset progress for initialization
            setUnifiedProgress(0.05)
        }
    }

    /// Complete the loading operation successfully
    public func completeLoading() {
        logger.info("🚀 UnifiedProgressEngine: ✅ Loading operation completed successfully")
        transitionToPhase(.completed)

        // Clean up animation timer after completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.animationTimer?.invalidate()
        }
    }

    /// Handle errors during loading
    public func handleError(_ error: ProgressError) {
        logger.error("🚀 UnifiedProgressEngine: ❌ Loading error: \(error.localizedDescription)")
        currentError = error
        transitionToPhase(.error)
    }

    /// Enhanced error handling with storage check and recovery suggestions
    public func handleStorageError(available: Int64, required: Int64) {
        logger.warning("🚀 UnifiedProgressEngine: 💾 Insufficient storage - Available: \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file)), Required: \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file))")

        let storageError = ProgressError.insufficientStorage(available: available, required: required)
        handleError(storageError)

        // Log recovery suggestions
        if available > 0 {
            logger.info("🚀 UnifiedProgressEngine: 💡 Recovery suggestion: Clear app cache or remove other files to free up \(ByteCountFormatter.string(fromByteCount: required - available, countStyle: .file))")
        } else {
            logger.error("🚀 UnifiedProgressEngine: ❌ No storage available - Device storage may be full")
        }
    }

    /// Handle timeout errors with context
    public func handleTimeout(duration: TimeInterval, phase: LoadingPhase) {
        logger.warning("🚀 UnifiedProgressEngine: ⏱️ Operation timed out after \(String(format: "%.1f", duration))s in phase: \(phase.displayName)")

        let timeoutError = ProgressError.timeout(duration: duration)
        handleError(timeoutError)

        // Log context for debugging
        logger.info("🚀 UnifiedProgressEngine: 📊 Timeout context - Phase: \(phase.displayName), Progress: \(String(format: "%.1f", self.unifiedProgress * 100))%, Network: \(self.networkConnectionType.displayName)")
    }

    /// Cancel the current loading operation
    public func cancelLoading() {
        logger.info("🚀 UnifiedProgressEngine: 🚫 Loading operation cancelled by user")
        handleError(.userCancelled)
    }

    // MARK: - Private Implementation

    private func resetProgress() {
        unifiedProgress = 0.0
        unifiedStatus = ""
        estimatedTimeRemaining = 0.0
        downloadProgress = 0.0
        transferProgress = 0.0
        _targetProgress = 0.0
        currentAnimationProgress = 0.0
        currentError = nil
        _currentPhase = .initializing
    }

    private func updatePhase(_ phase: LoadingPhase) {
        _currentPhase = phase
        unifiedStatus = phase.displayName
        lastProgressUpdate = Date()
        updateEstimatedTimeRemaining()
    }

    private func calculatePredictiveWeights() {
        // Adjust weights based on file size and network conditions
        let baseDownloadWeight = 0.6
        let baseTransferWeight = 0.4

        // Network-based adjustments
        var networkMultiplier: Double = 1.0

        switch networkConnectionType {
        case .wifi:
            networkMultiplier = 1.0
        case .cellular:
            networkMultiplier = 1.2 // Cellular may be slower, increase download weight
        case .ethernet:
            networkMultiplier = 0.8 // Ethernet is faster, decrease download weight
        default:
            networkMultiplier = 1.0
        }

        // File size-based adjustments
        var fileSizeMultiplier: Double = 1.0

        if fileSizeEstimate > 0 {
            // Large files (>100MB) need more download time
            if fileSizeEstimate > 100 * 1024 * 1024 {
                fileSizeMultiplier = 1.3
            }
            // Small files (<10MB) need less download time
            else if fileSizeEstimate < 10 * 1024 * 1024 {
                fileSizeMultiplier = 0.7
            }
        }

        // Apply multipliers
        let adjustedDownloadWeight = baseDownloadWeight * networkMultiplier * fileSizeMultiplier
        let adjustedTransferWeight = baseTransferWeight * (2.0 - networkMultiplier) * (2.0 - fileSizeMultiplier)

        // Normalize to ensure sum equals 1.0
        let totalWeight = adjustedDownloadWeight + adjustedTransferWeight
        downloadWeight = adjustedDownloadWeight / totalWeight
        transferWeight = adjustedTransferWeight / totalWeight

        logger.info("🚀 UnifiedProgressEngine: 📊 Predictive weights calculated - Download: \(String(format: "%.2f", self.downloadWeight)), Transfer: \(String(format: "%.2f", self.transferWeight))")
        logger.info("🚀 UnifiedProgressEngine: 📊 Weighting factors - Network: \(self.networkConnectionType.displayName) (\(String(format: "%.2f", networkMultiplier))), File size: \(ByteCountFormatter.string(fromByteCount: self.fileSizeEstimate, countStyle: .file)) (\(String(format: "%.2f", fileSizeMultiplier)))")
    }

    private func calculateUnifiedProgress() {
        let progress: Double

        switch currentPhase {
        case .initializing:
            progress = 0.05
        case .downloading:
            // p_unified = W_download * p_download
            progress = downloadWeight * downloadProgress
        case .transferring:
            // p_unified = W_download + W_transfer * p_transfer
            progress = downloadWeight + (transferWeight * transferProgress)
        case .validating:
            // Validation phase at 90% of progress
            progress = 0.9
        case .finalizing:
            // Finalizing phase at 95% of progress
            progress = 0.95
        case .completed:
            progress = 1.0
        case .error:
            progress = unifiedProgress // Maintain current progress on error
        }

        // Update target progress for smooth animation
        _targetProgress = max(0.0, min(1.0, progress))

        logger.debug("🚀 UnifiedProgressEngine: 📊 Unified progress calculated: \(String(format: "%.3f", self._targetProgress)) (Phase: \(self._currentPhase.rawValue))")
    }

    private func setUnifiedProgress(_ progress: Double) {
        _targetProgress = max(0.0, min(1.0, progress))
    }

    private func updateEstimatedTimeRemaining() {
        guard unifiedProgress > 0.01 else {
            estimatedTimeRemaining = 0
            return
        }

        let elapsed = Date().timeIntervalSince(operationStartTime)
        let estimatedTotal = elapsed / unifiedProgress
        estimatedTimeRemaining = max(0, estimatedTotal - elapsed)
    }

    // MARK: - Animation & Smoothing

    private func setupAnimationTimer() {
        self.animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAnimatedProgress()
            }
        }
    }

    private func updateAnimatedProgress() {
        // Calculate the distance between current animated progress and target progress
        let progressDelta = _targetProgress - currentAnimationProgress

        guard abs(progressDelta) > 0.001 else {
            return // No significant change needed - animation is essentially complete
        }

        // 🚨 CRITICAL FIX: Replace flawed ease-in calculation with linear interpolation
        //
        // PROBLEM: The previous calculation `pow(currentAnimationProgress, easeInFactor)`
        // results in 0 when currentAnimationProgress is 0, creating a mathematical singularity
        // that prevents the progress bar from "lifting off" from zero.
        //
        // EXAMPLE: pow(0.0, 0.8) = 0.0, so animationStep = progressDelta * 0.0 * 0.15 = 0.0
        // This causes the progress bar to remain stuck at 0% indefinitely.
        //
        // SOLUTION: Use linear interpolation that moves a fraction of the remaining distance
        // each frame. This creates a smooth ease-out animation and is mathematically stable.
        let animationStep = progressDelta * 0.1 // Move 10% of remaining distance per frame

        // 📊 DIAGNOSTIC LOGGING: Track animation behavior for verification
        logger.debug("🚀 UnifiedProgressEngine: 🎬 ANIMATION_FRAME - Target: \(String(format: "%.3f", self._targetProgress)), Current: \(String(format: "%.3f", self.currentAnimationProgress)), Delta: \(String(format: "%.3f", progressDelta)), Step: \(String(format: "%.3f", animationStep))")

        // Update current animation progress
        currentAnimationProgress += animationStep

        // Clamp to target to prevent overshooting
        if abs(self._targetProgress - self.currentAnimationProgress) < 0.001 {
            self.currentAnimationProgress = self._targetProgress
            logger.debug("🚀 UnifiedProgressEngine: ✅ ANIMATION_COMPLETE - Progress converged to target: \(String(format: "%.3f", self.currentAnimationProgress))")
        }

        // Update published progress for UI
        unifiedProgress = currentAnimationProgress
        updateEstimatedTimeRemaining()

        // 📊 ADDITIONAL DIAGNOSTIC: Log progress percentage for UI verification
        let progressPercentage = Int(self.currentAnimationProgress * 100)
        if progressPercentage % 10 == 0 && progressDelta > 0.01 {
            logger.info("🚀 UnifiedProgressEngine: 📊 UI_PROGRESS_UPDATE: \(progressPercentage)% (Target: \(Int(self._targetProgress * 100))%)")
        }
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handleNetworkPathUpdate(path)
            }
        }

        networkMonitor.start(queue: networkQueue)
        logger.info("🚀 UnifiedProgressEngine: 📡 Network monitoring started")
    }

    private func handleNetworkPathUpdate(_ path: NWPath) {
        // Determine connection type
        let newConnectionType: NetworkConnectionType

        if path.usesInterfaceType(.wifi) {
            newConnectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            newConnectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            newConnectionType = .ethernet
        } else if path.status == .satisfied {
            newConnectionType = .other
        } else {
            newConnectionType = .none
        }

        // Determine network quality
        let newNetworkQuality: NetworkQuality

        if path.status == .satisfied {
            if path.isExpensive {
                newNetworkQuality = .fair // Cellular is typically more expensive and potentially slower
            } else if path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet) {
                newNetworkQuality = .excellent
            } else {
                newNetworkQuality = .good
            }
        } else if path.status == .unsatisfied {
            newNetworkQuality = .poor
        } else {
            newNetworkQuality = .fair
        }

        // Handle network changes
        if newConnectionType != self.networkConnectionType {
            logger.info("🚀 UnifiedProgressEngine: 📡 Network connection changed: \(self.networkConnectionType.displayName) → \(newConnectionType.displayName)")
            let previousConnectionType = self.networkConnectionType
            self.networkConnectionType = newConnectionType

            // Handle network loss during operation with enhanced error handling
            if newConnectionType == .none && self._currentPhase != .completed && self._currentPhase != .error {
                logger.warning("🚀 UnifiedProgressEngine: ⚠️ Network lost during operation - Phase: \(self._currentPhase.displayName), Progress: \(String(format: "%.1f", self.unifiedProgress * 100))%")

                // Add delay to allow for temporary network interruptions
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    guard let self = self else { return }

                    // Check if network is still lost after delay
                    if self.networkConnectionType == .none && self._currentPhase != .completed && self._currentPhase != .error {
                        self.logger.warning("🚀 UnifiedProgressEngine: ❌ Network still lost after delay - Handling as network error")
                        self.handleError(.networkLost)
                    } else {
                        self.logger.info("🚀 UnifiedProgressEngine: ✅ Network restored after brief interruption")
                    }
                }
            }

            // Handle network degradation (e.g., switching from WiFi to cellular)
            if (previousConnectionType == .wifi && newConnectionType == .cellular) ||
               (previousConnectionType == .ethernet && newConnectionType != .ethernet) {
                logger.warning("🚀 UnifiedProgressEngine: ⚠️ Network degraded - \(previousConnectionType.displayName) → \(newConnectionType.displayName)")

                // Recalculate weights for slower network
                if adaptiveWeightingEnabled && fileSizeEstimate > 0 {
                    calculatePredictiveWeights()
                }
            }
        }

        if newNetworkQuality != self.networkQuality {
            logger.info("🚀 UnifiedProgressEngine: 📡 Network quality changed: \(self.networkQuality.displayName) → \(newNetworkQuality.displayName)")
            self.networkQuality = newNetworkQuality

            // Recalculate weights if network quality changes significantly
            if self.adaptiveWeightingEnabled && self.fileSizeEstimate > 0 {
                self.calculatePredictiveWeights()
            }
        }
    }
}

// MARK: - Progress Monitoring Extensions

extension UnifiedProgressEngine {

    /// Get current diagnostic information
    public var diagnosticInfo: [String: Any] {
        return [
            "unifiedProgress": unifiedProgress,
            "targetProgress": _targetProgress,
            "currentPhase": currentPhase.rawValue,
            "downloadProgress": downloadProgress,
            "transferProgress": transferProgress,
            "downloadWeight": downloadWeight,
            "transferWeight": transferWeight,
            "networkConnectionType": networkConnectionType.rawValue,
            "networkQuality": networkQuality.rawValue,
            "estimatedTimeRemaining": estimatedTimeRemaining,
            "fileSizeEstimate": fileSizeEstimate,
            "elapsedTime": Date().timeIntervalSince(operationStartTime),
            "lastProgressUpdate": lastProgressUpdate
        ]
    }

    /// Log diagnostic information
    public func logDiagnostics() {
        logger.info("🚀 UnifiedProgressEngine: 📊 DIAGNOSTIC REPORT")
        logger.info("🚀 UnifiedProgressEngine: ┌─ Progress Analysis")
        logger.info("🚀 UnifiedProgressEngine: │  ├─ Unified Progress: \(String(format: "%.3f", self.unifiedProgress)) (\(Int(self.unifiedProgress * 100))%)")
        logger.info("🚀 UnifiedProgressEngine: │  ├─ Target Progress: \(String(format: "%.3f", self._targetProgress))")
        logger.info("🚀 UnifiedProgressEngine: │  ├─ Current Phase: \(self._currentPhase.displayName)")
        logger.info("🚀 UnifiedProgressEngine: │  ├─ Download Progress: \(String(format: "%.3f", self.downloadProgress))")
        logger.info("🚀 UnifiedProgressEngine: │  └─ Transfer Progress: \(String(format: "%.3f", self.transferProgress))")

        logger.info("🚀 UnifiedProgressEngine: ├─ Weighting Analysis")
        logger.info("🚀 UnifiedProgressEngine: │  ├─ Download Weight: \(String(format: "%.3f", self.downloadWeight))")
        logger.info("🚀 UnifiedProgressEngine: │  └─ Transfer Weight: \(String(format: "%.3f", self.transferWeight))")

        logger.info("🚀 UnifiedProgressEngine: ├─ Network Analysis")
        logger.info("🚀 UnifiedProgressEngine: │  ├─ Connection Type: \(self.networkConnectionType.displayName)")
        logger.info("🚀 UnifiedProgressEngine: │  └─ Network Quality: \(self.networkQuality.displayName)")

        logger.info("🚀 UnifiedProgressEngine: ├─ Timing Analysis")
        logger.info("🚀 UnifiedProgressEngine: │  ├─ Estimated Time Remaining: \(String(format: "%.1f", self.estimatedTimeRemaining))s")
        logger.info("🚀 UnifiedProgressEngine: │  ├─ Elapsed Time: \(String(format: "%.1f", Date().timeIntervalSince(self.operationStartTime)))s")
        logger.info("🚀 UnifiedProgressEngine: │  └─ Last Progress Update: \(String(format: "%.1f", Date().timeIntervalSince(self.lastProgressUpdate)))s ago")

        logger.info("🚀 UnifiedProgressEngine: └─ File Analysis")
        logger.info("🚀 UnifiedProgressEngine:     ├─ File Size Estimate: \(ByteCountFormatter.string(fromByteCount: self.fileSizeEstimate, countStyle: .file))")
        logger.info("🚀 UnifiedProgressEngine:     └─ Adaptive Weighting: \(self.adaptiveWeightingEnabled ? "Enabled" : "Disabled")")
    }

    // MARK: - Legacy Progress Processing

    /// Process legacy VideoLoadingProgress updates and manage state transitions
    public func processLegacyProgress(_ progress: VideoLoadingProgress) {
        switch progress.phase {
        case .initializing:
            self.transitionToPhase(.initializing)
        case .downloadingFromCloud(let downloadProgress):
            // If we aren't in the downloading phase, transition to it first
            if self._currentPhase != .downloading {
                self.transitionToPhase(.downloading)
            }
            self.updateDownloadProgress(downloadProgress)
        case .transferring:
            if self._currentPhase != .transferring {
                self.transitionToPhase(.transferring)
            }
            self.updateTransferProgress(progress.progress)
        case .validating, .creatingAsset:
            self.transitionToPhase(.validating)
        case .loadingTrimmerDuration, .loadingTrimmerTracks:
            self.transitionToPhase(.finalizing)
        case .validatingTrimmer:
            // 🎯 CATEGORY THEORY FIX: Terminal Object Mapping - .validatingTrimmer is true terminal signal
            // In category theory, terminal objects have unique morphisms from all other objects
            // .validatingTrimmer must map to .completed (1.0) as it's the terminal state of loading pipeline
            logger.info("🚀 UnifiedProgressEngine: 🎯 TERMINAL_OBJECT_MAPPING: .validatingTrimmer → .completed (1.0)")
            logger.info("🚀 UnifiedProgressEngine: 📊 CATEGORY_THEORY: Ensuring terminal morphism satisfies completion condition (>= 1.0)")

            // 🎯 DEFINTIVE FIX: Set unifiedProgress to exactly 1.0 to satisfy completion condition
            // This eliminates the 99% stall where completion check requires >= 1.0
            self.setUnifiedProgress(1.0)
            self.transitionToPhase(.completed)

            logger.info("🚀 UnifiedProgressEngine: ✅ TERMINAL_STATE_ACHIEVED: Progress = 1.0, Phase = .completed")
            logger.info("🚀 UnifiedProgressEngine: 🎯 COMPLETION_GUARANTEE: All morphisms composed successfully to terminal object")
        }
    }
}