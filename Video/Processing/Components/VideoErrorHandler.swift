import Foundation

public enum VideoError: LocalizedError {
    case assetLoadingFailed(underlyingError: Error?)
    case playerInitializationFailed(underlyingError: Error?)
    case readinessTimeout
    case playbackFailed(underlyingError: Error?)
    case unknownError(Error?)
    
    public var errorDescription: String? {
        switch self {
        case .assetLoadingFailed(let underlyingError):
            return "Failed to load video asset. \(underlyingError?.localizedDescription ?? "")"
        case .playerInitializationFailed(let underlyingError):
            return "Failed to initialize video player. \(underlyingError?.localizedDescription ?? "")"
        case .readinessTimeout:
            return "Video player readiness timeout. Please try again."
        case .playbackFailed(let underlyingError):
            return "Video playback failed. \(underlyingError?.localizedDescription ?? "")"
        case .unknownError(let underlyingError):
            return "An unknown error occurred. \(underlyingError?.localizedDescription ?? "")"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .assetLoadingFailed:
            return "Please check if the video file exists and is accessible."
        case .playerInitializationFailed:
            return "Please try restarting the application."
        case .readinessTimeout:
            return "Please try again with a different video or check your network connection."
        case .playbackFailed:
            return "Please try playing the video again."
        case .unknownError:
            return "Please try again or contact support if the issue persists."
        }
    }
}

public class VideoErrorHandler {
    
    public static func handle(_ error: Error, correlationID: String) -> VideoError {
        // Log the error with correlation ID
        VideoLogger.error("Error occurred: \(error.localizedDescription)", error: error, category: "ERROR_HANDLER", correlationID: correlationID)
        
        // Convert to VideoError based on error type
        if let videoError = error as? VideoError {
            return videoError
        }
        
        if let assetLoaderError = error as? VideoAssetLoader.VideoAssetLoaderError {
            switch assetLoaderError {
            case .itemIdentifierMissing, .assetNotFound, .avAssetCreationFailed, .unsupportedFileType, .dataUnavailable, .temporaryFileError:
                return .assetLoadingFailed(underlyingError: assetLoaderError)
            }
        }
        
        if let playerInitializerError = error as? PlayerInitializer.PlayerInitializerError {
            switch playerInitializerError {
            case .playerCreationFailed, .playerItemCreationFailed:
                return .playerInitializationFailed(underlyingError: playerInitializerError)
            }
        }
        
        if let readinessMonitorError = error as? ReadinessMonitor.ReadinessMonitorError {
            switch readinessMonitorError {
            case .readinessTimeout:
                return .readinessTimeout
            case .playerItemUnavailable, .playerUnavailable:
                return .playerInitializationFailed(underlyingError: readinessMonitorError)
            }
        }
        
        // Default case
        return .unknownError(error)
    }
    
    public static func getUserMessage(for error: VideoError) -> String {
        return error.errorDescription ?? "An unknown error occurred."
    }
    
    public static func getRecoverySuggestion(for error: VideoError) -> String? {
        return error.recoverySuggestion
    }
}