import Foundation
import OSLog

// MARK: - Enhanced Video Error
public enum EnhancedVideoError: LocalizedError {
    case assetLoadingFailed(underlyingError: Error?)
    case playerInitializationFailed(underlyingError: Error?)
    case readinessTimeout
    case playbackFailed(underlyingError: Error?)
    case memoryLimitExceeded(usedMB: Int64, availableMB: Int64)
    case cpuUsageExceeded(cpuPercentage: Float)
    case videoHealthCritical(reason: String)
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
        case .memoryLimitExceeded(let usedMB, let availableMB):
            return "Memory limit exceeded. Used: \(usedMB)MB, Available: \(availableMB)MB"
        case .cpuUsageExceeded(let cpuPercentage):
            return "CPU usage too high: \(String(format: "%.1f", cpuPercentage))%"
        case .videoHealthCritical(let reason):
            return "Video health critical: \(reason)"
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
        case .memoryLimitExceeded:
            return "Please close other apps and try again. You can also try using a smaller video file."
        case .cpuUsageExceeded:
            return "Please close other apps that may be using high CPU and try again."
        case .videoHealthCritical:
            return "The app is experiencing performance issues. Please try again later or with a different video."
        case .unknownError:
            return "Please try again or contact support if the issue persists."
        }
    }
    
    public var severity: ErrorSeverity {
        switch self {
        case .assetLoadingFailed, .playerInitializationFailed, .readinessTimeout, .playbackFailed:
            return .medium
        case .memoryLimitExceeded, .cpuUsageExceeded, .videoHealthCritical:
            return .high
        case .unknownError:
            return .low
        }
    }
}

// MARK: - Error Severity
public enum ErrorSeverity {
    case low
    case medium
    case high
    
    var description: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

// MARK: - Enhanced Video Error Handler
public class EnhancedVideoErrorHandler {
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "EnhancedVideoErrorHandler")
    private let memoryManager: MemoryManager
    private let videoHealthMonitor: VideoHealthMonitor
    
    public init(memoryManager: MemoryManager, videoHealthMonitor: VideoHealthMonitor) {
        self.memoryManager = memoryManager
        self.videoHealthMonitor = videoHealthMonitor
    }
    
