import Foundation

// MARK: - Add Move Errors
public enum AddMoveError: LocalizedError {
    case videoLoadFailed(underlyingError: Error?)
    case invalidMoveName
    case invalidTrimRange(String)
    case trimmerNotAvailable
    case trimmerNotReady
    case videoAssetNotAvailable
    case playerNotReady
    case assetNotReady(String)
    case invalidAssetDuration
    case invalidStateForSaving
    case photosIdentifierNotAvailable
    case saveValidationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .videoLoadFailed:
            return "Failed to load video"
        case .invalidMoveName:
            return "Invalid move name"
        case .invalidTrimRange(let reason):
            return reason
        case .trimmerNotAvailable:
            return "Trimmer is not available"
        case .trimmerNotReady:
            return "Trimmer is not ready"
        case .videoAssetNotAvailable:
            return "Video asset is not available"
        case .playerNotReady:
            return "Video player is not ready"
        case .assetNotReady(let reason):
            return "Video asset is not ready: \(reason)"
        case .invalidAssetDuration:
            return "Invalid video duration detected"
        case .invalidStateForSaving:
            return "Cannot save from current state"
        case .photosIdentifierNotAvailable:
            return "Photos identifier not available"
        case .saveValidationFailed(let details):
            return "Save validation failed: \(details)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .videoLoadFailed:
            return "Please try selecting a different video"
        case .invalidMoveName:
            return "Please enter a valid name for your move"
        case .invalidTrimRange:
            return "Please adjust your trim handles to valid positions"
        case .trimmerNotAvailable:
            return "Please restart the trimming process"
        case .trimmerNotReady:
            return "Please wait for the trimmer to load completely"
        case .videoAssetNotAvailable:
            return "Please reload the video"
        case .playerNotReady:
            return "Please wait for the video to load completely"
        case .assetNotReady:
            return "Please wait for the video to finish processing"
        case .invalidAssetDuration:
            return "Please select a video with valid duration"
        case .invalidStateForSaving:
            return "Please complete the setup process before saving"
        case .photosIdentifierNotAvailable:
            return "Please reselect the video from your photo library"
        case .saveValidationFailed:
            return "Please address the validation issues before saving"
        }
    }

    public var isRecoverable: Bool {
        switch self {
        case .videoLoadFailed, .invalidMoveName, .invalidTrimRange, .trimmerNotAvailable,
             .trimmerNotReady, .videoAssetNotAvailable, .playerNotReady, .assetNotReady,
             .invalidAssetDuration, .invalidStateForSaving, .photosIdentifierNotAvailable,
             .saveValidationFailed:
            return true
        }
    }

    public var severity: ErrorSeverity {
        switch self {
        case .videoLoadFailed, .invalidAssetDuration, .invalidStateForSaving, .photosIdentifierNotAvailable:
            return .critical
        case .invalidMoveName, .invalidTrimRange, .trimmerNotAvailable, .trimmerNotReady,
             .videoAssetNotAvailable, .playerNotReady, .assetNotReady, .saveValidationFailed:
            return .warning
        }
    }
}

// MARK: - Video Processing Errors
public enum VideoProcessingError: LocalizedError {
    case memoryLimitExceeded(used: Int64, available: Int64)
    case invalidStateTransition(from: String, to: String)
    case videoLoadingFailed(identifier: String, underlyingError: Error)
    case videoProcessingFailed(operation: String, underlyingError: Error)
    case assetCreationFailed
    case playerInitializationFailed
    case readinessTimeout
    case exportFailed(operation: String, underlyingError: Error)
    case trimOperationFailed(startTime: Double, endTime: Double, underlyingError: Error)
    case assetNotReadable
    case codecNotSupported
    case invalidVideoFormat
    case insufficientPermissions
    case diskSpaceFull(required: Int64, available: Int64)
    case networkError(operation: String, underlyingError: Error)
    case concurrentOperationLimitReached
    case operationCancelled
    case invalidVideoDimensions(width: Int, height: Int)
    case frameRateNotSupported(fps: Double)
    case audioTrackMissing

