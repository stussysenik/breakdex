import Foundation
import AVFoundation
import OSLog
import CoreMedia

// Use MemoryHelper for memory information
private func getAvailableMemoryMB() -> Double {
    return MemoryHelper.getDetailedMemoryInfo().available
}

// MARK: - Enhanced Video Logger
public class EnhancedVideoLogger {
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "EnhancedVideoLogger")
    private let appLogger: AppLogger
    
    public init(appLogger: AppLogger) {
        self.appLogger = appLogger
    }
    
    // MARK: - Correlation ID Generation
    
    public func generateCorrelationID() -> String {
        return UUID().uuidString
    }
    
    // MARK: - Video Loading Logging
    
    public func logVideoLoadingStart(correlationID: String, source: String) {
        let message = "Starting video loading from \(source)"
        let metadata = [
            "correlationID": correlationID,
            "source": source,
            "timestamp": Date().timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.info(message, metadata: metadata)
        logger.info("🎬 VIDEO_LOADING: [\(correlationID)] \(message)")
    }
    
    public func logAssetLoadingStart(correlationID: String, assetInfo: [String: Any]) {
        let message = "Loading video asset"
        var metadata = assetInfo
        metadata["correlationID"] = correlationID
        metadata["timestamp"] = Date().timeIntervalSince1970
        metadata["availableMemoryMB"] = getAvailableMemoryMB()
        
        appLogger.info(message, metadata: metadata)
        logger.info("🎬 VIDEO_LOADING: [\(correlationID)] \(message)")
    }
    
    public func logAssetLoadingSuccess(correlationID: String, asset: AVAsset, loadTime: TimeInterval) {
        let duration = asset.duration.seconds
        let tracks = asset.tracks
        
        var trackInfo: [[String: Any]] = []
        for track in tracks {
            var info: [String: Any] = [
                "type": track.mediaType.rawValue,
                "enabled": track.isEnabled
            ]
            
            if track.mediaType == .video {
                info["size"] = "\(Int(track.naturalSize.width))x\(Int(track.naturalSize.height))"
                info["frameRate"] = track.nominalFrameRate ?? 0
            }
            
            if track.mediaType == .audio {
                if let formatDescs = track.formatDescriptions as? [Any],
                   let firstDesc = formatDescs.first {
                    let audioFormat = CMAudioFormatDescriptionGetStreamBasicDescription(firstDesc as! CMAudioFormatDescription)
                    if let basicDescription = audioFormat?.pointee {
                        info["channels"] = basicDescription.mChannelsPerFrame
                        info["sampleRate"] = basicDescription.mSampleRate
                    }
                }
            }
            
            trackInfo.append(info)
        }
        
        let message = "Asset loaded successfully in \(String(format: "%.2f", loadTime))s"
        let metadata = [
            "correlationID": correlationID,
            "duration": duration,
            "trackCount": tracks.count,
            "trackInfo": trackInfo,
            "loadTime": loadTime,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.info(message, metadata: metadata)
        logger.info("🎬 VIDEO_LOADING: [\(correlationID)] \(message)")
    }
    
    public func logAssetLoadingFailure(correlationID: String, error: Error, context: String) {
        let message = "Asset loading failed: \(context)"
        let metadata = [
            "correlationID": correlationID,
            "error": error.localizedDescription,
            "context": context,
            "timestamp": Date().timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.error(message, metadata: metadata)
        logger.error("🎬 VIDEO_LOADING: [\(correlationID)] \(message): \(error.localizedDescription)")
    }
    
    // MARK: - Player Initialization Logging
    
    public func logPlayerInitializationStart(correlationID: String, rotationQuarterTurns: Int) {
        let message = "Initializing video player with rotation \(rotationQuarterTurns * 90)°"
        let metadata = [
            "correlationID": correlationID,
            "rotationQuarterTurns": rotationQuarterTurns,
            "timestamp": Date().timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.info(message, metadata: metadata)
        logger.info("🎬 VIDEO_PLAYER: [\(correlationID)] \(message)")
    }
    
    public func logPlayerInitializationSuccess(correlationID: String, player: AVPlayer, initTime: TimeInterval) {
        let message = "Player initialized successfully in \(String(format: "%.2f", initTime))s"
        let metadata = [
            "correlationID": correlationID,
            "playerStatus": player.status.rawValue,
            "initTime": initTime,
            "timestamp": Date().timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.info(message, metadata: metadata)
        logger.info("🎬 VIDEO_PLAYER: [\(correlationID)] \(message)")
    }
    
    public func logPlayerInitializationFailure(correlationID: String, error: Error) {
        let message = "Player initialization failed"
        let metadata = [
            "correlationID": correlationID,
            "error": error.localizedDescription,
            "timestamp": Date().timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.error(message, metadata: metadata)
        logger.error("🎬 VIDEO_PLAYER: [\(correlationID)] \(message): \(error.localizedDescription)")
    }
    
    // MARK: - Player Readiness Logging
    
    public func logPlayerReadinessCheckStart(correlationID: String) {
        let message = "Checking player readiness"
        let metadata = [
            "correlationID": correlationID,
            "timestamp": Date().timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.info(message, metadata: metadata)
        logger.info("🎬 VIDEO_PLAYER: [\(correlationID)] \(message)")
    }
    
    public func logPlayerReadinessSuccess(correlationID: String, waitTime: TimeInterval) {
        let message = "Player is ready after \(String(format: "%.2f", waitTime))s"
        let metadata = [
            "correlationID": correlationID,
            "waitTime": waitTime,
            "timestamp": Date().timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.info(message, metadata: metadata)
        logger.info("🎬 VIDEO_PLAYER: [\(correlationID)] \(message)")
    }
    
    public func logPlayerReadinessTimeout(correlationID: String, timeout: TimeInterval) {
        let message = "Player readiness timeout after \(String(format: "%.2f", timeout))s"
        let metadata = [
            "correlationID": correlationID,
            "timeout": timeout,
            "timestamp": Date().timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.error(message, metadata: metadata)
        logger.error("🎬 VIDEO_PLAYER: [\(correlationID)] \(message)")
    }
    
    // MARK: - Playback Logging
    
    public func logPlaybackStart(correlationID: String, player: AVPlayer) {
        let message = "Starting video playback"
        let metadata = [
            "correlationID": correlationID,
            "playerStatus": player.status.rawValue,
            "rate": player.rate,
            "timestamp": Date().timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.info(message, metadata: metadata)
        logger.info("🎬 VIDEO_PLAYBACK: [\(correlationID)] \(message)")
    }
    
    public func logPlaybackPause(correlationID: String, player: AVPlayer) {
        let message = "Pausing video playback"
        let metadata = [
            "correlationID": correlationID,
            "playerStatus": player.status.rawValue,
            "rate": player.rate,
            "timestamp": Date().timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.info(message, metadata: metadata)
        logger.info("🎬 VIDEO_PLAYBACK: [\(correlationID)] \(message)")
    }
    
    public func logPlaybackStop(correlationID: String, player: AVPlayer) {
        let message = "Stopping video playback"
        let metadata = [
            "correlationID": correlationID,
            "playerStatus": player.status.rawValue,
            "rate": player.rate,
            "timestamp": Date().timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.info(message, metadata: metadata)
        logger.info("🎬 VIDEO_PLAYBACK: [\(correlationID)] \(message)")
    }
    
    public func logPlaybackError(correlationID: String, player: AVPlayer, error: Error) {
        let message = "Playback error occurred"
        let metadata = [
            "correlationID": correlationID,
            "playerStatus": player.status.rawValue,
            "rate": player.rate,
            "error": error.localizedDescription,
            "timestamp": Date().timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.error(message, metadata: metadata)
        logger.error("🎬 VIDEO_PLAYBACK: [\(correlationID)] \(message): \(error.localizedDescription)")
    }
    
    // MARK: - Health Monitoring Logging
    
    public func logHealthMonitoringStart(correlationID: String, asset: AVAsset) {
        let message = "Starting video health monitoring"
        let metadata = [
            "correlationID": correlationID,
            "assetDuration": asset.duration.seconds,
            "timestamp": Date().timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.info(message, metadata: metadata)
        logger.info("🏥 VIDEO_HEALTH: [\(correlationID)] \(message)")
    }
    
    public func logHealthMonitoringStop(correlationID: String) {
        let message = "Stopping video health monitoring"
        let metadata = [
            "correlationID": correlationID,
            "timestamp": Date().timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.info(message, metadata: metadata)
        logger.info("🏥 VIDEO_HEALTH: [\(correlationID)] \(message)")
    }
    
    public func logHealthReport(correlationID: String, report: VideoHealthReport) {
        let message = "Health report: \(report.state.description)"
        let metadata = [
            "correlationID": correlationID,
            "healthState": report.state.description,
            "memoryUsageMB": report.memoryUsage / (1024 * 1024),
            "cpuUsage": report.cpuUsage,
            "playbackStatus": report.playbackStatus,
            "additionalInfo": report.additionalInfo,
            "timestamp": report.timestamp.timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        switch report.state {
        case .healthy:
            appLogger.info(message, metadata: metadata)
            logger.info("🏥 VIDEO_HEALTH: [\(correlationID)] \(message)")
        case .warning:
            appLogger.warning(message, metadata: metadata)
            logger.warning("⚠️ VIDEO_HEALTH: [\(correlationID)] \(message)")
        case .critical:
            appLogger.critical(message, metadata: metadata)
            logger.error("🚨 VIDEO_HEALTH: [\(correlationID)] \(message)")
        }
    }
    
    // MARK: - Error Handling and Recovery Logging
    
    public func logErrorHandlingStart(correlationID: String, error: Error, severity: String) {
        let message = "Handling error with severity: \(severity)"
        let metadata = [
            "correlationID": correlationID,
            "error": error.localizedDescription,
            "severity": severity,
            "timestamp": Date().timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.error(message, metadata: metadata)
        logger.error("🔧 VIDEO_ERROR: [\(correlationID)] \(message): \(error.localizedDescription)")
    }
    
    public func logRecoveryAttemptStart(correlationID: String, attempt: Int, maxAttempts: Int) {
        let message = "Starting recovery attempt \(attempt)/\(maxAttempts)"
        let metadata = [
            "correlationID": correlationID,
            "attempt": attempt,
            "maxAttempts": maxAttempts,
            "timestamp": Date().timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.info(message, metadata: metadata)
        logger.info("🔄 VIDEO_RECOVERY: [\(correlationID)] \(message)")
    }
    
    public func logRecoverySuccess(correlationID: String, recoveryMessage: String, recoveryTime: TimeInterval) {
        let message = "Recovery successful: \(recoveryMessage)"
        let metadata = [
            "correlationID": correlationID,
            "recoveryMessage": recoveryMessage,
            "recoveryTime": recoveryTime,
            "timestamp": Date().timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.info(message, metadata: metadata)
        logger.info("✅ VIDEO_RECOVERY: [\(correlationID)] \(message)")
    }
    
    public func logRecoveryFailure(correlationID: String, failureMessage: String) {
        let message = "Recovery failed: \(failureMessage)"
        let metadata = [
            "correlationID": correlationID,
            "failureMessage": failureMessage,
            "timestamp": Date().timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.error(message, metadata: metadata)
        logger.error("❌ VIDEO_RECOVERY: [\(correlationID)] \(message)")
    }
    
    // MARK: - Memory Logging
    
    public func logMemoryUsage(correlationID: String, context: String) {
        let availableMemoryMB = getAvailableMemoryMB()
        
        let message = "Memory usage in context: \(context)"
        let metadata = [
            "correlationID": correlationID,
            "context": context,
            "availableMemoryMB": availableMemoryMB,
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        appLogger.info(message, metadata: metadata)
        logger.info("🧠 VIDEO_MEMORY: [\(correlationID)] \(context): \(String(format: "%.1f", availableMemoryMB)) MB available")
    }
    
    public func logMemoryWarning(correlationID: String, context: String, availableMemory: Int64) {
        let availableMemoryMB = getAvailableMemoryMB()
        
        let message = "Memory warning in context: \(context)"
        let metadata = [
            "correlationID": correlationID,
            "context": context,
            "availableMemoryMB": availableMemoryMB,
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        appLogger.warning(message, metadata: metadata)
        logger.warning("⚠️ VIDEO_MEMORY: [\(correlationID)] \(context): Low memory - \(String(format: "%.1f", availableMemoryMB)) MB available")
    }
    
    public func logMemoryCritical(correlationID: String, context: String, availableMemory: Int64) {
        let availableMemoryMB = getAvailableMemoryMB()
        
        let message = "Critical memory in context: \(context)"
        let metadata = [
            "correlationID": correlationID,
            "context": context,
            "availableMemoryMB": availableMemoryMB,
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        appLogger.critical(message, metadata: metadata)
        logger.error("🚨 VIDEO_MEMORY: [\(correlationID)] \(context): Critical memory - \(String(format: "%.1f", availableMemoryMB)) MB available")
    }
    
    // MARK: - Teardown Logging
    
    public func logTeardownStart(correlationID: String) {
        let message = "Starting video coordinator teardown"
        let metadata = [
            "correlationID": correlationID,
            "timestamp": Date().timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.info(message, metadata: metadata)
        logger.info("🔄 VIDEO_TEARDOWN: [\(correlationID)] \(message)")
    }
    
    public func logTeardownComplete(correlationID: String, cleanupActions: [String]) {
        let message = "Video coordinator teardown completed"
        let metadata = [
            "correlationID": correlationID,
            "cleanupActions": cleanupActions,
            "timestamp": Date().timeIntervalSince1970,
            "availableMemoryMB": getAvailableMemoryMB()
        ] as [String : Any]
        
        appLogger.info(message, metadata: metadata)
        logger.info("✅ VIDEO_TEARDOWN: [\(correlationID)] \(message)")
    }
}