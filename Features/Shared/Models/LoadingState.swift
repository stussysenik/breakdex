import AVFoundation
import SwiftUI
import OSLog

// MARK: - Logging Configuration
/// Diagnostic logging for LoadingState transitions
extension Logger {
    static let loadingState = Logger(subsystem: "com.breakdex.loading", category: "🎬 LoadingState")
}

// MARK: - Loading Stage
/// Detailed loading stages with iCloud awareness and progress mapping
public enum LoadingStage: Equatable {
    case initializing                      // 0-10%
    case downloadingFromCloud             // 10-60%
    case transferringFile                 // 60-70%
    case validatingFile                   // 70-80%
    case creatingAsset                    // 80-90%
    case initializingPlayer               // 90-95%
    case preparingPlayback                // 95-99%
    case finalizing                       // 99-100%

    /// Base progress for each stage (0.0 to 1.0)
    public var baseProgress: Double {
        switch self {
        case .initializing:
            return 0.0
        case .downloadingFromCloud:
            return 0.1
        case .transferringFile:
            return 0.6
        case .validatingFile:
            return 0.7
        case .creatingAsset:
            return 0.8
        case .initializingPlayer:
            return 0.9
        case .preparingPlayback:
            return 0.95
        case .finalizing:
            return 0.99
        }
    }

    /// Weight factor for progress within this stage
    public var weight: Double {
        switch self {
        case .initializing:
            return 0.1        // 0-10%
        case .downloadingFromCloud:
            return 0.5        // 10-60%
        case .transferringFile:
            return 0.1        // 60-70%
        case .validatingFile:
            return 0.1        // 70-80%
        case .creatingAsset:
            return 0.1        // 80-90%
        case .initializingPlayer:
            return 0.05       // 90-95%
        case .preparingPlayback:
            return 0.04       // 95-99%
        case .finalizing:
            return 0.01       // 99-100%
        }
    }

    /// Default message for each stage
    public var defaultMessage: String {
        switch self {
        case .initializing:
            return "Initializing..."
        case .downloadingFromCloud:
            return "Downloading from iCloud..."
        case .transferringFile:
            return "Transferring file..."
        case .validatingFile:
            return "Validating video file..."
        case .creatingAsset:
            return "Creating video asset..."
        case .initializingPlayer:
            return "Preparing video player..."
        case .preparingPlayback:
            return "Preparing for playback..."
        case .finalizing:
            return "Finalizing..."
        }
    }
}

// MARK: - Enhanced Loading State
/// Enhanced loading state with iCloud awareness and player synchronization
public enum LoadingState: Equatable {
    case idle
    case loading(progress: Double, stage: LoadingStage, message: String)
    case assetReady(AVAsset)              // AVAsset loaded, player loading pending
    case playerReady(AVAsset)             // Player ready, finalizing
    case fullyReady(AVAsset)              // Both asset and player ready
    case failed(String)

    public var isLoading: Bool {
        switch self {
        case .loading:
            return true
        default:
            return false
        }
    }

    public var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    public var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    /// Overall progress calculated based on loading stage and internal progress
    public var progress: Double {
        switch self {
        case .loading(let progress, let stage, _):
            let calculatedProgress = stage.baseProgress + (progress * stage.weight)
            // ENHANCED: Ensure monotonic progress increase to 100%
            return min(1.0, max(0.0, calculatedProgress))
        case .assetReady:
            return 0.6  // 60% - Asset loaded, player loading pending
        case .playerReady:
            return 0.8  // 80% - Player ready, finalizing
        case .fullyReady:
            // CRITICAL FIX: Guarantee fullyReady state always returns 1.0 (100%)
            return 1.0  // 100% - Fully ready
        case .failed, .idle:
            return 0.0
        }
    }

