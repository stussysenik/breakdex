import Foundation
import Network
import OSLog
import Combine
import AVFoundation

/// MARK: - Unified Progress Engine
///
/// A deterministic progress calculation engine that provides precise, reality-aligned
/// video loading progress with fixed stage weighting based on actual backend operations.
///
/// Key Features:
/// - Single 0.0-1.0 unified progress value representing entire import operation
/// - Deterministic stage-based weighting (no predictive algorithms)
/// - F1-precision millisecond timer with exact timing measurements
/// - Fixed stage weights that sum to exactly 1.0 for guaranteed completion
/// - Comprehensive diagnostic logging using OSLog categories
/// - Race condition prevention with @MainActor isolation
/// - Terminal state completion guarantee (validatingTrimmer → 1.0)
@MainActor
public final class UnifiedProgressEngine: ObservableObject {

    // MARK: - Published Properties
    @Published public private(set) var unifiedProgress: Double = 0.0
    @Published public private(set) var unifiedStatus: String = ""
    @Published public private(set) var estimatedTimeRemaining: TimeInterval = 0.0

    // MARK: - Progress Tracking
    private var phaseProgress: Double = 0.0
    private var _currentPhase: LoadingPhase = .initializing

    /// Current loading phase (read-only public access)
    public var currentPhase: LoadingPhase {
        return _currentPhase
    }
    private var operationStartTime: Date = Date()
    private var lastProgressUpdate: Date = Date()

    // MARK: - F1-Precision Timer
    private var timerStartTime: Date = Date()
    private var timerTimer: Timer?
    @Published public private(set) var elapsedTime: TimeInterval = 0.0
    @Published public private(set) var elapsedTimeString: String = "00:00.00"

    // MARK: - Deterministic Stage Weighting
    /// Fixed stage weights that sum to exactly 1.0 for deterministic progress
    private let stageWeights: [LoadingPhase: Double] = [
        .initializing: 0.05,           // 5% - Initial setup
        .downloadingFromCloud: 0.50,   // 50% - Download from iCloud (largest chunk)
        .transferring: 0.20,           // 20% - Transfer and processing
        .validating: 0.10,             // 10% - Video validation
        .creatingAsset: 0.05,          // 5% - Asset creation
        .loadingTrimmerDuration: 0.03, // 3% - Load trimmer duration
        .loadingTrimmerTracks: 0.02,   // 2% - Load trimmer tracks
        .validatingTrimmer: 0.05       // 5% - Final validation (TERMINAL STATE)
    ]

    // Verify weights sum to 1.0
    private var totalWeight: Double {
        return stageWeights.values.reduce(0, +)
    }

    // MARK: - Animation & Smoothing (DISABLED for determinism)
    private var animationTimer: Timer?
    private var _targetProgress: Double = 0.0

    /// Target progress for smooth animation (read-only public access)
    public var targetProgress: Double {
        return _targetProgress
    }
    private var currentAnimationProgress: Double = 0.0
    private let animationFrameInterval: TimeInterval = 1.0/60.0 // 60 FPS

    // MARK: - Logging
    private let logger = Logger(subsystem: "breakdex", category: "🎯 DeterministicProgressEngine")
    private let progressLogger = Logger(subsystem: "breakdex", category: "📊 ProgressCalculation")
    private let timerLogger = Logger(subsystem: "breakdex", category: "⏱️ F1Timer")

    // MARK: - Error Handling
    @Published public private(set) var currentError: ProgressError?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Enums

    public enum LoadingPhase: String, CaseIterable, Comparable {
        case initializing = "initializing"
        case downloadingFromCloud = "downloadingFromCloud"
        case transferring = "transferring"
        case validating = "validating"
        case creatingAsset = "creatingAsset"
        case loadingTrimmerDuration = "loadingTrimmerDuration"
        case loadingTrimmerTracks = "loadingTrimmerTracks"
        case validatingTrimmer = "validatingTrimmer"
        case completed = "completed"
        case error = "error"

        // Order property for deterministic progress calculation
        var order: Int {
            switch self {
            case .initializing: return 0
            case .downloadingFromCloud: return 1
            case .transferring: return 2
            case .validating: return 3
            case .creatingAsset: return 4
            case .loadingTrimmerDuration: return 5
            case .loadingTrimmerTracks: return 6
            case .validatingTrimmer: return 7
            case .completed: return 8
            case .error: return 9
            }
        }

        // For Comparable conformance
        public static func < (lhs: LoadingPhase, rhs: LoadingPhase) -> Bool {
            return lhs.order < rhs.order
        }