    public var errorDescription: String? {
        switch self {
        case .memoryLimitExceeded(let used, let available):
            return "Memory limit exceeded. Used: \(used)MB, Available: \(available)MB"
        case .invalidStateTransition(let from, let to):
            return "Invalid state transition from \(from) to \(to)"
        case .videoLoadingFailed(let identifier, _):
            return "Failed to load video with identifier: \(identifier)"
        case .videoProcessingFailed(let operation, _):
            return "Failed to perform video operation: \(operation)"
        case .assetCreationFailed:
            return "Failed to create video asset"
        case .playerInitializationFailed:
            return "Failed to initialize video player"
        case .readinessTimeout:
            return "Video player readiness timeout"
        case .exportFailed(let operation, _):
            return "Failed to export video during: \(operation)"
        case .trimOperationFailed(let startTime, let endTime, _):
            return "Failed to trim video from \(startTime)s to \(endTime)s"
        case .assetNotReadable:
            return "Video asset is not readable"
        case .codecNotSupported:
            return "Video codec is not supported"
        case .invalidVideoFormat:
            return "Invalid video format"
        case .insufficientPermissions:
            return "Insufficient permissions to access video"
        case .diskSpaceFull(let required, let available):
            return "Insufficient disk space. Required: \(required)MB, Available: \(available)MB"
        case .networkError(let operation, _):
            return "Network error during: \(operation)"
        case .concurrentOperationLimitReached:
            return "Too many concurrent video operations"
        case .operationCancelled:
            return "Video operation was cancelled"
        case .invalidVideoDimensions(let width, let height):
            return "Invalid video dimensions: \(width)x\(height)"
        case .frameRateNotSupported(let fps):
            return "Frame rate not supported: \(fps)fps"
        case .audioTrackMissing:
            return "Audio track is missing from video"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .memoryLimitExceeded:
            return "Try closing other apps or using a smaller video file"
        case .invalidStateTransition:
            return "Please restart the app and try again"
        case .videoLoadingFailed:
            return "Check if the video exists in your photo library"
        case .videoProcessingFailed:
            return "Try again with a different video or reduce the video quality"
        case .assetCreationFailed:
            return "Please try selecting a different video"
        case .playerInitializationFailed:
            return "Restart the app and try again"
        case .readinessTimeout:
            return "Check your internet connection and try again"
        case .exportFailed:
            return "Try reducing video quality or use a shorter video segment"
        case .trimOperationFailed:
            return "Try adjusting the trim range or using a different video"
        case .assetNotReadable:
            return "Please reselect the video file"
        case .codecNotSupported:
            return "Convert the video to a supported format (H.264, HEVC)"
        case .invalidVideoFormat:
            return "Use a standard video format (MP4, MOV)"
        case .insufficientPermissions:
            return "Grant photo library access in Settings"
        case .diskSpaceFull:
            return "Free up storage space on your device"
        case .networkError:
            return "Check your internet connection and try again"
        case .concurrentOperationLimitReached:
            return "Wait for current operations to complete"
        case .operationCancelled:
            return "Start the operation again"
        case .invalidVideoDimensions:
            return "Use a video with standard dimensions (1920x1080 or smaller)"
        case .frameRateNotSupported:
            return "Use a video with standard frame rate (24, 30, or 60 fps)"
        case .audioTrackMissing:
            return "This is expected for silent videos"
        }
    }

    public var isRecoverable: Bool {
        switch self {
        case .memoryLimitExceeded, .invalidStateTransition, .videoLoadingFailed, .videoProcessingFailed,
             .assetCreationFailed, .playerInitializationFailed, .readinessTimeout, .exportFailed,
             .trimOperationFailed, .assetNotReadable, .codecNotSupported, .invalidVideoFormat,
             .insufficientPermissions, .diskSpaceFull, .networkError, .concurrentOperationLimitReached,
             .invalidVideoDimensions, .frameRateNotSupported:
            return true
        case .operationCancelled, .audioTrackMissing:
            return false
        }
    }

    public var severity: ErrorSeverity {
        switch self {
        case .memoryLimitExceeded, .invalidStateTransition, .assetCreationFailed, .playerInitializationFailed,
             .codecNotSupported, .invalidVideoFormat, .insufficientPermissions, .diskSpaceFull,
             .invalidVideoDimensions, .frameRateNotSupported:
            return .critical
        case .videoLoadingFailed, .videoProcessingFailed, .readinessTimeout, .exportFailed,
             .trimOperationFailed, .assetNotReadable, .networkError, .concurrentOperationLimitReached:
            return .warning
        case .operationCancelled, .audioTrackMissing:
            return .info
        }
    }

    public var operationType: VideoProcessingOperation {
        switch self {
        case .videoLoadingFailed: return .loading
        case .videoProcessingFailed, .exportFailed, .trimOperationFailed: return .processing
        case .assetCreationFailed, .playerInitializationFailed: return .initialization
        case .memoryLimitExceeded, .readinessTimeout, .diskSpaceFull, .concurrentOperationLimitReached: return .resource
        case .codecNotSupported, .invalidVideoFormat, .invalidVideoDimensions, .frameRateNotSupported: return .format
        case .insufficientPermissions: return .permission
        case .networkError: return .network
        case .operationCancelled: return .user
        case .invalidStateTransition: return .state
        case .assetNotReadable, .audioTrackMissing: return .content
        }
    }
}