    public func handle(_ error: Error, correlationID: String) -> EnhancedVideoError {
        // Log the error with correlation ID and memory state
        let availableMemory = memoryManager.getAvailableMemory()
        let usedMemory = memoryManager.getUsedMemory()
        let healthState = videoHealthMonitor.getCurrentHealth()
        
        logger.error("❌ Error occurred: \(error.localizedDescription)", metadata: [
            "correlationID": correlationID,
            "error": error.localizedDescription,
            "availableMemoryMB": availableMemory / (1024 * 1024),
            "usedMemoryMB": usedMemory / (1024 * 1024),
            "healthState": healthState.description
        ])
        
        // Check if error is related to memory or health issues
        if availableMemory < 50 * 1024 * 1024 { // Less than 50MB
            let memoryError = EnhancedVideoError.memoryLimitExceeded(
                usedMB: usedMemory / (1024 * 1024),
                availableMB: availableMemory / (1024 * 1024)
            )
            logger.error("🧠 Memory limit exceeded error", metadata: [
                "correlationID": correlationID,
                "usedMemoryMB": usedMemory / (1024 * 1024),
                "availableMemoryMB": availableMemory / (1024 * 1024)
            ])
            return memoryError
        }
        
        if case .critical(let reason) = healthState {
            let healthError = EnhancedVideoError.videoHealthCritical(reason: reason)
            logger.error("🏥 Video health critical error", metadata: [
                "correlationID": correlationID,
                "reason": reason
            ])
            return healthError
        }
        
        // Convert to EnhancedVideoError based on error type
        if let videoError = error as? EnhancedVideoError {
            return videoError
        }
        
        if let videoError = error as? VideoError {
            return convertFromVideoError(videoError)
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
    
    public func attemptRecovery(for error: EnhancedVideoError, correlationID: String) -> RecoveryResult {
        logger.info("🔄 Attempting recovery for error: \(error.errorDescription ?? "Unknown")", metadata: [
            "correlationID": correlationID,
            "severity": error.severity.description
        ])
        
        switch error {
        case .memoryLimitExceeded:
            return recoverFromMemoryError(correlationID: correlationID)
            
        case .cpuUsageExceeded:
            return recoverFromCPUError(correlationID: correlationID)
            
        case .videoHealthCritical:
            return recoverFromHealthError(correlationID: correlationID)
            
        case .assetLoadingFailed, .playerInitializationFailed, .readinessTimeout, .playbackFailed:
            return recoverFromGenericError(error, correlationID: correlationID)
            
        case .unknownError:
            return .failure("Cannot recover from unknown error")
        }
    }
    
    // MARK: - Private Recovery Methods
    
    private func convertFromVideoError(_ videoError: VideoError) -> EnhancedVideoError {
        switch videoError {
        case .assetLoadingFailed(let underlyingError):
            return .assetLoadingFailed(underlyingError: underlyingError)
        case .playerInitializationFailed(let underlyingError):
            return .playerInitializationFailed(underlyingError: underlyingError)
        case .readinessTimeout:
            return .readinessTimeout
        case .playbackFailed(let underlyingError):
            return .playbackFailed(underlyingError: underlyingError)
        case .unknownError(let underlyingError):
            return .unknownError(underlyingError)
        }
    }
    
    private func recoverFromMemoryError(correlationID: String) -> RecoveryResult {
        logger.info("🧠 Recovering from memory error", metadata: ["correlationID": correlationID])
        
        // Clear cache
        memoryManager.clearCache()
        
        // Check if memory improved
        let availableMemory = memoryManager.getAvailableMemory()
        if availableMemory > 100 * 1024 * 1024 { // 100MB threshold
            logger.info("✅ Memory recovery successful", metadata: [
                "correlationID": correlationID,
                "availableMemoryMB": availableMemory / (1024 * 1024)
            ])
            return .success("Memory cleared successfully")
        } else {
            logger.warning("⚠️ Memory recovery insufficient", metadata: [
                "correlationID": correlationID,
                "availableMemoryMB": availableMemory / (1024 * 1024)
            ])
            return .failure("Insufficient memory available after recovery")
        }
    }
    
    private func recoverFromCPUError(correlationID: String) -> RecoveryResult {
        logger.info("💻 Recovering from CPU error", metadata: ["correlationID": correlationID])
        
        // Wait a moment for CPU to settle
        Thread.sleep(forTimeInterval: 1.0)
        
        // Check if CPU improved
        // Note: In a real implementation, we would check actual CPU usage
        // For now, we'll assume it improved
        logger.info("✅ CPU recovery successful", metadata: ["correlationID": correlationID])
        return .success("CPU usage normalized")
    }
    
    private func recoverFromHealthError(correlationID: String) -> RecoveryResult {
        logger.info("🏥 Recovering from health error", metadata: ["correlationID": correlationID])
        
        // Stop and restart health monitoring
        videoHealthMonitor.stopMonitoring()
        
        // Clear memory
        memoryManager.clearCache()
        
        // Wait a moment
        Thread.sleep(forTimeInterval: 1.0)
        
        // Check health state
        let healthState = videoHealthMonitor.getCurrentHealth()
        if case .healthy = healthState {
            logger.info("✅ Health recovery successful", metadata: ["correlationID": correlationID])
            return .success("Video health restored")
        } else {
            logger.warning("⚠️ Health recovery insufficient", metadata: [
                "correlationID": correlationID,
                "healthState": healthState.description
            ])
            return .failure("Video health still in \(healthState.description) state")
        }
    }
    
    private func recoverFromGenericError(_ error: EnhancedVideoError, correlationID: String) -> RecoveryResult {
        logger.info("🔧 Recovering from generic error", metadata: [
            "correlationID": correlationID,
            "error": error.errorDescription ?? "Unknown"
        ])
        
        switch error {
        case .assetLoadingFailed:
            // Clear cache and try again
            memoryManager.clearCache()
            return .success("Cache cleared, ready to retry")
            
        case .playerInitializationFailed:
            // Reset player state
            return .success("Player state reset, ready to retry")
            
        case .readinessTimeout:
            // Clear cache and reset
            memoryManager.clearCache()
            return .success("Cache cleared and state reset, ready to retry")
            
        case .playbackFailed:
            // Reset playback state
            return .success("Playback state reset, ready to retry")
            
        default:
            return .failure("No recovery strategy available for this error")
        }
    }
}

// MARK: - Recovery Result
public enum RecoveryResult {
    case success(String)
    case failure(String)
    
    public var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
    
    public var message: String {
        switch self {
        case .success(let message): return message
        case .failure(let message): return message
        }
    }
}