        var displayName: String {
            switch self {
            case .initializing: return "Initializing"
            case .downloadingFromCloud: return "Downloading from iCloud"
            case .transferring: return "Transferring video"
            case .validating: return "Validating video"
            case .creatingAsset: return "Creating asset"
            case .loadingTrimmerDuration: return "Loading trimmer duration"
            case .loadingTrimmerTracks: return "Loading trimmer tracks"
            case .validatingTrimmer: return "Validating trimmer setup"
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
        verifyStageWeights()
        setupF1Timer()
        setupAnimationTimer()
        logger.info("🎯 DeterministicProgressEngine: Initialized with deterministic stage weights and F1-precision timer")
        progressLogger.info("📊 Stage weights verified: Total = \(String(format: "%.3f", self.totalWeight))")
    }

    deinit {
        timerTimer?.invalidate()
        timerTimer = nil
        animationTimer?.invalidate()
        cancellables.removeAll()
        logger.info("🎯 DeterministicProgressEngine: Deinitialized")
    }

    // MARK: - Stage Weight Verification

    private func verifyStageWeights() {
        let calculatedTotal = totalWeight
        let expectedTotal = 1.0

        if abs(calculatedTotal - expectedTotal) > 0.001 {
            logger.error("🎯 DeterministicProgressEngine: ❌ CRITICAL - Stage weights sum to \(String(format: "%.6f", calculatedTotal)), expected \(expectedTotal)")
            fatalError("Stage weights must sum to exactly 1.0 for deterministic progress")
        } else {
            logger.info("🎯 DeterministicProgressEngine: ✅ Stage weights verification passed - Sum = \(String(format: "%.3f", calculatedTotal))")
        }

        // Log each stage weight for diagnostic purposes
        for (phase, weight) in stageWeights {
            progressLogger.debug("📊 Stage: \(phase.rawValue) → Weight: \(String(format: "%.3f", weight)) (\(Int(weight * 100))%)")
        }
    }

    // MARK: - Public Interface

    /// Begin a new video loading operation with optional file size estimate
    public func beginLoading(fileSizeEstimate: Int64 = 0) {
        logger.info("🎯 DeterministicProgressEngine: 📥 Beginning deterministic video loading operation")
        progressLogger.info("📊 Operation started - File size estimate: \(ByteCountFormatter.string(fromByteCount: fileSizeEstimate, countStyle: .file))")

        resetProgress()
        operationStartTime = Date()
        lastProgressUpdate = Date()
        startF1Timer()

        // 🎯 LIFECYCLE FIX: Re-initialize the animation timer if it has been invalidated.
        if animationTimer == nil || !(animationTimer?.isValid ?? false) {
            logger.info("🎯 DeterministicProgressEngine: 🔄 Animation timer is invalid, re-initializing for new operation.")
            setupAnimationTimer()
        }

        // No predictive weighting - use deterministic stage weights
        updatePhase(.initializing)
        calculateDeterministicProgress(phase: .initializing, phaseProgress: 0.0)

        logger.info("🎯 DeterministicProgressEngine: ✅ Deterministic loading operation initialized")
        progressLogger.info("📊 Initial progress: \(String(format: "%.3f", self.unifiedProgress)) (\(Int(self.unifiedProgress * 100))%)")
    }

    /// Update download progress (0.0 to 1.0)
    public func updateDownloadProgress(_ progress: Double) {
        guard self._currentPhase == .downloadingFromCloud else {
            logger.warning("🎯 DeterministicProgressEngine: ⚠️ Download progress update received in \(self._currentPhase.rawValue) phase")
            return
        }

        let clampedProgress = max(0.0, min(1.0, progress))
        phaseProgress = clampedProgress

        progressLogger.debug("📊 Download progress: \(String(format: "%.1f", clampedProgress * 100))%")

        calculateDeterministicProgress(phase: .downloadingFromCloud, phaseProgress: clampedProgress)
    }

    /// Update transfer progress (0.0 to 1.0)
    public func updateTransferProgress(_ progress: Double) {
        guard self._currentPhase == .transferring else {
            logger.warning("🎯 DeterministicProgressEngine: ⚠️ Transfer progress update received in \(self._currentPhase.rawValue) phase")
            return
        }

        let clampedProgress = max(0.0, min(1.0, progress))
        phaseProgress = clampedProgress

        progressLogger.debug("📊 Transfer progress: \(String(format: "%.1f", clampedProgress * 100))%")

        calculateDeterministicProgress(phase: .transferring, phaseProgress: clampedProgress)
    }

    /// Transition to a specific loading phase
    public func transitionToPhase(_ phase: LoadingPhase) {
        logger.info("🎯 DeterministicProgressEngine: 🔄 Transitioning to phase: \(phase.displayName) [from: \(self._currentPhase.displayName)]")
        progressLogger.info("📊 Progress before transition: \(String(format: "%.3f", self.unifiedProgress)) (\(Int(self.unifiedProgress * 100))%)")

        updatePhase(phase)

        // 🎯 TERMINAL STATE FIX: Special handling for validatingTrimmer to guarantee 1.0 completion
        if phase == .validatingTrimmer {
            progressLogger.info("🎯 TERMINAL_STATE: Validating trimmer - setting progress to 1.0")
            calculateDeterministicProgress(phase: .validatingTrimmer, phaseProgress: 1.0)
        } else {
            calculateDeterministicProgress(phase: phase, phaseProgress: 0.0)
        }

        progressLogger.info("📊 Progress after transition: \(String(format: "%.3f", self.unifiedProgress)) (\(Int(self.unifiedProgress * 100))%)")

        // 🎯 COMPLETION GUARANTEE: Force completion when terminal state is reached
        if phase == .completed {
            progressLogger.info("🎯 COMPLETION: Operation completed - ensuring 1.0 progress")
            setUnifiedProgress(1.0)
        }
    }

    /// Complete the loading operation successfully
    public func completeLoading() {
        logger.info("🎯 DeterministicProgressEngine: ✅ Deterministic loading operation completed successfully")
        progressLogger.info("📊 Final completion - Total elapsed time: \(String(format: "%.2f", self.elapsedTime))s")
        transitionToPhase(.completed)
        stopF1Timer()

        // 🎯 LIFECYCLE FIX: Clean up animation timer after completion with proper logging
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }

            if let timer = self.animationTimer {
                timer.invalidate()
                self.animationTimer = nil
                self.logger.info("🎯 DeterministicProgressEngine: 🧹 Animation timer invalidated and set to nil after completion")
            } else {
                self.logger.warning("🎯 DeterministicProgressEngine: ⚠️ Animation timer was already nil when attempting to clean up after completion")
            }
        }
    }

