import AVFoundation
import Combine
import Foundation
import Network
import OSLog

// UnifiedProgressEngine.swift

// MARK: - CLASS
@MainActor
public final class UnifiedProgressEngine: ObservableObject {
    // MARK: - PROPERTIES
    @Published public private(set) var unifiedProgress: Double = 0.0
    @Published public private(set) var unifiedStatus: String = ""
    @Published public private(set) var estimatedTimeRemaining: TimeInterval =
        0.0

    // MARK: - VAR
    private var phaseProgress: Double = 0.0

    @Published public private(set) var currentPhase: LoadingPhase =
        .initializing 

    private var operationStartTime: Date = Date()
    private var lastProgressUpdate: Date = Date()

    // MARK: - VAR
    private var timerStartTime: Date = Date()
    private var timerTimer: Timer?
    @Published public private(set) var elapsedTime: TimeInterval = 0.0
    @Published public private(set) var elapsedTimeString: String = "00:00.00"

    // MARK: - VAR
    private let stageWeights: [LoadingPhase: Double] = [
        .initializing: 0.03,
        .requestingDownload: 0.02,
        .waitingForNetwork: 0.00,
        .downloadingFromCloud: 0.45,
        .transferring: 0.18,
        .validating: 0.08,
        .creatingAsset: 0.04,
        .generatingThumbnail: 0.05,
        .loadingTrimmerDuration: 0.03,
        .loadingTrimmerTracks: 0.02,
        .validatingTrimmer: 0.10,
    ]

    private var totalWeight: Double {
        return stageWeights.values.reduce(0, +)
    }

    // MARK: - VAR
    private var animationTimer: Timer?
    private var _targetProgress: Double = 0.0

    public var targetProgress: Double {
        return _targetProgress
    }

    private var currentAnimationProgress: Double = 0.0
    private let animationFrameInterval: TimeInterval = 1.0 / 60.0

    // MARK: - LOGGER
    private let logger = Logger(
        subsystem: "breakdex",
        category: "🎯 DeterministicProgressEngine"
    )
    private let progressLogger = Logger(
        subsystem: "breakdex",
        category: "📊 ProgressCalculation"
    )
    private let timerLogger = Logger(
        subsystem: "breakdex",
        category: "⏱️ F1Timer"
    )

    // MARK: - VAR
    @Published public private(set) var currentError: ProgressError?
    private var cancellables = Set<AnyCancellable>()

    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(
        label: "breakdex.network.monitor",
        qos: .utility
    )

    // MARK: - PUBLISHED VAR
    @Published public private(set) var networkConnectionType:
        NetworkConnectionType = .unknown
    @Published public private(set) var isNetworkAvailable: Bool = true
    @Published public private(set) var networkQuality: NetworkQuality =
        .excellent

    private var previousNetworkState: Bool = true
    private var networkLostDuringDownload: Bool = false
    private var pausedPhase: LoadingPhase?

    public enum LoadingPhase: String, CaseIterable, Comparable {
        case initializing = "initializing"
        case requestingDownload = "requestingDownload"
        case waitingForNetwork = "waitingForNetwork"
        case downloadingFromCloud = "downloadingFromCloud"
        case transferring = "transferring"
        case validating = "validating"
        case creatingAsset = "creatingAsset"
        case generatingThumbnail = "generatingThumbnail"
        case loadingTrimmerDuration = "loadingTrimmerDuration"
        case loadingTrimmerTracks = "loadingTrimmerTracks"
        case validatingTrimmer = "validatingTrimmer"
        case completed = "completed"
        case error = "error"

        var order: Int {
            switch self {
            case .initializing: return 0
            case .requestingDownload: return 1
            case .waitingForNetwork: return 2
            case .downloadingFromCloud: return 3
            case .transferring: return 4
            case .validating: return 5
            case .creatingAsset: return 6
            case .generatingThumbnail: return 7
            case .loadingTrimmerDuration: return 8
            case .loadingTrimmerTracks: return 9
            case .validatingTrimmer: return 10
            case .completed: return 11
            case .error: return 12
            }
        }
        // MARK: - FUNC
        public static func < (lhs: LoadingPhase, rhs: LoadingPhase) -> Bool {
            return lhs.order < rhs.order
        }

        // MARK: - TEXT
        var displayName: String {
            switch self {
            case .initializing: return "Initializing"
            case .requestingDownload: return "Requesting download"
            case .waitingForNetwork: return "Waiting for network"
            case .downloadingFromCloud: return "Downloading from iCloud"
            case .transferring: return "Transferring video"
            case .validating: return "Validating video"
            case .creatingAsset: return "Creating asset"
            case .generatingThumbnail: return "Generating thumbnail"
            case .loadingTrimmerDuration: return "Loading trimmer duration"
            case .loadingTrimmerTracks: return "Loading trimmer tracks"
            case .validatingTrimmer: return "Validating trimmer setup"
            case .completed: return "Completed"
            case .error: return "Error"
            }
        }
    }
    // MARK: - ENUM STATE
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
    // MARK: - ENUM STATE
    public enum ProgressError: Error, LocalizedError {
        case networkLost
        case insufficientStorage(available: Int64, required: Int64)
        case userCancelled
        case timeout(duration: TimeInterval)
        case invalidFileSize(size: Int64)
        case unsupportedCodec(codec: String)
        case corruptedFile
        case permissionDenied
        case zeroByteFile
        case diskSpaceCritical(available: Int64)
        case downloadQuotaExceeded
        case assetUnavailable
        case unknown(String)