    /// SESSION-AWARE STATE VALIDATION: Ensure state transitions can only move forward within sessions
    /// - Parameter previousState: The previous loading state to validate against
    /// - Returns: true if transition is valid (session-aware monotonic), false if harmful regression would occur
    public func validateMonotonicTransition(from previousState: LoadingState) -> Bool {
        let previousProgress = previousState.progress
        let currentProgress = self.progress

        // Special case: failed state can always be entered (error recovery)
        if case .failed = self {
            Logger.loadingState.warning("⚠️ State transition to failed allowed from \(previousState.progress * 100)%")
            return true
        }

        // Special case: idle state can only be entered from failed or idle (reset scenario)
        if case .idle = self {
            if previousState.isFailed || previousState.isIdle {
                Logger.loadingState.info("🔄 State reset to idle from \(previousState)")
                return true
            }
            Logger.loadingState.error("❌ Invalid transition to idle from \(previousState)")
            return false
        }

        // SESSION BOUNDARY FIX: Allow fullyReady → loading transitions for new loading sessions
        // This fixes the issue where cancel-trim-select-new-clip workflows were blocked
        if case .fullyReady = previousState, case .loading = self {
            Logger.loadingState.info("🆕 SESSION BOUNDARY: New loading session detected - allowing fullyReady → loading transition")
            Logger.loadingState.info("📊 Session transition: \(Int(previousProgress * 100))% → \(Int(currentProgress * 100))% (new session)")
            return true
        }

        // Ensure progress is monotonic within a session (always increases or stays the same)
        let isMonotonic = currentProgress >= previousProgress

        if !isMonotonic {
            Logger.loadingState.error("🚫 STATE REGRESSION DETECTED: \(previousProgress * 100)% → \(currentProgress * 100)%")
            return false
        }

        // Log successful monotonic transition
        Logger.loadingState.debug("✅ Monotonic transition: \(previousProgress * 100)% → \(currentProgress * 100)%")
        return true
    }

    /// ENHANCED: Progress validation to ensure monotonic increase to 100%
    public func validateProgressMonotonicity() -> Bool {
        let currentProgress = self.progress

        // Ensure fullyReady always returns exactly 1.0
        if case .fullyReady = self {
            let isExactlyOne = abs(currentProgress - 1.0) < 0.001 // Allow tiny floating point error
            if !isExactlyOne {
                Logger.loadingState.error("❌ fullyReady state returning invalid progress: \(currentProgress * 100)%")
            }
            return isExactlyOne
        }

        // Ensure progress is within valid bounds
        let isValidBounds = currentProgress >= 0.0 && currentProgress <= 1.0
        if !isValidBounds {
            Logger.loadingState.error("❌ Progress out of bounds: \(currentProgress * 100)%")
        }

        return isValidBounds
    }

    /// ENHANCED: Check if this state represents a stuck transition that needs timeout handling
    public var isPotentiallyStuck: Bool {
        switch self {
        case .loading(let progress, let stage, _):
            // Check if we're stuck in final stages for too long
            if stage == .creatingAsset && progress >= 0.88 {
                return true // Stuck at 88-90% - the main issue we're fixing
            }
            if stage == .finalizing && progress >= 0.98 {
                return true // Stuck at 98-99%
            }
            return false
        default:
            return false
        }
    }

    /// ENHANCED: Get timeout duration for stuck transitions
    public var stuckTransitionTimeout: TimeInterval {
        switch self {
        case .loading(_, let stage, _):
            switch stage {
            case .creatingAsset:
                return 5.0 // 5 seconds timeout for creatingAsset stage
            case .finalizing:
                return 3.0 // 3 seconds timeout for finalizing stage
            default:
                return 10.0 // Default 10 seconds for other stages
            }
        default:
            return 30.0 // 30 seconds for non-loading states
        }
    }

    /// Current loading stage, if applicable
    public var stage: LoadingStage? {
        switch self {
        case .loading(_, let stage, _):
            return stage
        default:
            return nil
        }
    }

    /// Current loading message
    public var message: String {
        switch self {
        case .loading(_, _, let message):
            return message
        case .assetReady:
            return "Preparing video player..."
        case .playerReady:
            return "Finalizing..."
        case .fullyReady:
            return "Ready"
        case .failed(let message):
            return message
        case .idle:
            return "Ready to load"
        }
    }

    public var asset: AVAsset? {
        switch self {
        case .assetReady(let asset), .playerReady(let asset), .fullyReady(let asset):
            return asset
        default:
            return nil
        }
    }

    public var errorMessage: String? {
        switch self {
        case .failed(let message):
            return message
        default:
            return nil
        }
    }

    /// Check if video is ready for playback (both asset and player ready)
    public var isFullyReady: Bool {
        switch self {
        case .fullyReady:
            return true
        default:
            return false
        }
    }

    /// Check if asset is ready (can be used for player initialization)
    public var isAssetReady: Bool {
        switch self {
        case .assetReady, .playerReady, .fullyReady:
            return true
        default:
            return false
        }
    }
}