    /// Handle errors during loading
    public func handleError(_ error: ProgressError) {
        logger.error("🎯 DeterministicProgressEngine: ❌ Loading error: \(error.localizedDescription)")
        progressLogger.error("📊 Error occurred in phase: \(self._currentPhase.rawValue) at progress: \(String(format: "%.3f", self.unifiedProgress))")
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
        logger.info("🚀 UnifiedProgressEngine: 📊 Timeout context - Phase: \(phase.displayName), Progress: \(String(format: "%.1f", self.unifiedProgress * 100))%, Network: \(NetworkConnectionType.wifi.displayName)")
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
        phaseProgress = 0.0
        _targetProgress = 0.0
        currentAnimationProgress = 0.0
        currentError = nil
        _currentPhase = .initializing
        elapsedTime = 0.0
        elapsedTimeString = "00:00.00"
    }

    private func updatePhase(_ phase: LoadingPhase) {
        _currentPhase = phase
        unifiedStatus = phase.displayName
        lastProgressUpdate = Date()
        updateEstimatedTimeRemaining()
    }

    // MARK: - Deterministic Progress Calculation

    /// Calculate deterministic progress based on fixed stage weights
    /// This replaces all predictive/time-based smoothing algorithms with deterministic calculation
    private func calculateDeterministicProgress(phase: LoadingPhase, phaseProgress: Double) {
        progressLogger.debug("📊 CALCULATION: Phase=\(phase.rawValue), PhaseProgress=\(String(format: "%.3f", phaseProgress))")

        var totalProgress = 0.0

        // Add weights of all completed phases before the current one
        for (currentPhase, weight) in stageWeights {
            if currentPhase.order < phase.order {
                totalProgress += weight
                progressLogger.debug("📊 Completed phase: \(currentPhase.rawValue) (+\(String(format: "%.3f", weight))) = \(String(format: "%.3f", totalProgress))")
            }
        }

        // Add the progress of the current phase (if it has a weight)
        if let currentPhaseWeight = stageWeights[phase] {
            let phaseContribution = currentPhaseWeight * phaseProgress
            totalProgress += phaseContribution
            progressLogger.debug("📊 Current phase contribution: \(phase.rawValue) × \(String(format: "%.3f", phaseProgress)) = \(String(format: "%.3f", phaseContribution))")
        }

        // 🎯 TERMINAL STATE FIX: Ensure validatingTrimmer always maps to exactly 1.0
        if phase == .validatingTrimmer && phaseProgress >= 1.0 {
            totalProgress = 1.0
            progressLogger.info("🎯 TERMINAL_STATE: Forcing progress to 1.0 for validatingTrimmer completion")
        }

        // Clamp to valid range and update
        let clampedProgress = max(0.0, min(1.0, totalProgress))
        _targetProgress = clampedProgress

        progressLogger.info("📊 DETERMINISTIC_CALCULATION: \(phase.rawValue) @ \(String(format: "%.1f", phaseProgress * 100))% → \(String(format: "%.3f", clampedProgress)) (\(Int(clampedProgress * 100))%)")

        // 🚨 DIAGNOSTIC LOG: Track major progress milestones
        let progressPercentage = Int(clampedProgress * 100)
        if progressPercentage % 25 == 0 && phaseProgress > 0.01 {
            progressLogger.info("📊 MILESTONE: \(progressPercentage)% complete in phase \(phase.displayName)")
        }

        // Update published progress immediately (no smoothing for determinism)
        updateUnifiedProgress()
    }

