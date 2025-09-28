import Foundation
import AVFoundation

// Note: TrimmerViewModel and UnifiedVideoPlayerViewModel are defined elsewhere in the codebase

// MARK: - Real-time Save Validation Types

public enum SaveValidationIssue: Hashable {
    case emptyMoveName
    case moveNameTooShort(Int)
    case moveNameTooLong(Int)
    case noVideoAsset
    case trimmerNotReady
    case invalidStartTime(Double)
    case endTimeExceedsAsset(Double, Double)
    case startTimeAfterEndTime(Double, Double)
    case durationTooShort(Double, Double)
    case playerNotReady
    case noPlayerAvailable
    case noPhotosIdentifier
    case invalidFlowState(AddMoveFlowState)
    case saveNotInProgress
    case seekInProgress
    case seekOperationTimeout
    case seekOperationFailed

    var isCritical: Bool {
        switch self {
        case .emptyMoveName, .noVideoAsset, .trimmerNotReady, .playerNotReady, .noPlayerAvailable, .noPhotosIdentifier, .seekInProgress, .seekOperationTimeout, .seekOperationFailed:
            return true
        default:
            return false
        }
    }

    var severity: String {
        return isCritical ? "Critical" : "Warning"
    }

    var localizedDescription: String {
        switch self {
        case .emptyMoveName:
            return "Move name cannot be empty"
        case .moveNameTooShort(let length):
            return "Move name is too short (\(length) characters, minimum 2)"
        case .moveNameTooLong(let length):
            return "Move name is too long (\(length) characters, maximum 50)"
        case .noVideoAsset:
            return "No video asset available"
        case .trimmerNotReady:
            return "Trimmer is not ready"
        case .invalidStartTime(let startTime):
            return "Invalid start time: \(startTime) seconds"
        case .endTimeExceedsAsset(let endTime, let assetDuration):
            return "End time (\(endTime)) exceeds asset duration (\(assetDuration))"
        case .startTimeAfterEndTime(let startTime, let endTime):
            return "Start time (\(startTime)) is after end time (\(endTime))"
        case .durationTooShort(let duration, let minimum):
            return "Duration (\(duration)) is too short (minimum: \(minimum))"
        case .playerNotReady:
            return "Player is not ready"
        case .noPlayerAvailable:
            return "No player available"
        case .noPhotosIdentifier:
            return "Photos identifier not available"
        case .invalidFlowState(let state):
            return "Invalid flow state for saving: \(state)"
        case .saveNotInProgress:
            return "Save operation is not in progress"
        case .seekInProgress:
            return "Seek operation in progress, please wait..."
        case .seekOperationTimeout:
            return "Video seek operation timed out"
        case .seekOperationFailed:
            return "Video seek operation failed"
        }
    }
}

// MARK: - SaveValidationIssue Extensions
extension SaveValidationIssue {
    var isSeekRelated: Bool {
        switch self {
        case .seekInProgress, .seekOperationTimeout, .seekOperationFailed:
            return true
        default:
            return false
        }
    }
}

public struct SaveReadinessResult {
    public let isValid: Bool
    public let issues: [SaveValidationIssue]
    public let canSave: Bool
    public let confidence: Double
    public let moveName: String
    public let hasValidAsset: Bool
    public let hasValidTrimmer: Bool
    public let hasValidPlayer: Bool
    public let trimDuration: Double

    public var hasCriticalIssues: Bool {
        issues.contains { $0.isCritical }
    }

    public var hasWarningIssues: Bool {
        issues.contains { !$0.isCritical }
    }

    public var criticalIssues: [SaveValidationIssue] {
        issues.filter { $0.isCritical }
    }

    public var warningIssues: [SaveValidationIssue] {
        issues.filter { !$0.isCritical }
    }

    public var issuesDescription: String {
        issues.map { $0.localizedDescription }.joined(separator: "\n")
    }
}

public enum SaveValidationStatus {
    case ready(String)
    case warning(String)
    case critical(String)

    var isReady: Bool {
        switch self {
        case .ready: return true
        default: return false
        }
    }

