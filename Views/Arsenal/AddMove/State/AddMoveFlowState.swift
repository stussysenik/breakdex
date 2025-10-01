import Foundation
import Combine

// Simplified VideoLoadingProgress for compatibility with existing services
public struct VideoLoadingProgress {
    public enum LoadingPhase: String, Sendable {
        case initializing
        case transferring
        case validating
        case creatingAsset
        case loadingTrimmerDuration
        case loadingTrimmerTracks
        case validatingTrimmer
    }

    public let phase: LoadingPhase
    public let correlationId: String
    public let progress: Double
    public let message: String

    public init(phase: LoadingPhase, correlationId: String) {
        self.phase = phase
        self.correlationId = correlationId
        self.progress = Self.calculateProgress(for: phase)
        self.message = Self.getMessage(for: phase)
    }

    private static func calculateProgress(for phase: LoadingPhase) -> Double {
        switch phase {
        case .initializing: return 0.1
        case .transferring: return 0.4
        case .validating: return 0.7
        case .creatingAsset: return 0.9
        case .loadingTrimmerDuration: return 0.95
        case .loadingTrimmerTracks: return 0.97
        case .validatingTrimmer: return 1.0  // Fixed: was 0.99, now goes to 100%
        }
    }

    private static func getMessage(for phase: LoadingPhase) -> String {
        switch phase {
        case .initializing: return "Initializing..."
        case .transferring: return "Transferring video..."
        case .validating: return "Validating video..."
        case .creatingAsset: return "Creating asset..."
        case .loadingTrimmerDuration: return "Loading trimmer duration..."
        case .loadingTrimmerTracks: return "Loading trimmer tracks..."
        case .validatingTrimmer: return "Validating trimmer setup..."
        }
    }
}

// Simplified progress tracking for loading stages
public struct SimpleProgress: Sendable, Equatable, Hashable {
    public let value: Double
    public let message: String

    public init(value: Double, message: String) {
        self.value = max(0.0, min(1.0, value)) // Clamp between 0 and 1
        self.message = message
    }

    public var percentage: Int {
        return Int(value * 100)
    }

    // Create from VideoLoadingProgress for compatibility
    public init(from videoProgress: VideoLoadingProgress) {
        self.value = videoProgress.progress
        self.message = videoProgress.message
    }
}

// MARK: - Simplified Flow State
/// Simplified 5-stage flow state that eliminates complex transitions and 99% stuck issues
/// Note: We keep the old VideoLoadingProgress struct for compatibility but use SimpleProgress in states
public enum AddMoveFlowState: Equatable, Hashable, Sendable {
    case ready
    case loadingVideo(progress: SimpleProgress)
    case trimming
    case loadingTrimmedAsset(progress: SimpleProgress)
    case naming
    case saving
    case success(message: String)
    case error(message: String, underlyingError: String?)

    // Backward compatibility - can still be created from old states
    public init(from oldState: AddMoveFlowState) {
        switch oldState {
        case .ready: self = .ready
        case .loadingVideo(let progress): self = .loadingVideo(progress: progress)
        case .trimming: self = .trimming
        case .loadingTrimmedAsset(let progress): self = .loadingTrimmedAsset(progress: progress)
        case .naming: self = .naming
        case .saving: self = .saving
        case .success(let message): self = .success(message: message)
        case .error(let message, let underlying): self = .error(message: message, underlyingError: underlying)
        }
    }

    // MARK: - State Properties

    /// Check if this is a terminal state (success or error)
    public var isTerminalState: Bool {
        switch self {
        case .success, .error:
            return true
        default:
            return false
        }
    }

    /// Check if this state allows user interaction
    public var isInteractive: Bool {
        switch self {
        case .trimming, .naming:
            return true
        case .ready, .loadingVideo, .loadingTrimmedAsset, .saving, .success, .error:
            return false
        }
    }

    // MARK: - Computed Properties
    var isLoading: Bool {
        switch self {
        case .loadingVideo, .loadingTrimmedAsset: return true
        default: return false
        }
    }

    // Helper to get loading progress for compatibility
    var loadingProgress: Double {
        switch self {
        case .loadingVideo(let progress), .loadingTrimmedAsset(let progress):
            return progress.value
        default: return 0.0
        }
    }

    // Helper to get loading status for compatibility
    var loadingStatus: String {
        switch self {
        case .loadingVideo(let progress), .loadingTrimmedAsset(let progress):
            return progress.message
        default: return ""
        }
    }

    var canShowPlayer: Bool {
        switch self {
        case .trimming, .loadingTrimmedAsset: return true
        default: return false
        }
    }

    var canShowTrimmer: Bool {
        switch self {
        case .trimming: return true
        default: return false
        }
    }

    var isFinalizing: Bool {
        switch self {
        case .saving, .success: return true
        default: return false
        }
    }
}

// MARK: - Player State
/// Unified player state that replaces the dual state system
public enum PlayerState: Equatable, Hashable, Sendable {
    case idle
    case loading
    case ready
    case playing
    case paused
    case seeking
    case error

    var isReady: Bool {
        switch self {
        case .ready, .playing, .paused: return true
        default: return false
        }
    }

    var isActive: Bool {
        switch self {
        case .playing, .paused, .seeking: return true
        default: return false
        }
    }

    var canPlay: Bool {
        switch self {
        case .ready, .paused: return true
        default: return false
        }
    }

    var canPause: Bool {
        switch self {
        case .playing: return true
        default: return false
        }
    }

    var canSeek: Bool {
        switch self {
        case .ready, .playing, .paused: return true
        default: return false
        }
    }
}