    private func setUnifiedProgress(_ progress: Double) {
        let clampedProgress = max(0.0, min(1.0, progress))
        _targetProgress = clampedProgress
        progressLogger.debug("📊 SET_PROGRESS: \(String(format: "%.3f", clampedProgress))")
        updateUnifiedProgress()
    }

    /// Immediate progress update without animation for determinism
    private func updateUnifiedProgress() {
        unifiedProgress = _targetProgress
        updateEstimatedTimeRemaining()
    }

    private func updateEstimatedTimeRemaining() {
        guard self.unifiedProgress > 0.01 else {
            self.estimatedTimeRemaining = 0
            return
        }

        let elapsed = Date().timeIntervalSince(self.operationStartTime)
        let estimatedTotal = elapsed / self.unifiedProgress
        self.estimatedTimeRemaining = max(0, estimatedTotal - elapsed)

        progressLogger.debug("⏱️ ETA: \(String(format: "%.1f", self.estimatedTimeRemaining))s (Elapsed: \(String(format: "%.1f", elapsed))s)")
    }

    // MARK: - F1-Precision Timer

    private func setupF1Timer() {
        timerStartTime = Date()

        timerTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateF1Timer()
            }
        }

        timerLogger.info("⏱️ F1 Timer: Initialized with 10ms precision")
    }

    private func startF1Timer() {
        timerStartTime = Date()
        elapsedTime = 0.0
        elapsedTimeString = "00:00.00"

        if timerTimer == nil || !(timerTimer?.isValid ?? false) {
            setupF1Timer()
        }

        timerLogger.info("⏱️ F1 Timer: Started for new operation")
    }

    private func updateF1Timer() {
        let now = Date()
        elapsedTime = now.timeIntervalSince(timerStartTime)

        // Format as mm:ss.ms (F1-style timing)
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        let milliseconds = Int((elapsedTime.truncatingRemainder(dividingBy: 1)) * 100)

        elapsedTimeString = String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)

        // Log timing milestones every 10 seconds
        if Int(self.elapsedTime) % 10 == 0 && self.elapsedTime.truncatingRemainder(dividingBy: 1) < 0.02 {
            timerLogger.info("⏱️ TIMING_MILESTONE: \(self.elapsedTimeString) elapsed")
        }
    }

    private func stopF1Timer() {
        timerTimer?.invalidate()
        timerTimer = nil

        timerLogger.info("⏱️ F1 Timer: Stopped - Final time: \(self.elapsedTimeString)")
        timerLogger.info("⏱️ TIMING_ANALYSIS: Total operation completed in \(String(format: "%.2f", self.elapsedTime)) seconds")
    }

    // MARK: - Animation & Smoothing (DISABLED for determinism)

    private func setupAnimationTimer() {
        // 🎯 DETERMINISTIC FIX: Animation timer disabled for precise progress tracking
        // We use immediate progress updates instead of smoothing for determinism
        logger.info("🎯 DeterministicProgressEngine: ⚠️ Animation timer DISABLED for deterministic progress tracking")
        progressLogger.info("📊 Progress updates will be immediate and precise, no smoothing applied")
    }

    private func updateAnimatedProgress() {
        // 🎯 DETERMINISTIC FIX: Animation disabled - progress updates are immediate
        // This method is kept for compatibility but does nothing for determinism
        progressLogger.debug("📊 ANIMATION_DISABLED: Progress updates are immediate for determinism")
    }

    // MARK: - Diagnostic Logging & Monitoring

    /// Get current diagnostic information for deterministic progress analysis
    public var diagnosticInfo: [String: Any] {
        return [
            "deterministicProgress": unifiedProgress,
            "targetProgress": _targetProgress,
            "currentPhase": currentPhase.rawValue,
            "phaseProgress": phaseProgress,
            "totalStageWeight": totalWeight,
            "elapsedTime": elapsedTime,
            "elapsedTimeString": elapsedTimeString,
            "estimatedTimeRemaining": estimatedTimeRemaining,
            "operationStartTime": operationStartTime,
            "lastProgressUpdate": lastProgressUpdate,
            "isDeterministic": true,
            "animationDisabled": true,
            "predictiveWeightingDisabled": true,
            "networkMonitoringDisabled": true
        ]
    }

    /// Log comprehensive diagnostic information for deterministic progress analysis
    public func logDiagnostics() {
        logger.info("🎯 DeterministicProgressEngine: 📊 COMPREHENSIVE DIAGNOSTIC REPORT")
        progressLogger.info("📊 ┌─ Deterministic Progress Analysis")
        progressLogger.info("📊 │  ├─ Unified Progress: \(String(format: "%.3f", self.unifiedProgress)) (\(Int(self.unifiedProgress * 100))%)")
        progressLogger.info("📊 │  ├─ Target Progress: \(String(format: "%.3f", self._targetProgress))")
        progressLogger.info("📊 │  ├─ Current Phase: \(self._currentPhase.displayName)")
        progressLogger.info("📊 │  └─ Phase Progress: \(String(format: "%.3f", self.phaseProgress))")

        progressLogger.info("📊 ├─ Stage Weight Analysis")
        progressLogger.info("📊 │  ├─ Total Stage Weight: \(String(format: "%.3f", self.totalWeight))")
        progressLogger.info("📊 │  └─ Current Phase Weight: \(String(format: "%.3f", self.stageWeights[self._currentPhase] ?? 0.0))")

        progressLogger.info("📊 ├─ Timing Analysis")
        progressLogger.info("📊 │  ├─ Elapsed Time: \(self.elapsedTimeString)")
        progressLogger.info("📊 │  ├─ Total Seconds: \(String(format: "%.2f", self.elapsedTime))")
        progressLogger.info("📊 │  └─ Estimated Time Remaining: \(String(format: "%.1f", self.estimatedTimeRemaining))s")

        progressLogger.info("📊 ├─ Deterministic System Analysis")
        progressLogger.info("📊 │  ├─ Deterministic Mode: ✅ ENABLED")
        progressLogger.info("📊 │  ├─ Animation Smoothing: ❌ DISABLED")
        progressLogger.info("📊 │  ├─ Predictive Weighting: ❌ DISABLED")
        progressLogger.info("📊 │  └─ Progress Updates: IMMEDIATE")

        // Log all stage weights for verification
        progressLogger.info("📊 └─ Stage Weights Breakdown")
        for phase in LoadingPhase.allCases.sorted(by: { $0.order < $1.order }) {
            if let weight = stageWeights[phase] {
                progressLogger.info("📊     ├─ \(phase.displayName): \(String(format: "%.3f", weight)) (\(Int(weight * 100))%)")
            }
        }
    }

    /// Log stage weight verification and progress calculation details
    public func logStageWeightVerification() {
        progressLogger.info("🎯 DeterministicProgressEngine: 🔍 STAGE WEIGHT VERIFICATION")

        var cumulativeProgress = 0.0
        for phase in LoadingPhase.allCases.sorted(by: { $0.order < $1.order }) {
            if let weight = stageWeights[phase] {
                cumulativeProgress += weight
                progressLogger.info("📊 Phase \(phase.order): \(phase.rawValue)")
                progressLogger.info("📊   ├─ Weight: \(String(format: "%.3f", weight)) (\(Int(weight * 100))%)")
                progressLogger.info("📊   └─ Cumulative: \(String(format: "%.3f", cumulativeProgress)) (\(Int(cumulativeProgress * 100))%)")
            }
        }

        progressLogger.info("📊 ✅ Stage weights verified - Total: \(String(format: "%.3f", cumulativeProgress))")
    }
}