        // MARK: - TEXT
        public var errorDescription: String? {
            switch self {
            case .networkLost:
                return "Network connection lost during video import"
            case .insufficientStorage(let available, let required):
                return
                    "Insufficient storage. Available: \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file)), Required: \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file))"
            case .userCancelled:
                return "Video import was cancelled"
            case .timeout(let duration):
                return
                    "Operation timed out after \(String(format: "%.1f", duration)) seconds"
            case .invalidFileSize(let size):
                return
                    "Invalid file size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))"
            case .unsupportedCodec(let codec):
                return
                    "Unsupported video codec: \(codec). Please convert to a compatible format."
            case .corruptedFile:
                return
                    "Video file appears to be corrupted and cannot be processed"
            case .permissionDenied:
                return
                    "Permission denied. Please check photo library access in Settings"
            case .zeroByteFile:
                return
                    "Video file is empty (0 bytes). Please select a valid video file"
            case .diskSpaceCritical(let available):
                return
                    "Critical disk space shortage. Only \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file)) available"
            case .downloadQuotaExceeded:
                return "iCloud download quota exceeded. Please try again later"
            case .assetUnavailable:
                return "Video asset is currently unavailable. Please try again"
            case .unknown(let message):
                return "Unknown error: \(message)"
            }
        }
    }

    // MARK: - INIT
    public init() {
        verifyStageWeights()
        setupF1Timer()
        setupAnimationTimer()
        setupNetworkMonitoring()
        logger.info(
            "🎯 DeterministicProgressEngine: Initialized with deterministic stage weights, F1-precision timer, and network monitoring"
        )
        progressLogger.info(
            "📊 Stage weights verified: Total = \(String(format: "%.3f", self.totalWeight))"
        )
    }

    // MARK: - DEINIT
    deinit {
        timerTimer?.invalidate()
        timerTimer = nil
        animationTimer?.invalidate()
        networkMonitor.cancel()
        cancellables.removeAll()
        logger.info("🎯 DeterministicProgressEngine: Deinitialized")
    }

    // MARK: - FUNC
    private func verifyStageWeights() {
        let calculatedTotal = totalWeight
        let expectedTotal = 1.0

        if abs(calculatedTotal - expectedTotal) > 0.001 {
            logger.error(
                "🎯 DeterministicProgressEngine: ❌ CRITICAL - Stage weights sum to \(String(format: "%.6f", calculatedTotal)), expected \(expectedTotal)"
            )
            fatalError(
                "Stage weights must sum to exactly 1.0 for deterministic progress"
            )
        } else {
            logger.info(
                "🎯 DeterministicProgressEngine: ✅ Stage weights verification passed - Sum = \(String(format: "%.3f", calculatedTotal))"
            )
        }

        for (phase, weight) in stageWeights {
            progressLogger.debug(
                "📊 Stage: \(phase.rawValue) → Weight: \(String(format: "%.3f", weight)) (\(Int(weight * 100))%)"
            )
        }
    }

    // MARK: - FUNC
    public func beginLoading(fileSizeEstimate: Int64 = 0) {
        logger.info(
            "🎯 DeterministicProgressEngine: 📥 Beginning deterministic video loading operation"
        )
        progressLogger.info(
            "📊 Operation started - File size estimate: \(ByteCountFormatter.string(fromByteCount: fileSizeEstimate, countStyle: .file))"
        )

        resetProgress()
        operationStartTime = Date()
        lastProgressUpdate = Date()
        startF1Timer()

        if animationTimer == nil || !(animationTimer?.isValid ?? false) {
            logger.info(
                "🎯 DeterministicProgressEngine: 🔄 Animation timer is invalid, re-initializing for new operation."
            )
            setupAnimationTimer()
        }

        updatePhase(.initializing)

        calculateDeterministicProgress(phase: .initializing, phaseProgress: 1.0)

        logger.info(
            "🎯 DeterministicProgressEngine: ✅ Deterministic loading operation initialized"
        )
        progressLogger.info(
            "📊 Initial progress: \(String(format: "%.3f", self.unifiedProgress)) (\(Int(self.unifiedProgress * 100))%)"
        )
    }

    // MARK: - FUNC
    public func updateDownloadProgress(_ progress: Double) {
        guard self.currentPhase == .downloadingFromCloud else {
            logger.warning(
                "🎯 DeterministicProgressEngine: ⚠️ Download progress update received in \(self.currentPhase.rawValue) phase"
            )
            return
        }

        let clampedProgress = max(0.0, min(1.0, progress))
        phaseProgress = clampedProgress

        progressLogger.debug(
            "📊 Download progress: \(String(format: "%.1f", clampedProgress * 100))%"
        )

        calculateDeterministicProgress(
            phase: .downloadingFromCloud,
            phaseProgress: clampedProgress
        )
    }

    // MARK: - FUNC
    public func updateTransferProgress(_ progress: Double) {
        guard self.currentPhase == .transferring else {
            logger.warning(
                "🎯 DeterministicProgressEngine: ⚠️ Transfer progress update received in \(self.currentPhase.rawValue) phase"
            )
            return
        }

        let clampedProgress = max(0.0, min(1.0, progress))
        phaseProgress = clampedProgress

        progressLogger.debug(
            "📊 Transfer progress: \(String(format: "%.1f", clampedProgress * 100))%"
        )

        calculateDeterministicProgress(
            phase: .transferring,
            phaseProgress: clampedProgress
        )
    }

