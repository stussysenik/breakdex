import Foundation
import Combine

// Assuming VideoLoadingProgress is defined elsewhere
public struct VideoLoadingProgress {
    public enum LoadingPhase: String, Sendable {
        case initializing
        case transferring
        case validating
        case creatingAsset
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
        }
    }

    private static func getMessage(for phase: LoadingPhase) -> String {
        switch phase {
        case .initializing: return "Initializing..."
        case .transferring: return "Transferring video..."
        case .validating: return "Validating video..."
        case .creatingAsset: return "Creating asset..."
        }
    }
}

// MARK: - Unified Flow State
/// Simplified flow state that eliminates the dual state system complexity
public enum AddMoveFlowState: Equatable, Hashable, Sendable {
    case ready
    case loading(progressPhase: VideoLoadingProgress.LoadingPhase)
    case replacingVideo(status: String)
    case previewing
    case trimming_setup
    case trimming
    case finalizing(status: String)
    case naming
    case saving
    case success(message: String)
    case error(message: String, underlyingError: String?)

    // MARK: - Computed Properties
    var isLoading: Bool {
        switch self {
        case .loading, .replacingVideo: return true
        default: return false
        }
    }

    // Helper to get loading progress for compatibility
    var loadingProgress: Double {
        switch self {
        case .loading(let phase):
            let progress = VideoLoadingProgress(phase: phase, correlationId: "")
            return progress.progress
        case .replacingVideo: return 0.48
        default: return 0.0
        }
    }

    // Helper to get loading status for compatibility
    var loadingStatus: String {
        switch self {
        case .loading(let phase):
            let progress = VideoLoadingProgress(phase: phase, correlationId: "")
            return progress.message
        case .replacingVideo(let status): return status
        default: return ""
        }
    }

    var canShowPlayer: Bool {
        switch self {
        case .previewing, .trimming_setup, .trimming: return true
        default: return false
        }
    }

    var canShowTrimmer: Bool {
        switch self {
        case .trimming_setup, .trimming: return true
        default: return false
        }
    }

    var isFinalizing: Bool {
        switch self {
        case .finalizing, .saving, .success: return true
        default: return false
        }
    }

    var isInteractive: Bool {
        switch self {
        case .ready, .previewing, .trimming_setup, .trimming, .naming: return true
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