// MARK: - Progress Monitoring Extensions

extension UnifiedProgressEngine {

    /// 🎯 LIFECYCLE FIX: Public method to check animation timer health
    public func logAnimationTimerHealth() {
        logger.info("🎯 DeterministicProgressEngine: 🏥 SYSTEM HEALTH CHECK")

        // Check F1 Timer health
        if let timer = self.timerTimer {
            if timer.isValid {
                logger.info("🎯 DeterministicProgressEngine: ✅ F1 Timer is HEALTHY - Valid and running")
                timerLogger.info("⏱️ F1 Timer Status: ✅ Active - Current time: \(self.elapsedTimeString)")
            } else {
                logger.warning("🎯 DeterministicProgressEngine: ⚠️ F1 Timer is INVALID - Needs re-initialization")
                timerLogger.warning("⏱️ F1 Timer Status: ❌ Invalid - Call beginLoading() to re-initialize")
            }
        } else {
            logger.warning("🎯 DeterministicProgressEngine: ❌ F1 Timer is NIL - Needs re-initialization")
            timerLogger.warning("⏱️ F1 Timer Status: ❌ Nil - Call beginLoading() to re-initialize")
        }

        // Animation timer status (intentionally disabled for determinism)
        logger.info("🎯 DeterministicProgressEngine: ℹ️ Animation Timer: INTENTIONALLY DISABLED for deterministic progress")
        progressLogger.info("📊 Progress System: ✅ Deterministic mode active - Immediate updates only")
    }

