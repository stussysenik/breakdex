import Foundation

// MARK: - Simple Progress Types
/// Essentialist approach - simple typealias instead of complex progress engines
/// Following KISS principle: progress is just a number from 0.0 to 1.0

/// Video processing progress - detailed progress with phase and correlation tracking
public struct VideoProcessingProgress {
    public let phase: ProcessingPhase
    public let progress: Double
    public let correlationId: String
    public let timestamp: Date

    public init(phase: ProcessingPhase, correlationId: String) {
        self.phase = phase
        self.progress = phase.defaultProgress
        self.correlationId = correlationId
        self.timestamp = Date()
    }

    public init(phase: ProcessingPhase, progress: Double, correlationId: String) {
        self.phase = phase
        self.progress = max(0.0, min(1.0, progress))
        self.correlationId = correlationId
        self.timestamp = Date()
    }

    /// Progress percentage (0-100)
    public var percentage: Int {
        return Int(progress * 100)
    }

    /// Progress message based on phase
    public var message: String {
        return phase.displayName
    }

    /// Check if progress is complete
    public var isComplete: Bool {
        return progress >= 1.0
    }

    /// Check if progress has started
    public var hasStarted: Bool {
        return progress > 0.0
    }
}

/// Processing phase enumeration for video processing operations
public enum ProcessingPhase {
    case idle
    case initializing
    case processing
    case encoding
    case exporting
    case completed
    case error(String)

    public var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .initializing: return "Initializing"
        case .processing: return "Processing"
        case .encoding: return "Encoding"
        case .exporting: return "Exporting"
        case .completed: return "Complete"
        case .error(let message): return "Error: \(message)"
        }
    }

    /// Default progress value for this processing phase
    public var defaultProgress: Double {
        switch self {
        case .idle: return 0.0
        case .initializing: return 0.1
        case .processing: return 0.5
        case .encoding: return 0.8
        case .exporting: return 0.95
        case .completed: return 1.0
        case .error: return 0.0
        }
    }

    public var isActive: Bool {
        switch self {
        case .idle, .completed, .error:
            return false
        default:
            return true
        }
    }

    public var isError: Bool {
        switch self {
        case .error: return true
        default: return false
        }
    }
}

/// Unified progress type - works for all operations
public typealias UnifiedProgress = Double

// MARK: - Video Loading Progress Struct
/// Detailed video loading progress with phase and correlation tracking
public struct VideoLoadingProgress {
    public let phase: LoadingPhase
    public let progress: Double
    public let correlationId: String
    public let timestamp: Date

    public init(phase: LoadingPhase, correlationId: String) {
        self.phase = phase
        self.progress = phase.defaultProgress
        self.correlationId = correlationId
        self.timestamp = Date()
    }

    public init(phase: LoadingPhase, progress: Double, correlationId: String) {
        self.phase = phase
        self.progress = max(0.0, min(1.0, progress))
        self.correlationId = correlationId
        self.timestamp = Date()
    }

    /// Progress percentage (0-100)
    public var percentage: Int {
        return Int(progress * 100)
    }

    /// Download percentage for compatibility with existing code
    public var downloadPercentage: Int? {
        return percentage
    }

    /// Download speed for compatibility with existing code
    public var formattedDownloadSpeed: String? {
        return nil
    }

    /// Progress message based on phase
    public var message: String {
        return phase.displayName
    }

    /// Check if progress is complete
    public var isComplete: Bool {
        return progress >= 1.0
    }

    /// Check if progress has started
    public var hasStarted: Bool {
        return progress > 0.0
    }
}

// MARK: - Progress Constants
extension Double {
    /// 0% progress
    static let progressNone: Double = 0.0
    /// 25% progress
    static let progressQuarter: Double = 0.25
    /// 50% progress
    static let progressHalf: Double = 0.5
    /// 75% progress
    static let progressThreeQuarters: Double = 0.75
    /// 100% progress
    static let progressComplete: Double = 1.0

    /// Convert to percentage string
    var percentage: String {
        return "\(Int(self * 100))%"
    }

    /// Check if progress is complete
    var isComplete: Bool {
        return self >= 1.0
    }

    /// Check if progress has started
    var hasStarted: Bool {
        return self > 0.0
    }
}

// MARK: - Simple Progress Struct
/// Minimal progress struct with value and optional message
public struct SimpleProgress: Equatable {
    public let value: Double
    public let message: String?

    public init(value: Double, message: String? = nil) {
        self.value = max(0.0, min(1.0, value)) // Clamp between 0.0 and 1.0
        self.message = message
    }

    /// Progress not started
    public static var none: SimpleProgress {
        return SimpleProgress(value: 0.0)
    }

    /// Progress complete
    public static var complete: SimpleProgress {
        return SimpleProgress(value: 1.0, message: "Complete")
    }

    /// Create progress with percentage
    public static func percentage(_ percent: Double, message: String? = nil) -> SimpleProgress {
        return SimpleProgress(value: percent / 100.0, message: message)
    }
}

// MARK: - Loading Phase Extension
extension VideoLoadingProgress {
    /// Simple progress phase enumeration for tracking operation states
    public enum LoadingPhase: Equatable {
        case idle
        case initializing
        case requestingDownload
        case downloadingFromCloud(Double)
        case transferring
        case creatingAsset
        case generatingThumbnail
        case loadingTrimmerDuration
        case loadingTrimmerTracks
        case validating
        case validatingTrimmer
        case waitingForNetwork
        case loading
        case processing
        case saving
        case completed
        case complete
        case error(String)