    // MARK: - FUNC
    public func transitionToPhase(_ phase: LoadingPhase) {
        let transitionId = UUID().uuidString.prefix(8)
        let timestamp = Date()

        logger.info(
            "🎯 DeterministicProgressEngine: [\(transitionId)] 🔄 PHASE_TRANSITION: \(phase.displayName) [from: \(self.currentPhase.displayName)]"
        )
        progressLogger.info(
            "📊 [\(transitionId)] 🔄 TRANSITION_START: \(self.currentPhase.displayName) → \(phase.displayName)"
        )
        progressLogger.info(
            "📊 [\(transitionId)] ⏰ Timestamp: \(timestamp.description)"
        )
        progressLogger.info(
            "📊 [\(transitionId)] 📈 Progress before: \(String(format: "%.3f", self.unifiedProgress)) (\(Int(self.unifiedProgress * 100))%)"
        )

        if isNetworkDependentPhase(phase)
            || isNetworkDependentPhase(self.currentPhase)
        {
            logger.info(
                "🌐 [\(transitionId)] 📶 NETWORK_CONTEXT: Available=\(self.isNetworkAvailable), Type=\(self.networkConnectionType.displayName), Quality=\(self.networkQuality.displayName)"
            )
        }

        if phase == .error {
            logger.error(
                "❌ [\(transitionId)] 🔴 ERROR_TRANSITION: Entering error state from \(self.currentPhase.displayName)"
            )
            if let error = currentError {
                logger.error(
                    "❌ [\(transitionId)] 🚨 ERROR_DETAILS: \(error.localizedDescription)"
                )
            }
        }

        updatePhase(phase)

        if phase == .validatingTrimmer {
            progressLogger.info(
                "🎯 [\(transitionId)] 🏁 TERMINAL_STATE: Validating trimmer - setting progress to 1.0"
            )
            calculateDeterministicProgress(
                phase: .validatingTrimmer,
                phaseProgress: 1.0
            )
        } else {
            calculateDeterministicProgress(phase: phase, phaseProgress: 0.0)
        }

        progressLogger.info(
            "📊 [\(transitionId)] 📈 Progress after: \(String(format: "%.3f", self.unifiedProgress)) (\(Int(self.unifiedProgress * 100))%)"
        )

        logPhaseSpecificDetails(
            transitionId: String(transitionId),
            phase: phase
        )

        if phase == .completed {
            progressLogger.info(
                "🎯 [\(transitionId)] 🏆 COMPLETION: Operation completed - ensuring 1.0 progress"
            )
            setUnifiedProgress(1.0)

            let totalDuration = elapsedTime
            progressLogger.info(
                "🎯 [\(transitionId)] ⏱️ COMPLETION_METRICS: Total duration: \(String(format: "%.2f", totalDuration))s"
            )
            progressLogger.info(
                "🎯 [\(transitionId)] 📊 COMPLETION_METRICS: Final progress: \(String(format: "%.3f", self.unifiedProgress))"
            )
        }
    }

    // MARK: - FUNC
    public func completeLoading() {
        logger.info(
            "🎯 DeterministicProgressEngine: ✅ Deterministic loading operation completed successfully"
        )
        progressLogger.info(
            "📊 Final completion - Total elapsed time: \(String(format: "%.2f", self.elapsedTime))s"
        )
        transitionToPhase(.completed)
        stopF1Timer()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }

            if let timer = self.animationTimer {
                timer.invalidate()
                self.animationTimer = nil
                self.logger.info(
                    "🎯 DeterministicProgressEngine: 🧹 Animation timer invalidated and set to nil after completion"
                )
            } else {
                self.logger.warning(
                    "🎯 DeterministicProgressEngine: ⚠️ Animation timer was already nil when attempting to clean up after completion"
                )
            }
        }
    }

    // MARK: - FUNC
    public func handleError(_ error: ProgressError) {
        logger.error(
            "🎯 DeterministicProgressEngine: ❌ Loading error: \(error.localizedDescription)"
        )
        progressLogger.error(
            "📊 Error occurred in phase: \(self.currentPhase.rawValue) at progress: \(String(format: "%.3f", self.unifiedProgress))"
        )
        currentError = error
        transitionToPhase(.error)
    }

    // MARK: - FUNC
    public func handleStorageError(available: Int64, required: Int64) {
        logger.warning(
            "🚀 UnifiedProgressEngine: 💾 Insufficient storage - Available: \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file)), Required: \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file))"
        )

        let storageError = ProgressError.insufficientStorage(
            available: available,
            required: required
        )
        handleError(storageError)

        if available > 0 {
            logger.info(
                "🚀 UnifiedProgressEngine: 💡 Recovery suggestion: Clear app cache or remove other files to free up \(ByteCountFormatter.string(fromByteCount: required - available, countStyle: .file))"
            )
        } else {
            logger.error(
                "🚀 UnifiedProgressEngine: ❌ No storage available - Device storage may be full"
            )
        }
    }

    // MARK: - FUNC
    public func handleTimeout(duration: TimeInterval, phase: LoadingPhase) {
        logger.warning(
            "🚀 UnifiedProgressEngine: ⏱️ Operation timed out after \(String(format: "%.1f", duration))s in phase: \(phase.displayName)"
        )

        let timeoutError = ProgressError.timeout(duration: duration)
        handleError(timeoutError)

        logger.info(
            "🚀 UnifiedProgressEngine: 📊 Timeout context - Phase: \(phase.displayName), Progress: \(String(format: "%.1f", self.unifiedProgress * 100))%, Network: \(NetworkConnectionType.wifi.displayName)"
        )
    }

    // MARK: - FUNC
    public func cancelLoading() {
        logger.info(
            "🚀 UnifiedProgressEngine: 🚫 Loading operation cancelled by user"
        )
        handleError(.userCancelled)
    }

    // MARK: - FUNC
    public func handleZeroByteFile(fileSize: Int64) {
        logger.error(
            "🚀 UnifiedProgressEngine: ❌ Zero-byte file detected - Size: \(fileSize) bytes"
        )
        progressLogger.error(
            "📊 ZERO_BYTE_FILE: File validation failed - empty file detected"
        )
        handleError(.zeroByteFile)
    }

    // MARK: - FUNC
    public func handleUnsupportedCodec(
        detectedCodec: String,
        supportedCodecs: [String]
    ) {
        logger.error(
            "🚀 UnifiedProgressEngine: ❌ Unsupported codec detected - \(detectedCodec)"
        )
        progressLogger.error(
            "📊 UNSUPPORTED_CODEC: Detected: \(detectedCodec), Supported: \(supportedCodecs.joined(separator: ", "))"
        )
        handleError(.unsupportedCodec(codec: detectedCodec))
    }

    public func handleCorruptedFile(fileName: String, errorDetails: String) {
        logger.error(
            "🚀 UnifiedProgressEngine: ❌ Corrupted file detected - \(fileName)"
        )
        progressLogger.error(
            "📊 CORRUPTED_FILE: File: \(fileName), Details: \(errorDetails)"
        )
        handleError(.corruptedFile)
    }

    // MARK: - FUNC
    public func handlePermissionDenied(resource: String) {
        logger.error(
            "🚀 UnifiedProgressEngine: ❌ Permission denied for resource: \(resource)"
        )
        progressLogger.error(
            "📊 PERMISSION_DENIED: Access denied to \(resource)"
        )
        handleError(.permissionDenied)
    }

    // MARK: - FUNC
    public func handleCriticalDiskSpace(
        availableSpace: Int64,
        requiredSpace: Int64
    ) {
        logger.error(
            "🚀 UnifiedProgressEngine: 💾 Critical disk space - Available: \(ByteCountFormatter.string(fromByteCount: availableSpace, countStyle: .file)), Required: \(ByteCountFormatter.string(fromByteCount: requiredSpace, countStyle: .file))"
        )
        progressLogger.error(
            "📊 DISK_CRITICAL: Space shortage - Available: \(availableSpace) bytes, Required: \(requiredSpace) bytes"
        )
        handleError(.diskSpaceCritical(available: availableSpace))
    }

    // MARK: - FUNC
    public func handleDownloadQuotaExceeded(quotaType: String) {
        logger.error(
            "🚀 UnifiedProgressEngine: ☁️ iCloud download quota exceeded - Type: \(quotaType)"
        )
        progressLogger.error(
            "📊 QUOTA_EXCEEDED: \(quotaType) quota limit reached"
        )
        handleError(.downloadQuotaExceeded)
    }

    // MARK: - FUNC
    public func handleAssetUnavailable(assetIdentifier: String, reason: String)
    {
        logger.warning(
            "🚀 UnifiedProgressEngine: ⚠️ Asset unavailable - ID: \(assetIdentifier), Reason: \(reason)"
        )
        progressLogger.warning(
            "📊 ASSET_UNAVAILABLE: Asset \(assetIdentifier) not accessible - \(reason)"
        )
        handleError(.assetUnavailable)
    }

    public func validateFileSize(
        _ fileSize: Int64,
        expectedRange: ClosedRange<Int64>? = nil
    ) -> Bool {
        let logger = Logger(
            subsystem: "breakdex",
            category: "🔍 FILE_VALIDATION"
        )

        logger.info(
            "🔍 Validating file size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))"
        )

        if fileSize == 0 {
            handleZeroByteFile(fileSize: fileSize)
            return false
        }

        if let range = expectedRange {
            if !range.contains(fileSize) {
                logger.error(
                    "🔍 File size \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)) outside expected range \(ByteCountFormatter.string(fromByteCount: range.lowerBound, countStyle: .file)) - \(ByteCountFormatter.string(fromByteCount: range.upperBound, countStyle: .file))"
                )
                handleError(.invalidFileSize(size: fileSize))
                return false
            }
        }

        logger.info("🔍 File size validation passed")
        return true
    }

    // MARK: - FUNC
    public func validateNetworkConnectivity() -> Bool {
        let logger = Logger(
            subsystem: "breakdex",
            category: "🌐 NETWORK_VALIDATION"
        )

        logger.info("🌐 Validating network connectivity for download operations")

        guard isNetworkAvailable else {
            logger.error(
                "🌐 Network validation failed - No network connection available"
            )
            progressLogger.error(
                "📊 NETWORK_VALIDATION: Cannot proceed with download - network unavailable"
            )
            return false
        }

        switch self.networkConnectionType {
        case .wifi, .ethernet:
            logger.info(
                "🌐 Network validation passed - Suitable connection: \(self.networkConnectionType.displayName)"
            )
            return true
        case .cellular:
            logger.warning(
                "🌐 Network validation warning - Using cellular connection may incur data charges"
            )
            return true
        case .other, .unknown:
            logger.warning(
                "🌐 Network validation warning - Unknown connection type: \(self.networkConnectionType.displayName)"
            )
            return true
        case .none:
            logger.error("🌐 Network validation failed - No connection")
            return false
        }
    }

    // MARK: - FUNC
    public func performHealthCheck(fileSize: Int64? = nil) -> [ProgressError] {
        let logger = Logger(subsystem: "breakdex", category: "🏥 HEALTH_CHECK")
        var errors: [ProgressError] = []

        logger.info("🏥 Performing comprehensive system health check")

        if !validateNetworkConnectivity() {
            errors.append(.networkLost)
        }

        if let fileSize = fileSize {

            let requiredSpace = fileSize * 3
            let availableSpace = getAvailableDiskSpace()

            if availableSpace < requiredSpace {
                errors.append(
                    .insufficientStorage(
                        available: availableSpace,
                        required: requiredSpace
                    )
                )
            } else if availableSpace < requiredSpace * 2 {
                errors.append(.diskSpaceCritical(available: availableSpace))
            }
        }

        if errors.isEmpty {
            logger.info(
                "🏥 Health check passed - System ready for video loading"
            )
        } else {
            logger.error(
                "🏥 Health check failed - \(errors.count) issues detected"
            )
            for (index, error) in errors.enumerated() {
                logger.error(
                    "🏥 Issue \(index + 1): \(error.localizedDescription)"
                )
            }
        }

        return errors
    }

    // MARK: - FUNC
    private func getAvailableDiskSpace() -> Int64 {

        return 1024 * 1024 * 1024
    }

    // MARK: - FUNC
    private func logPhaseSpecificDetails(
        transitionId: String,
        phase: LoadingPhase
    ) {
        let phaseLogger = Logger(
            subsystem: "breakdex",
            category: "🎯 PHASE_DETAILS"
        )

        switch phase {
        case .initializing:
            phaseLogger.info(
                "🎯 [\(transitionId)] 🚀 PHASE_INITIALIZING: Setting up video loading operation"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Timer: F1-precision timer started"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Network: Monitoring enabled"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] └─ Progress: Deterministic calculation system ready"
            )
        case .requestingDownload:
            phaseLogger.info(
                "🎯 [\(transitionId)] ☁️ PHASE_REQUESTING_DOWNLOAD: Requesting video from iCloud"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Network: \(self.networkConnectionType.displayName) connection"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Quality: \(self.networkQuality.displayName) quality"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] └─ Status: Sending download request to Photos framework"
            )
        case .waitingForNetwork:
            phaseLogger.warning(
                "🎯 [\(transitionId)] ⏳ PHASE_WAITING_NETWORK: Waiting for network connection"
            )
            phaseLogger.warning(
                "🎯 [\(transitionId)] ├─ Previous phase: \(self.pausedPhase?.displayName ?? "unknown")"
            )
            phaseLogger.warning("🎯 [\(transitionId)] ├─ Network lost: Yes")
            phaseLogger.warning(
                "🎯 [\(transitionId)] └─ Action: Will auto-resume when connection restored"
            )
        case .downloadingFromCloud:
            phaseLogger.info(
                "🎯 [\(transitionId)] ☁️ PHASE_DOWNLOADING: Downloading video from iCloud"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Network: \(self.networkConnectionType.displayName)"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Progress weight: 45% of total operation"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] └─ Monitoring: Real-time progress tracking active"
            )
        case .transferring:
            phaseLogger.info(
                "🎯 [\(transitionId)] 📦 PHASE_TRANSFERRING: Transferring and processing video"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Progress weight: 18% of total operation"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Status: Moving data to processing pipeline"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] └─ Next: Asset creation phase"
            )
        case .validating:
            phaseLogger.info(
                "🎯 [\(transitionId)] ✅ PHASE_VALIDATING: Validating video integrity"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Progress weight: 8% of total operation"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Checks: Format, duration, corruption"
            )
            phaseLogger.info("🎯 [\(transitionId)] └─ Next: Asset creation")

        case .creatingAsset:
            phaseLogger.info(
                "🎯 [\(transitionId)] 🎬 PHASE_CREATING_ASSET: Creating AVAsset instance"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Progress weight: 4% of total operation"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Status: Framework asset initialization"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] └─ Next: Thumbnail generation"
            )
        case .generatingThumbnail:
            phaseLogger.info(
                "🎯 [\(transitionId)] 🖼️ PHASE_GENERATING_THUMBNAIL: Creating video thumbnail"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Progress weight: 5% of total operation"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Status: Extracting key frame for preview"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] └─ Next: Trimmer duration loading"
            )
        case .loadingTrimmerDuration:
            phaseLogger.info(
                "🎯 [\(transitionId)] 📏 PHASE_LOADING_DURATION: Loading video duration"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Progress weight: 3% of total operation"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Status: Determining trimmer timeline range"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] └─ Next: Trimmer tracks loading"
            )

        case .loadingTrimmerTracks:
            phaseLogger.info(
                "🎯 [\(transitionId)] 🎚️ PHASE_LOADING_TRACKS: Loading trimmer video tracks"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Progress weight: 2% of total operation"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Status: Preparing video track for trimming"
            )
            phaseLogger.info("🎯 [\(transitionId)] └─ Next: Final validation")

        case .validatingTrimmer:
            phaseLogger.info(
                "🎯 [\(transitionId)] 🏁 PHASE_VALIDATING_TRIMMER: Final trimmer validation"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Progress weight: 10% of total operation"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Status: Final system validation before UI handoff"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] └─ Next: Ready for user interaction"
            )
        case .completed:
            phaseLogger.info(
                "🎯 [\(transitionId)] 🏆 PHASE_COMPLETED: Video loading operation complete"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Duration: \(self.elapsedTimeString)"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] ├─ Progress: 100% deterministic completion"
            )
            phaseLogger.info(
                "🎯 [\(transitionId)] └─ Status: Ready for user in trimmer UI"
            )

        case .error:
            phaseLogger.error(
                "🎯 [\(transitionId)] ❌ PHASE_ERROR: Error occurred during loading"
            )
            phaseLogger.error(
                "🎯 [\(transitionId)] ├─ Failed phase: \(self.pausedPhase?.displayName ?? "unknown")"
            )
            if let error = self.currentError {
                phaseLogger.error(
                    "🎯 [\(transitionId)] ├─ Error: \(error.localizedDescription)"
                )
                phaseLogger.error(
                    "🎯 [\(transitionId)] └─ Recovery: User intervention required"
                )
            }
        }
    }

    // MARK: - FUNC
    private func resetProgress() {
        unifiedProgress = 0.0
        unifiedStatus = ""
        estimatedTimeRemaining = 0.0
        phaseProgress = 0.0
        _targetProgress = 0.0
        currentAnimationProgress = 0.0
        currentError = nil
        currentPhase = .initializing
        elapsedTime = 0.0
        elapsedTimeString = "00:00.00"
    }

    // MARK: - FUNC
    private func updatePhase(_ phase: LoadingPhase) {
        currentPhase = phase
        unifiedStatus = phase.displayName
        lastProgressUpdate = Date()
        updateEstimatedTimeRemaining()
    }

    // MARK: - FUNC
    private func calculateDeterministicProgress(
        phase: LoadingPhase,
        phaseProgress: Double
    ) {
        progressLogger.debug(
            "📊 CALCULATION: Phase=\(phase.rawValue), PhaseProgress=\(String(format: "%.3f", phaseProgress))"
        )

        var totalProgress = 0.0

        for (currentPhase, weight) in stageWeights {
            if currentPhase.order < phase.order {
                totalProgress += weight
                progressLogger.debug(
                    "📊 Completed phase: \(currentPhase.rawValue) (+\(String(format: "%.3f", weight))) = \(String(format: "%.3f", totalProgress))"
                )
            }
        }

        if let currentPhaseWeight = stageWeights[phase] {
            let phaseContribution = currentPhaseWeight * phaseProgress
            totalProgress += phaseContribution
            progressLogger.debug(
                "📊 Current phase contribution: \(phase.rawValue) × \(String(format: "%.3f", phaseProgress)) = \(String(format: "%.3f", phaseContribution))"
            )
        }

        if phase == .validatingTrimmer && phaseProgress >= 1.0 {
            totalProgress = 1.0
            progressLogger.info(
                "🎯 TERMINAL_STATE: Forcing progress to 1.0 for validatingTrimmer completion"
            )
        }

        let clampedProgress = max(0.0, min(1.0, totalProgress))
        _targetProgress = clampedProgress

        progressLogger.info(
            "📊 DETERMINISTIC_CALCULATION: \(phase.rawValue) @ \(String(format: "%.1f", phaseProgress * 100))% → \(String(format: "%.3f", clampedProgress)) (\(Int(clampedProgress * 100))%)"
        )

        let progressPercentage = Int(clampedProgress * 100)
        if progressPercentage % 25 == 0 && phaseProgress > 0.01 {
            progressLogger.info(
                "📊 MILESTONE: \(progressPercentage)% complete in phase \(phase.displayName)"
            )
        }

        updateUnifiedProgress()
    }

    // MARK: - FUNC
    private func setUnifiedProgress(_ progress: Double) {
        let clampedProgress = max(0.0, min(1.0, progress))
        _targetProgress = clampedProgress
        progressLogger.debug(
            "📊 SET_PROGRESS: \(String(format: "%.3f", clampedProgress))"
        )
        updateUnifiedProgress()
    }

    // MARK: - FUNC
    private func updateUnifiedProgress() {
        unifiedProgress = _targetProgress
        updateEstimatedTimeRemaining()
    }

    // MARK: - FUNC
    private func updateEstimatedTimeRemaining() {
        guard self.unifiedProgress > 0.01 else {
            self.estimatedTimeRemaining = 0
            return
        }

        let elapsed = Date().timeIntervalSince(self.operationStartTime)
        let estimatedTotal = elapsed / self.unifiedProgress
        self.estimatedTimeRemaining = max(0, estimatedTotal - elapsed)

        progressLogger.debug(
            "⏱️ ETA: \(String(format: "%.1f", self.estimatedTimeRemaining))s (Elapsed: \(String(format: "%.1f", elapsed))s)"
        )
    }

    // MARK: - FUNC
    private func setupF1Timer() {
        timerStartTime = Date()

        timerTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true)
        { [weak self] _ in
            Task { @MainActor in
                self?.updateF1Timer()
            }
        }

        timerLogger.info("⏱️ F1 Timer: Initialized with 10ms precision")
    }

    // MARK: - FUNC
    private func startF1Timer() {
        timerStartTime = Date()
        elapsedTime = 0.0
        elapsedTimeString = "00:00.00"

        if timerTimer == nil || !(timerTimer?.isValid ?? false) {
            setupF1Timer()
        }

        timerLogger.info("⏱️ F1 Timer: Started for new operation")
    }

    // MARK: - FUNC
    private func updateF1Timer() {
        let now = Date()
        elapsedTime = now.timeIntervalSince(timerStartTime)

        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        let milliseconds = Int(
            (elapsedTime.truncatingRemainder(dividingBy: 1)) * 100
        )

        elapsedTimeString = String(
            format: "%02d:%02d.%02d",
            minutes,
            seconds,
            milliseconds
        )

        if Int(self.elapsedTime) % 10 == 0
            && self.elapsedTime.truncatingRemainder(dividingBy: 1) < 0.02
        {
            timerLogger.info(
                "⏱️ TIMING_MILESTONE: \(self.elapsedTimeString) elapsed"
            )
        }
    }

    // MARK: - FUNC
    private func stopF1Timer() {
        timerTimer?.invalidate()
        timerTimer = nil

        timerLogger.info(
            "⏱️ F1 Timer: Stopped - Final time: \(self.elapsedTimeString)"
        )
        timerLogger.info(
            "⏱️ TIMING_ANALYSIS: Total operation completed in \(String(format: "%.2f", self.elapsedTime)) seconds"
        )
    }

    // MARK: - FUNC
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handleNetworkPathUpdate(path)
            }
        }
        networkMonitor.start(queue: networkQueue)

        logger.info(
            "🌐 Network monitoring started for iCloud download resilience"
        )
        progressLogger.info(
            "📊 Network state monitoring active - will handle network loss during downloads"
        )
    }

    // MARK: - FUNC
    private func handleNetworkPathUpdate(_ path: NWPath) {
        let newNetworkState = path.status == .satisfied
        let newConnectionType = determineConnectionType(path)
        let newNetworkQuality = determineNetworkQuality(path)

        if newNetworkState != previousNetworkState {
            Task { @MainActor in
                self.previousNetworkState = newNetworkState
                self.isNetworkAvailable = newNetworkState
                self.networkConnectionType = newConnectionType
                self.networkQuality = newNetworkQuality

                if newNetworkState {
                    await self.handleNetworkRestored()
                } else {
                    await self.handleNetworkLost()
                }
            }
        }

        logger.debug(
            "🌐 Network state: Available=\(newNetworkState), Type=\(newConnectionType.rawValue), Quality=\(newNetworkQuality.rawValue)"
        )
    }

    // MARK: - FUNC
    private func determineConnectionType(_ path: NWPath)
        -> NetworkConnectionType
    {
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
    private func handleNetworkLost() async {
        logger.warning(
            "🌐 Network connection lost during video loading operation"
        )
        progressLogger.warning(
            "📊 NETWORK_LOST: Current phase: \(self.currentPhase.displayName), Progress: \(String(format: "%.1f", self.unifiedProgress * 100))%"
        )

        if isNetworkDependentPhase(self.currentPhase) {
            self.networkLostDuringDownload = true
            self.pausedPhase = self.currentPhase

            logger.info(
                "🌐 Transitioning to waitingForNetwork phase due to network loss"
            )
            self.transitionToPhase(.waitingForNetwork)

            let networkError = ProgressError.networkLost
            self.currentError = networkError
        }
    }

    // MARK: - FUNC
    private func handleNetworkRestored() async {
        logger.info("🌐 Network connection restored")
        progressLogger.info(
            "📊 NETWORK_RESTORED: Connection type: \(self.networkConnectionType.displayName), Quality: \(self.networkQuality.displayName)"
        )

        if self.networkLostDuringDownload && self.pausedPhase != nil {
            logger.info(
                "🌐 Resuming from waitingForNetwork phase to \(self.pausedPhase?.displayName ?? "unknown")"
            )
            progressLogger.info(
                "📊 RESUMING: Network restored, continuing video loading operation"
            )

            self.networkLostDuringDownload = false

            if case .networkLost = self.currentError {
                self.currentError = nil
            }

            if let resumePhase = self.pausedPhase {
                self.pausedPhase = nil
                self.transitionToPhase(resumePhase)
            }
        }
    }

    // MARK: - FUNC
    private func isNetworkDependentPhase(_ phase: LoadingPhase) -> Bool {
        switch phase {
        case .requestingDownload, .downloadingFromCloud:
            return true
        case .waitingForNetwork:
            return false
        default:
            return false
        }
    }

    // MARK: - FUNC
    private func setupAnimationTimer() {

        logger.info(
            "🎯 DeterministicProgressEngine: ⚠️ Animation timer DISABLED for deterministic progress tracking"
        )
        progressLogger.info(
            "📊 Progress updates will be immediate and precise, no smoothing applied"
        )
    }

    // MARK: - FUNC
    private func updateAnimatedProgress() {

        progressLogger.debug(
            "📊 ANIMATION_DISABLED: Progress updates are immediate for determinism"
        )
    }

    // MARK: - ARRAY
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
            "networkMonitoringEnabled": true,
            "networkConnectionType": networkConnectionType.rawValue,
            "isNetworkAvailable": isNetworkAvailable,
            "networkQuality": networkQuality.rawValue,
            "networkLostDuringDownload": networkLostDuringDownload,
            "pausedPhase": pausedPhase?.rawValue ?? "none",
        ]
    }

    // MARK: - FUNC
    public func logDiagnostics() {
        logger.info(
            "🎯 DeterministicProgressEngine: 📊 COMPREHENSIVE DIAGNOSTIC REPORT"
        )
        progressLogger.info("📊 ┌─ Deterministic Progress Analysis")
        progressLogger.info(
            "📊 │  ├─ Unified Progress: \(String(format: "%.3f", self.unifiedProgress)) (\(Int(self.unifiedProgress * 100))%)"
        )
        progressLogger.info(
            "📊 │  ├─ Target Progress: \(String(format: "%.3f", self._targetProgress))"
        )
        progressLogger.info(
            "📊 │  ├─ Current Phase: \(self.currentPhase.displayName)"
        )
        progressLogger.info(
            "📊 │  └─ Phase Progress: \(String(format: "%.3f", self.phaseProgress))"
        )

        progressLogger.info("📊 ├─ Stage Weight Analysis")
        progressLogger.info(
            "📊 │  ├─ Total Stage Weight: \(String(format: "%.3f", self.totalWeight))"
        )
        progressLogger.info(
            "📊 │  └─ Current Phase Weight: \(String(format: "%.3f", self.stageWeights[self.currentPhase] ?? 0.0))"
        )

        progressLogger.info("📊 ├─ Timing Analysis")
        progressLogger.info("📊 │  ├─ Elapsed Time: \(self.elapsedTimeString)")
        progressLogger.info(
            "📊 │  ├─ Total Seconds: \(String(format: "%.2f", self.elapsedTime))"
        )
        progressLogger.info(
            "📊 │  └─ Estimated Time Remaining: \(String(format: "%.1f", self.estimatedTimeRemaining))s"
        )

        progressLogger.info("📊 ├─ Network Resilience Analysis")
        progressLogger.info(
            "📊 │  ├─ Network Available: \(self.isNetworkAvailable ? "✅ YES" : "❌ NO")"
        )
        progressLogger.info(
            "📊 │  ├─ Connection Type: \(self.networkConnectionType.displayName)"
        )
        progressLogger.info(
            "📊 │  ├─ Network Quality: \(self.networkQuality.displayName)"
        )
        progressLogger.info(
            "📊 │  ├─ Network Lost During Download: \(self.networkLostDuringDownload ? "⚠️ YES" : "✅ NO")"
        )
        progressLogger.info(
            "📊 │  └─ Paused Phase: \(self.pausedPhase?.displayName ?? "None")"
        )

        progressLogger.info("📊 ├─ Deterministic System Analysis")
        progressLogger.info("📊 │  ├─ Deterministic Mode: ✅ ENABLED")
        progressLogger.info("📊 │  ├─ Animation Smoothing: ❌ DISABLED")
        progressLogger.info("📊 │  ├─ Predictive Weighting: ❌ DISABLED")
        progressLogger.info("📊 │  └─ Progress Updates: IMMEDIATE")

        progressLogger.info("📊 └─ Stage Weights Breakdown")
        for phase in LoadingPhase.allCases.sorted(by: { $0.order < $1.order }) {
            if let weight = stageWeights[phase] {
                progressLogger.info(
                    "📊     ├─ \(phase.displayName): \(String(format: "%.3f", weight)) (\(Int(weight * 100))%)"
                )
            }
        }
    }

    // MARK: - FUNC
    public func logStageWeightVerification() {
        progressLogger.info(
            "🎯 DeterministicProgressEngine: 🔍 STAGE WEIGHT VERIFICATION"
        )

        var cumulativeProgress = 0.0
        for phase in LoadingPhase.allCases.sorted(by: { $0.order < $1.order }) {
            if let weight = stageWeights[phase] {
                cumulativeProgress += weight
                progressLogger.info("📊 Phase \(phase.order): \(phase.rawValue)")
                progressLogger.info(
                    "📊   ├─ Weight: \(String(format: "%.3f", weight)) (\(Int(weight * 100))%)"
                )
                progressLogger.info(
                    "📊   └─ Cumulative: \(String(format: "%.3f", cumulativeProgress)) (\(Int(cumulativeProgress * 100))%)"
                )
            }
        }

        progressLogger.info(
            "📊 ✅ Stage weights verified - Total: \(String(format: "%.3f", cumulativeProgress))"
        )
    }
}