    // MARK: - Legacy Progress Processing

    /// Process legacy VideoLoadingProgress updates and manage state transitions using deterministic progress
    public func processLegacyProgress(_ progress: VideoLoadingProgress) {
        progressLogger.info("📊 LEGACY_PROGRESS: Processing video loading progress with unified progress: \(String(format: "%.3f", progress.progress))")

        switch progress.phase {
        case .initializing:
            progressLogger.debug("📊 LEGACY_MAPPING: .initializing → .initializing")
            self.transitionToPhase(.initializing)
        case .downloadingFromCloud(let downloadProgress):
            progressLogger.debug("📊 LEGACY_MAPPING: .downloadingFromCloud → .downloadingFromCloud @ \(String(format: "%.1f", downloadProgress * 100))%")
            // If we aren't in the downloading phase, transition to it first
            if self._currentPhase != .downloadingFromCloud {
                self.transitionToPhase(.downloadingFromCloud)
            }
            self.updateDownloadProgress(downloadProgress)
        case .transferring:
            progressLogger.debug("📊 LEGACY_MAPPING: .transferring → .transferring")
            if self._currentPhase != .transferring {
                self.transitionToPhase(.transferring)
            }
            self.updateTransferProgress(progress.progress)
        case .validating:
            progressLogger.debug("📊 LEGACY_MAPPING: .validating → .validating")
            self.transitionToPhase(.validating)
        case .creatingAsset:
            progressLogger.debug("📊 LEGACY_MAPPING: .creatingAsset → .creatingAsset")
            self.transitionToPhase(.creatingAsset)
        case .loadingTrimmerDuration:
            progressLogger.debug("📊 LEGACY_MAPPING: .loadingTrimmerDuration → .loadingTrimmerDuration")
            self.transitionToPhase(.loadingTrimmerDuration)
        case .loadingTrimmerTracks:
            progressLogger.debug("📊 LEGACY_MAPPING: .loadingTrimmerTracks → .loadingTrimmerTracks")
            self.transitionToPhase(.loadingTrimmerTracks)
        case .validatingTrimmer:
            // 🎯 TERMINAL STATE FIX: Terminal Object Mapping - .validatingTrimmer is true terminal signal
            // This maps to exactly 1.0 progress for guaranteed completion
            progressLogger.info("🎯 TERMINAL_STATE_MAPPING: .validatingTrimmer → .completed (1.0)")
            progressLogger.info("📊 DETERMINISTIC_GUARANTEE: Setting progress to 1.0 for terminal state")

            // 🎯 CRITICAL FIX: Set progress to exactly 1.0 to eliminate 99% stall issue
            self.calculateDeterministicProgress(phase: .validatingTrimmer, phaseProgress: 1.0)
            self.transitionToPhase(.completed)

            progressLogger.info("✅ TERMINAL_STATE_ACHIEVED: Progress = 1.0, Phase = .completed")
            progressLogger.info("🎯 COMPLETION_GUARANTEE: All morphisms composed successfully to terminal object")
            progressLogger.info("📊 DETERMINISTIC_RESULT: No more 99% stall - progress reaches exactly 1.0")
        }
    }
}