    var statusMessage: String {
        switch self {
        case .ready(let message): return message
        case .warning(let message): return "⚠️ " + message
        case .critical(let message): return "❌ " + message
        }
    }
}

public struct ImmediateSaveValidationResult {
    public let isValid: Bool
    public let preparedAsset: PreparedAssetResult
    public let saveReadiness: SaveReadinessResult
    public let validationTimestamp: Date
}

// MARK: - Asset Readiness Types

public enum TrimmingReadinessIssue {
    case trimmerNotAvailable
    case trimmerNotReady
    case invalidTrimmerDuration
    case invalidStartTime(Double)
    case endTimeExceedsAsset(Double, Double)
    case startTimeAfterEndTime(Double, Double)
    case durationTooShort(Double, Double)
    case assetNotReady(String)
    case playerNotReady

    var localizedDescription: String {
        switch self {
        case .trimmerNotAvailable:
            return "Trimmer is not available"
        case .trimmerNotReady:
            return "Trimmer is not ready"
        case .invalidTrimmerDuration:
            return "Trimmer has invalid duration"
        case .invalidStartTime(let startTime):
            return "Invalid start time: \(startTime) seconds"
        case .endTimeExceedsAsset(let endTime, let assetDuration):
            return "End time (\(endTime)) exceeds asset duration (\(assetDuration))"
        case .startTimeAfterEndTime(let startTime, let endTime):
            return "Start time (\(startTime)) is after end time (\(endTime))"
        case .durationTooShort(let duration, let minimum):
            return "Duration (\(duration)) is too short (minimum: \(minimum))"
        case .assetNotReady(let reason):
            return "Asset not ready: \(reason)"
        case .playerNotReady:
            return "Player is not ready"
        }
    }
}

public struct TrimmingReadinessResult {
    public let isReady: Bool
    public let issues: [TrimmingReadinessIssue]
    public let trimmerViewModel: TrimmerViewModel?
    public let videoAsset: AVAsset
    public let playerViewModel: UnifiedVideoPlayerViewModel?

    public var hasIssues: Bool {
        !issues.isEmpty
    }

    public var issuesDescription: String {
        issues.map { $0.localizedDescription }.joined(separator: "; ")
    }
}

public struct PreparedAssetResult {
    public let asset: AVAsset
    public let photosIdentifier: String
    public let trimStartTime: Double
    public let trimEndTime: Double
    public let rotationQuarterTurns: Int
    public let moveName: String
    public let trimmingReadiness: TrimmingReadinessResult

    public var trimDuration: Double {
        trimEndTime - trimStartTime
    }

    public var isValidForSave: Bool {
        trimmingReadiness.isReady && !moveName.isEmpty && trimDuration >= 3.0
    }
}

// MARK: - State Validation Errors

public enum StateValidationError {
    case invalidAssetDuration(Double)
    case invalidStartTime(Double)
    case endTimeExceedsAsset(Double, Double)
    case startTimeAfterEndTime(Double, Double)
    case durationTooShort(Double, Double)
    case playerNotReadyInTrimmingState
    case missingTrimmerInTrimmingState
    case missingPlayerInNamingState

    var localizedDescription: String {
        switch self {
        case .invalidAssetDuration(let duration):
            return "Invalid asset duration: \(duration) seconds"
        case .invalidStartTime(let startTime):
            return "Invalid start time: \(startTime) seconds"
        case .endTimeExceedsAsset(let endTime, let assetDuration):
            return "End time (\(endTime)) exceeds asset duration (\(assetDuration))"
        case .startTimeAfterEndTime(let startTime, let endTime):
            return "Start time (\(startTime)) is after end time (\(endTime))"
        case .durationTooShort(let duration, let minimum):
            return "Duration (\(duration)) is too short (minimum: \(minimum))"
        case .playerNotReadyInTrimmingState:
            return "Player is not ready in trimming state"
        case .missingTrimmerInTrimmingState:
            return "Trimmer view model is missing in trimming state"
        case .missingPlayerInNamingState:
            return "Player view model is missing in naming state"
        }
    }
}