import AVFoundation
import Foundation
import OSLog

// VideoLoadingState.swift - comprehensive enum for all loading states

// MARK: - Video Loading State
/// Comprehensive state management for video loading operations
/// Supports iCloud downloads, network monitoring, and detailed progress tracking
enum VideoLoadingState: Equatable {
    case idle
    case initializing(progress: Double, message: String)
    case requestingDownload
    case downloadingFromCloud(progress: Double)
    case transferringFile
    case validatingFile
    case creatingAsset
    case generatingThumbnail
    case loadingTrimmerComponents
    case ready(asset: AVAsset, url: URL)
    case error(error: VideoLoadingError, retryAvailable: Bool)

    // MARK: - Computed Properties
    var isLoading: Bool {
        switch self {
        case .initializing, .requestingDownload, .downloadingFromCloud,
             .transferringFile, .validatingFile, .creatingAsset,
             .generatingThumbnail, .loadingTrimmerComponents:
            return true
        case .idle, .ready, .error:
            return false
        }
    }

    var progress: Double {
        switch self {
        case .idle:
            return 0.0
        case .initializing(let progress, _):
            return progress
        case .requestingDownload:
            return 0.1
        case .downloadingFromCloud(let progress):
            return 0.2 + (progress * 0.6)
        case .transferringFile:
            return 0.8
        case .validatingFile:
            return 0.9
        case .creatingAsset:
            return 0.95
        case .generatingThumbnail:
            return 0.98
        case .loadingTrimmerComponents:
            return 0.99
        case .ready:
            return 1.0
        case .error:
            return 0.0
        }
    }

    var statusMessage: String {
        switch self {
        case .idle:
            return "Ready to load video"
        case .initializing(_, let message):
            return message
        case .requestingDownload:
            return "Requesting video from iCloud..."
        case .downloadingFromCloud:
            return "Downloading from iCloud..."
        case .transferringFile:
            return "Transferring video file..."
        case .validatingFile:
            return "Validating video file..."
        case .creatingAsset:
            return "Creating video asset..."
        case .generatingThumbnail:
            return "Generating thumbnail..."
        case .loadingTrimmerComponents:
            return "Preparing trimmer..."
        case .ready:
            return "Video loaded successfully"
        case .error(let error, _):
            return error.localizedDescription
        }
    }

    var canRetry: Bool {
        switch self {
        case .error(_, let retryAvailable):
            return retryAvailable
        default:
            return false
        }
    }
}

// MARK: - Equatable Conformance
extension VideoLoadingState {
    static func == (lhs: VideoLoadingState, rhs: VideoLoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.requestingDownload, .requestingDownload),
             (.transferringFile, .transferringFile),
             (.validatingFile, .validatingFile),
             (.creatingAsset, .creatingAsset),
             (.generatingThumbnail, .generatingThumbnail),
             (.loadingTrimmerComponents, .loadingTrimmerComponents):
            return true

        case (.initializing(let lhsProgress, let lhsMessage),
              .initializing(let rhsProgress, let rhsMessage)):
            return lhsProgress == rhsProgress && lhsMessage == rhsMessage

        case (.downloadingFromCloud(let lhsProgress),
              .downloadingFromCloud(let rhsProgress)):
            return lhsProgress == rhsProgress

        case (.ready(let lhsAsset, let lhsUrl),
              .ready(let rhsAsset, let rhsUrl)):
            return lhsAsset == rhsAsset && lhsUrl == rhsUrl

        case (.error(let lhsError, let lhsRetry),
              .error(let rhsError, let rhsRetry)):
            return lhsError.localizedDescription == rhsError.localizedDescription && lhsRetry == rhsRetry

        default:
            return false
        }
    }
}

// MARK: - Loading Progress Helper
/// Helper struct for detailed loading progress information
/// Uses the existing VideoLoadingProgress from ProgressTypes.swift
extension VideoLoadingProgress {
    var state: VideoLoadingState {
        // Convert LoadingPhase to VideoLoadingState
        switch self.phase {
        case .idle:
            return .idle
        case .initializing:
            return .initializing(progress: self.progress, message: self.message)
        case .requestingDownload:
            return .requestingDownload
        case .downloadingFromCloud:
            return .downloadingFromCloud(progress: self.progress)
        case .transferring:
            return .transferringFile
        case .creatingAsset:
            return .creatingAsset
        case .generatingThumbnail:
            return .generatingThumbnail
        case .loadingTrimmerDuration, .loadingTrimmerTracks, .validatingTrimmer:
            return .loadingTrimmerComponents
        case .validating:
            return .validatingFile
        case .waitingForNetwork:
            return .initializing(progress: self.progress, message: self.message)
        case .loading, .processing, .saving:
            return .initializing(progress: self.progress, message: self.message)
        case .completed, .complete:
            return .ready(asset: AVURLAsset(url: URL(fileURLWithPath: "/dev/null")), url: URL(fileURLWithPath: "/dev/null"))
        case .error(let message):
            return .error(error: .validationFailed(message), retryAvailable: true)
        }
    }
}

// MARK: - AddMoveFlowState Mapping
/// Extension to map VideoLoadingState to AddMoveFlowState for consistent state management
extension VideoLoadingState {
    /// Convert VideoLoadingState to corresponding AddMoveFlowState
    var toAddMoveFlowState: AddMoveFlowState {
        switch self {
        case .idle:
            return .ready
        case .initializing, .requestingDownload, .downloadingFromCloud,
             .transferringFile, .validatingFile, .creatingAsset,
             .generatingThumbnail, .loadingTrimmerComponents:
            return .loadingVideo
        case .ready(_, _):
            return .trimming
        case .error(let error, let retryAvailable):
            return .error(error.localizedDescription, retryAvailable ? "Retry available" : nil)
        }
    }
}

// MARK: - Loading Configuration
/// Configuration for video loading operations
struct VideoLoadingConfiguration {
    let timeoutDuration: TimeInterval
    let retryAttempts: Int
    let allowCellularDownload: Bool
    let preferHighQuality: Bool

    static let `default` = VideoLoadingConfiguration(
        timeoutDuration: 300.0, // 5 minutes
        retryAttempts: 3,
        allowCellularDownload: true,
        preferHighQuality: true
    )

    static let fast = VideoLoadingConfiguration(
        timeoutDuration: 60.0, // 1 minute
        retryAttempts: 1,
        allowCellularDownload: true,
        preferHighQuality: false
    )
}