        public var displayName: String {
            switch self {
            case .idle: return "Ready"
            case .initializing: return "Initializing"
            case .requestingDownload: return "Requesting Download"
            case .downloadingFromCloud(let progress): return "Downloading from Cloud (\(Int(progress * 100))%)"
            case .transferring: return "Transferring"
            case .creatingAsset: return "Creating Asset"
            case .generatingThumbnail: return "Generating Thumbnail"
            case .loadingTrimmerDuration: return "Loading Trimmer Duration"
            case .loadingTrimmerTracks: return "Loading Trimmer Tracks"
            case .validating: return "Validating"
            case .validatingTrimmer: return "Validating Trimmer"
            case .waitingForNetwork: return "Waiting for Network"
            case .loading: return "Loading"
            case .processing: return "Processing"
            case .saving: return "Saving"
            case .completed: return "Completed"
            case .complete: return "Complete"
            case .error(let message): return "Error: \(message)"
            }
        }

        /// Default progress value for this loading phase
        public var defaultProgress: Double {
            switch self {
            case .idle: return 0.0
            case .initializing: return 0.05
            case .requestingDownload: return 0.1
            case .downloadingFromCloud(let progress): return progress
            case .transferring: return 0.25
            case .creatingAsset: return 0.35
            case .generatingThumbnail: return 0.45
            case .loadingTrimmerDuration: return 0.55
            case .loadingTrimmerTracks: return 0.65
            case .validating: return 0.75
            case .validatingTrimmer: return 0.85
            case .waitingForNetwork: return 0.4
            case .loading: return 0.25
            case .processing: return 0.5
            case .saving: return 0.75
            case .completed: return 1.0
            case .complete: return 1.0
            case .error: return 0.0
            }
        }

        public var isActive: Bool {
            switch self {
            case .idle, .complete, .completed, .error:
                return false
            default:
                return true
            }
        }

        public var isError: Bool {
            switch self {
            case .error: return true
            default: return false
            }
        }
    }

    /// Get loading phase for given progress value
    public static func phase(for progress: VideoLoadingProgress) -> LoadingPhase {
        if progress.progress <= 0.0 {
            return .idle
        } else if progress.progress < 1.0 {
            return .loading
        } else {
            return .complete
        }
    }

    /// Create error phase
    public static func error(_ message: String) -> LoadingPhase {
        return .error(message)
    }
}

// MARK: - Progress Phase Enum
/// Simple phases for progress tracking
public enum ProgressPhase: String, CaseIterable {
    case idle = "Idle"
    case initializing = "Initializing"
    case requestingDownload = "Requesting Download"
    case downloadingFromCloud = "Downloading from Cloud"
    case transferring = "Transferring"
    case creatingAsset = "Creating Asset"
    case generatingThumbnail = "Generating Thumbnail"
    case loadingTrimmerDuration = "Loading Trimmer Duration"
    case loadingTrimmerTracks = "Loading Trimmer Tracks"
    case validating = "Validating"
    case validatingTrimmer = "Validating Trimmer"
    case waitingForNetwork = "Waiting for Network"
    case loading = "Loading"
    case processing = "Processing"
    case saving = "Saving"
    case completed = "Completed"
    case complete = "Complete"
    case error = "Error"

    /// Default progress value for this phase
    public var defaultProgress: Double {
        switch self {
        case .idle: return 0.0
        case .initializing: return 0.05
        case .requestingDownload: return 0.1
        case .downloadingFromCloud: return 0.15
        case .transferring: return 0.25
        case .creatingAsset: return 0.35
        case .generatingThumbnail: return 0.45
        case .loadingTrimmerDuration: return 0.55
        case .loadingTrimmerTracks: return 0.65
        case .validating: return 0.75
        case .validatingTrimmer: return 0.85
        case .waitingForNetwork: return 0.4
        case .loading: return 0.25
        case .processing: return 0.5
        case .saving: return 0.75
        case .completed: return 1.0
        case .complete: return 1.0
        case .error: return 0.0
        }
    }

    /// Check if this phase represents an active operation
    public var isActive: Bool {
        switch self {
        case .idle, .complete, .completed, .error:
            return false
        default:
            return true
        }
    }

    /// Check if this phase represents an error state
    public var isError: Bool {
        return self == .error
    }
}

// MARK: - Progress Error Enum
/// Progress error types for video loading and processing operations
public enum ProgressError: Error, LocalizedError {
    case timeout(duration: TimeInterval)
    case networkLost
    case assetUnavailable
    case permissionDenied
    case corruptedFile
    case userCancelled
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .timeout(let duration):
            return "Operation timed out after \(String(format: "%.1f", duration)) seconds"
        case .networkLost:
            return "Network connection was lost"
        case .assetUnavailable:
            return "Video asset is unavailable or could not be loaded"
        case .permissionDenied:
            return "Permission to access video was denied"
        case .corruptedFile:
            return "Video file is corrupted or invalid"
        case .userCancelled:
            return "Operation was cancelled by the user"
        case .unknown(let message):
            return message
        }
    }
}