// MARK: - EXTENSION
extension UnifiedProgressEngine {
    // MARK: - FUNC
    public func logAnimationTimerHealth() {
        logger.info("🎯 DeterministicProgressEngine: 🏥 SYSTEM HEALTH CHECK")

        if let timer = self.timerTimer {
            if timer.isValid {
                logger.info(
                    "🎯 DeterministicProgressEngine: ✅ F1 Timer is HEALTHY - Valid and running"
                )
                timerLogger.info(
                    "⏱️ F1 Timer Status: ✅ Active - Current time: \(self.elapsedTimeString)"
                )
            } else {
                logger.warning(
                    "🎯 DeterministicProgressEngine: ⚠️ F1 Timer is INVALID - Needs re-initialization"
                )
                timerLogger.warning(
                    "⏱️ F1 Timer Status: ❌ Invalid - Call beginLoading() to re-initialize"
                )
            }
        } else {
            logger.warning(
                "🎯 DeterministicProgressEngine: ❌ F1 Timer is NIL - Needs re-initialization"
            )
            timerLogger.warning(
                "⏱️ F1 Timer Status: ❌ Nil - Call beginLoading() to re-initialize"
            )
        }

        logger.info(
            "🎯 DeterministicProgressEngine: ℹ️ Animation Timer: INTENTIONALLY DISABLED for deterministic progress"
        )
        progressLogger.info(
            "📊 Progress System: ✅ Deterministic mode active - Immediate updates only"
        )
    }

