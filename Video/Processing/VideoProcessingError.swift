import Foundation

// MARK: - Video Processing Errors
public enum VideoProcessingError: LocalizedError {
    case memoryLimitExceeded(used: Int64, available: Int64)
    case invalidStateTransition(from: VideoState, to: VideoState)
    case videoLoadingFailed(identifier: String, underlyingError: Error)
    case videoProcessingFailed(operation: String, underlyingError: Error)
    case assetCreationFailed
    case playerInitializationFailed
    case readinessTimeout
    
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
        }
    }
}