// MARK: - Supporting Types

public enum ErrorSeverity {
    case critical
    case warning
    case info

    var localizedDescription: String {
        switch self {
        case .critical: return "Critical"
        case .warning: return "Warning"
        case .info: return "Info"
        }
    }
}

public enum VideoProcessingOperation {
    case loading
    case processing
    case initialization
    case resource
    case format
    case permission
    case network
    case user
    case state
    case content

    var localizedDescription: String {
        switch self {
        case .loading: return "Loading"
        case .processing: return "Processing"
        case .initialization: return "Initialization"
        case .resource: return "Resource"
        case .format: return "Format"
        case .permission: return "Permission"
        case .network: return "Network"
        case .user: return "User"
        case .state: return "State"
        case .content: return "Content"
        }
    }
}


// MARK: - Error Utilities

public struct ErrorInfo {
    public let error: Error
    public let severity: ErrorSeverity
    public let isRecoverable: Bool
    public let recoverySuggestion: String?
    public let operationType: VideoProcessingOperation?
    public let timestamp: Date

    public init(error: Error, severity: ErrorSeverity = .warning, isRecoverable: Bool = true,
                recoverySuggestion: String? = nil, operationType: VideoProcessingOperation? = nil) {
        self.error = error
        self.severity = severity
        self.isRecoverable = isRecoverable
        self.recoverySuggestion = recoverySuggestion
        self.operationType = operationType
        self.timestamp = Date()
    }

    public var localizedDescription: String {
        if let localizedError = error as? LocalizedError {
            return localizedError.errorDescription ?? error.localizedDescription
        }
        return error.localizedDescription
    }
}

// MARK: - Error Handler Protocol

public protocol VideoProcessingErrorHandler {
    func handleError(_ error: Error, operation: VideoProcessingOperation?) async throws -> RecoveryAction
    func shouldRetry(_ error: Error, attemptCount: Int) -> Bool
    func getRecoverySuggestion(for error: Error) -> String?
}

public enum RecoveryAction {
    case retry
    case skip
    case cancel
    case fallbackToDefault
    case useAlternativeMethod(String)
}

// MARK: - Error Collector

public class ErrorCollector {
    private var errors: [ErrorInfo] = []
    private let maxErrors: Int

    public init(maxErrors: Int = 100) {
        self.maxErrors = maxErrors
    }

    public func recordError(_ error: Error, severity: ErrorSeverity = .warning,
                          operation: VideoProcessingOperation? = nil) {
        let errorInfo: ErrorInfo

        if let videoError = error as? VideoProcessingError {
            errorInfo = ErrorInfo(
                error: error,
                severity: videoError.severity,
                isRecoverable: videoError.isRecoverable,
                recoverySuggestion: videoError.recoverySuggestion,
                operationType: videoError.operationType
            )
        } else if let addMoveError = error as? AddMoveError {
            errorInfo = ErrorInfo(
                error: error,
                severity: addMoveError.severity,
                isRecoverable: addMoveError.isRecoverable,
                recoverySuggestion: addMoveError.recoverySuggestion,
                operationType: operation
            )
        } else {
            errorInfo = ErrorInfo(
                error: error,
                severity: severity,
                operationType: operation
            )
        }

        errors.append(errorInfo)

        // Keep only the most recent errors
        if errors.count > maxErrors {
            errors.removeFirst(errors.count - maxErrors)
        }
    }

    public func getErrors() -> [ErrorInfo] {
        return errors
    }

    public func getCriticalErrors() -> [ErrorInfo] {
        return errors.filter { $0.severity == .critical }
    }

    public func getRecentErrors(since date: Date) -> [ErrorInfo] {
        return errors.filter { $0.timestamp >= date }
    }

    public func clearErrors() {
        errors.removeAll()
    }

    public func hasCriticalErrors() -> Bool {
        return errors.contains { $0.severity == .critical }
    }

    public func getErrorSummary() -> String {
        let total = errors.count
        let critical = errors.filter { $0.severity == .critical }.count
        let warnings = errors.filter { $0.severity == .warning }.count
        let info = errors.filter { $0.severity == .info }.count

        return "Errors: \(total) (Critical: \(critical), Warnings: \(warnings), Info: \(info))"
    }
}