// MARK: - Enhanced Loading Error
/// Comprehensive loading error for user-friendly messages with iCloud support
public enum LoadingError: Error, LocalizedError, Equatable {
    // Network and connectivity errors
    case networkLost
    case timeout(TimeInterval)
    case dataTransferFailed(String)
    case streamingFailed(Error)

    // Permission and access errors
    case permissionDenied
    case itemIdentifierMissing
    case transferableNotSupported

    // Asset and file errors
    case assetUnavailable
    case assetNotFound
    case corruptedFile
    case unsupportedFileType
    case avAssetCreationFailed
    case assetValidationFailed(String)
    case invalidAsset(String)
    case dataUnavailable
    case temporaryFileError(Error)

    // Player and playback errors
    case playerInitializationFailed(String)
    case playerItemFailed(String)

    // General errors
    case networkUnavailable
    case downloadFailed(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        // Network errors
        case .networkLost:
            return "Network connection was lost"
        case .timeout(let duration):
            return "Operation timed out after \(String(format: "%.1f", duration)) seconds"
        case .dataTransferFailed(let message):
            return "Data transfer failed: \(message)"
        case .streamingFailed(let error):
            return "Streaming failed: \(error.localizedDescription)"

        // Permission errors
        case .permissionDenied:
            return "Photo library access denied"
        case .itemIdentifierMissing:
            return "Video item identifier is missing"
        case .transferableNotSupported:
            return "Transferable content not supported"

        // Asset errors
        case .assetUnavailable:
            return "Video asset is temporarily unavailable"
        case .assetNotFound:
            return "Video asset could not be found"
        case .corruptedFile:
            return "Video file is corrupted or damaged"
        case .unsupportedFileType:
            return "Video file type is not supported"
        case .avAssetCreationFailed:
            return "Failed to create AVAsset from video"
        case .assetValidationFailed(let message):
            return "Asset validation failed: \(message)"
        case .invalidAsset(let message):
            return "Invalid video asset: \(message)"
        case .dataUnavailable:
            return "Video data is unavailable"
        case .temporaryFileError(let error):
            return "Temporary file error: \(error.localizedDescription)"

        // Player errors
        case .playerInitializationFailed(let message):
            return "Player initialization failed: \(message)"
        case .playerItemFailed(let message):
            return "Player item failed: \(message)"

        // General errors
        case .networkUnavailable:
            return "Network connection required"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .unknown(let reason):
            return "Error: \(reason)"
        }
    }

    public var userFriendlyMessage: String {
        switch self {
        // Network errors
        case .networkLost:
            return "Network connection was lost"
        case .timeout:
            return "Loading took too long - try again"
        case .dataTransferFailed:
            return "Data transfer failed - try again"
        case .streamingFailed:
            return "Streaming failed - try again"

        // Permission errors
        case .permissionDenied:
            return "Allow photo library access in Settings"
        case .itemIdentifierMissing:
            return "Video item is missing - try again"
        case .transferableNotSupported:
            return "Video format not supported"

        // Asset errors
        case .assetUnavailable:
            return "Video temporarily unavailable - try again"
        case .assetNotFound:
            return "Please select a different video"
        case .corruptedFile:
            return "The video file may be damaged"
        case .unsupportedFileType:
            return "Choose a supported video format"
        case .avAssetCreationFailed:
            return "Failed to process video - try again"
        case .assetValidationFailed:
            return "Video validation failed - try again"
        case .invalidAsset:
            return "Invalid video format - choose another"
        case .dataUnavailable:
            return "Video data unavailable - try again"
        case .temporaryFileError:
            return "File processing error - try again"

        // Player errors
        case .playerInitializationFailed:
            return "Video player failed - try again"
        case .playerItemFailed:
            return "Playback failed - try again"

        // General errors
        case .networkUnavailable:
            return "Check your internet connection"
        case .downloadFailed:
            return "Try downloading again"
        case .unknown:
            return "Something went wrong - try again"
        }
    }

    // MARK: - Equatable Conformance
    public static func == (lhs: LoadingError, rhs: LoadingError) -> Bool {
        switch (lhs, rhs) {
        case (.networkLost, .networkLost),
             (.permissionDenied, .permissionDenied),
             (.itemIdentifierMissing, .itemIdentifierMissing),
             (.transferableNotSupported, .transferableNotSupported),
             (.assetUnavailable, .assetUnavailable),
             (.assetNotFound, .assetNotFound),
             (.corruptedFile, .corruptedFile),
             (.unsupportedFileType, .unsupportedFileType),
             (.avAssetCreationFailed, .avAssetCreationFailed),
             (.dataUnavailable, .dataUnavailable),
             (.networkUnavailable, .networkUnavailable):
            return true

        case (.timeout(let lhsDuration), .timeout(let rhsDuration)):
            return abs(lhsDuration - rhsDuration) < 0.001

        case (.dataTransferFailed(let lhsMessage), .dataTransferFailed(let rhsMessage)):
            return lhsMessage == rhsMessage

        case (.assetValidationFailed(let lhsMessage), .assetValidationFailed(let rhsMessage)):
            return lhsMessage == rhsMessage

        case (.invalidAsset(let lhsMessage), .invalidAsset(let rhsMessage)):
            return lhsMessage == rhsMessage

        case (.playerInitializationFailed(let lhsMessage), .playerInitializationFailed(let rhsMessage)):
            return lhsMessage == rhsMessage

        case (.playerItemFailed(let lhsMessage), .playerItemFailed(let rhsMessage)):
            return lhsMessage == rhsMessage

        case (.downloadFailed(let lhsMessage), .downloadFailed(let rhsMessage)):
            return lhsMessage == rhsMessage

        case (.unknown(let lhsMessage), .unknown(let rhsMessage)):
            return lhsMessage == rhsMessage

        case (.streamingFailed(let lhsError), .streamingFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription

        case (.temporaryFileError(let lhsError), .temporaryFileError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription

        default:
            return false
        }
    }
}

// MARK: - Enhanced Loading Progress
/// Enhanced progress tracking for UI feedback with iCloud awareness
public struct LoadingProgress {
    public let value: Double
    public let message: String
    public let stage: LoadingStage?
    public let downloadSpeed: Double?  // bytes per second for iCloud downloads

    public init(value: Double, message: String = "", stage: LoadingStage? = nil, downloadSpeed: Double? = nil) {
        self.value = max(0.0, min(1.0, value))
        self.message = message
        self.stage = stage
        self.downloadSpeed = downloadSpeed
    }

    // **BREAKING CHANGE**: Stage-aware constructor - requires stage parameter for progress synchronization
    public init(value: Double, message: String, stage: LoadingStage, downloadSpeed: Double? = nil) {
        self.value = max(0.0, min(1.0, value))
        self.message = message
        self.stage = stage
        self.downloadSpeed = downloadSpeed
    }

    // Convenience initializers for common stages
    public static let initial = LoadingProgress(value: 0.0, message: "Initializing...", stage: .initializing)
    public static let downloading = LoadingProgress(value: 0.1, message: "Downloading from iCloud...", stage: .downloadingFromCloud)
    public static let transferring = LoadingProgress(value: 0.6, message: "Transferring file...", stage: .transferringFile)
    public static let validating = LoadingProgress(value: 0.7, message: "Validating file...", stage: .validatingFile)
    public static let creatingAsset = LoadingProgress(value: 0.8, message: "Creating asset...", stage: .creatingAsset)
    public static let initializingPlayer = LoadingProgress(value: 0.9, message: "Preparing player...", stage: .initializingPlayer)
    public static let preparingPlayback = LoadingProgress(value: 0.95, message: "Preparing playback...", stage: .preparingPlayback)
    public static let finalizing = LoadingProgress(value: 0.99, message: "Finalizing...", stage: .finalizing)
    public static let complete = LoadingProgress(value: 1.0, message: "Complete", stage: nil)

    // **NEW**: Stage-aware factory method for fullyReady state - ensures 100% completion
    public static func fullyReady(asset: AVAsset) -> LoadingProgress {
        return LoadingProgress(value: 1.0, message: "Ready", stage: nil)
    }

    // iCloud download with speed info
    public static func iCloudDownload(progress: Double, speed: Double) -> LoadingProgress {
        let formattedSpeed = ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file)
        return LoadingProgress(
            value: 0.1 + (progress * 0.5),
            message: "Downloading from iCloud... \(formattedSpeed)/s",
            stage: .downloadingFromCloud,
            downloadSpeed: speed
        )
    }
}