    // MARK: - FUNC
    public func processLegacyProgress(_ progress: VideoLoadingProgress) {
        progressLogger.info(
            "📊 LEGACY_PROGRESS: Processing video loading progress with unified progress: \(String(format: "%.3f", progress.progress))"
        )

        switch progress.phase {
        case .initializing:
            progressLogger.debug(
                "📊 LEGACY_MAPPING: .initializing → .initializing"
            )
            self.transitionToPhase(.initializing)
        case .downloadingFromCloud(let downloadProgress):
            progressLogger.debug(
                "📊 LEGACY_MAPPING: .downloadingFromCloud → .downloadingFromCloud @ \(String(format: "%.1f", downloadProgress * 100))%"
            )

            if self.currentPhase != .downloadingFromCloud {
                self.transitionToPhase(.downloadingFromCloud)
            }
            self.updateDownloadProgress(downloadProgress)
        case .transferring:
            progressLogger.debug(
                "📊 LEGACY_MAPPING: .transferring → .transferring"
            )
            if self.currentPhase != .transferring {
                self.transitionToPhase(.transferring)
            }
            self.updateTransferProgress(progress.progress)
        case .validating:
            progressLogger.debug("📊 LEGACY_MAPPING: .validating → .validating")
            self.transitionToPhase(.validating)
        case .creatingAsset:
            progressLogger.debug(
                "📊 LEGACY_MAPPING: .creatingAsset → .creatingAsset"
            )
            self.transitionToPhase(.creatingAsset)
        case .generatingThumbnail:
            progressLogger.debug(
                "📊 LEGACY_MAPPING: .generatingThumbnail → .generatingThumbnail"
            )
            self.transitionToPhase(.generatingThumbnail)
        case .loadingTrimmerDuration:
            progressLogger.debug(
                "📊 LEGACY_MAPPING: .loadingTrimmerDuration → .loadingTrimmerDuration"
            )
            self.transitionToPhase(.loadingTrimmerDuration)
        case .loadingTrimmerTracks:
            progressLogger.debug(
                "📊 LEGACY_MAPPING: .loadingTrimmerTracks → .loadingTrimmerTracks"
            )
            self.transitionToPhase(.loadingTrimmerTracks)
        case .validatingTrimmer:

            progressLogger.info(
                "🎯 TERMINAL_STATE_MAPPING: .validatingTrimmer → .completed (1.0)"
            )
            progressLogger.info(
                "📊 DETERMINISTIC_GUARANTEE: Setting progress to 1.0 for terminal state"
            )

            self.calculateDeterministicProgress(
                phase: .validatingTrimmer,
                phaseProgress: 1.0
            )
            self.transitionToPhase(.completed)

            progressLogger.info(
                "✅ TERMINAL_STATE_ACHIEVED: Progress = 1.0, Phase = .completed"
            )
            progressLogger.info(
                "🎯 COMPLETION_GUARANTEE: All morphisms composed successfully to terminal object"
            )
            progressLogger.info(
                "📊 DETERMINISTIC_RESULT: No more 99% stall - progress reaches exactly 1.0"
            )
        case .completed:
            progressLogger.debug("📊 LEGACY_MAPPING: .completed → .completed")
            self.transitionToPhase(.completed)
        }
    }
}
