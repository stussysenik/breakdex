import Foundation
import AVFoundation
import OSLog

// MARK: - Video Health State
public enum VideoHealthState {
    case healthy
    case warning(reason: String)
    case critical(reason: String)
    
    var description: String {
        switch self {
        case .healthy:
            return "Healthy"
        case .warning(let reason):
            return "Warning: \(reason)"
        case .critical(let reason):
            return "Critical: \(reason)"
        }
    }
}

// MARK: - Video Health Monitor Protocol
public protocol VideoHealthMonitor {
    func startMonitoring(asset: AVAsset)
    func stopMonitoring()
    func pauseMonitoring()
    func resumeMonitoring()
    func getCurrentHealth() -> VideoHealthState
    func getCurrentHealthStatus() -> VideoHealthStatus
    func getHealthReports() -> AsyncStream<VideoHealthReport>
    func getHealthStatusReports() -> AsyncStream<VideoHealthStatusReport>
}

// MARK: - Video Health Report
public struct VideoHealthReport {
    let timestamp: Date
    let state: VideoHealthState
    let memoryUsage: Int64
    let cpuUsage: Float
    let playbackStatus: String
    let additionalInfo: [String: String]
}

// MARK: - Video Health Status Report
public struct VideoHealthStatusReport {
    let timestamp: Date
    let status: VideoHealthStatus
    let memoryUsage: Int64
    let cpuUsage: Float
    let playbackStatus: String
    let additionalInfo: [String: String]
}

// MARK: - Video Health Monitor Implementation
final class VideoHealthMonitorImpl: VideoHealthMonitor {
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "VideoHealthMonitor")
    private let memoryManager: MemoryManager
    private var monitoringTask: Task<Void, Never>?
    private var continuation: AsyncStream<VideoHealthReport>.Continuation?
    private var statusContinuation: AsyncStream<VideoHealthStatusReport>.Continuation?
    private var currentAsset: AVAsset?
    
    // Monitoring intervals
    private let healthCheckInterval: TimeInterval = 2.0 // Check every 2 seconds
    private let memoryWarningThreshold: Int64 = 150 * 1024 * 1024 // 150MB
    private let memoryCriticalThreshold: Int64 = 50 * 1024 * 1024 // 50MB
    private let cpuWarningThreshold: Float = 80.0 // 80% CPU usage
    private let cpuCriticalThreshold: Float = 95.0 // 95% CPU usage
    
    init(memoryManager: MemoryManager) {
        self.memoryManager = memoryManager
        logger.info("🏥 VideoHealthMonitor initialized")
    }
    
    func startMonitoring(asset: AVAsset) {
        logger.info("🏥 Starting video health monitoring")
        
        // Stop any existing monitoring
        stopMonitoring()
        
        currentAsset = asset
        
        // Start the monitoring task
        monitoringTask = Task {
            await monitorVideoHealth()
        }
        
        logger.info("🏥 Video health monitoring started")
    }
    
    func stopMonitoring() {
        logger.info("🏥 Stopping video health monitoring")
        
        monitoringTask?.cancel()
        monitoringTask = nil
        continuation?.finish()
        continuation = nil
        statusContinuation?.finish()
        statusContinuation = nil
        currentAsset = nil
        
        logger.info("🏥 Video health monitoring stopped")
    }
    
    func pauseMonitoring() {
        logger.info("🏥 Pausing video health monitoring")
        logger.info("🏥 Current monitoring task exists: \(self.monitoringTask != nil)")
        logger.info("🏥 Asset preserved: \(self.currentAsset != nil)")
        
        self.monitoringTask?.cancel()
        self.monitoringTask = nil
        // Keep continuations and asset for quick resume
        
        logger.info("🏥 📊 Memory after monitoring pause: \(self.memoryManager.getAvailableMemory() / (1024*1024)) MB available")
        
        logger.info("🏥 ✅ Video health monitoring paused")
    }
    
    func resumeMonitoring() {
        logger.info("🏥 Resuming video health monitoring")
        logger.info("🏥 Current asset available: \(self.currentAsset != nil)")
        logger.info("🏥 Current monitoring task exists: \(self.monitoringTask != nil)")
        
        guard self.currentAsset != nil else {
            logger.warning("🏥 ⚠️ Cannot resume monitoring - no asset")
            logger.info("🏥 This indicates improper state management")
            return
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Restart monitoring with existing asset
        self.monitoringTask = Task {
            await self.monitorVideoHealth()
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let resumeTime = (endTime - startTime) * 1000
        logger.info("🏥 ⚡ Monitoring resume took \(String(format: "%.2f", resumeTime))ms")
        logger.info("🏥 📊 Memory after monitoring resume: \(self.memoryManager.getAvailableMemory() / (1024*1024)) MB available")
        
        logger.info("🏥 ✅ Video health monitoring resumed successfully")
    }
    
    func getCurrentHealth() -> VideoHealthState {
        let availableMemory = memoryManager.getAvailableMemory()
        let cpuUsage = getCurrentCPUUsage()
        
        if availableMemory < memoryCriticalThreshold {
            return .critical(reason: "Memory critically low: \(availableMemory / (1024 * 1024))MB")
        } else if availableMemory < memoryWarningThreshold {
            return .warning(reason: "Memory low: \(availableMemory / (1024 * 1024))MB")
        } else if cpuUsage > cpuCriticalThreshold {
            return .critical(reason: "CPU usage critically high: \(String(format: "%.1f", cpuUsage))%")
        } else if cpuUsage > cpuWarningThreshold {
            return .warning(reason: "CPU usage high: \(String(format: "%.1f", cpuUsage))%")
        } else {
            return .healthy
        }
    }
    
    func getCurrentHealthStatus() -> VideoHealthStatus {
        let healthState = getCurrentHealth()
        return VideoHealthStatus.from(healthState)
    }
    
    func getHealthReports() -> AsyncStream<VideoHealthReport> {
        return AsyncStream { continuation in
            self.continuation = continuation
        }
    }
    
    func getHealthStatusReports() -> AsyncStream<VideoHealthStatusReport> {
        return AsyncStream { continuation in
            self.statusContinuation = continuation
        }
    }
    
    // MARK: - Private Methods
    
    private func monitorVideoHealth() async {
        await withTaskCancellationHandler {
            while !Task.isCancelled {
                let report = generateHealthReport()
                let statusReport = generateHealthStatusReport()
                
                // Log the health report
                logHealthReport(report)
                
                // Send the report to the stream
                continuation?.yield(report)
                statusContinuation?.yield(statusReport)
                
                // Take action based on health state
                handleHealthState(report.state)
                
                // Wait for the next check
                try? await Task.sleep(nanoseconds: UInt64(healthCheckInterval * 1_000_000_000))
            }
        } onCancel: {
            logger.info("🏥 Video health monitoring cancelled")
        }
    }
    
    private func generateHealthReport() -> VideoHealthReport {
        let memoryUsage = memoryManager.getUsedMemory()
        let cpuUsage = getCurrentCPUUsage()
        let healthState = getCurrentHealth()
        
        // Get additional info about the asset
        var additionalInfo: [String: String] = [:]
        if let asset = currentAsset {
            additionalInfo["duration"] = String(format: "%.2f", asset.duration.seconds)
            additionalInfo["tracks"] = "\(asset.tracks.count)"
            
            if let videoTrack = asset.tracks(withMediaType: .video).first {
                let size = videoTrack.naturalSize
                additionalInfo["videoSize"] = "\(Int(size.width))x\(Int(size.height))"
                
                // nominalFrameRate is not optional, so no conditional binding needed
                let frameRate = videoTrack.nominalFrameRate
                additionalInfo["frameRate"] = String(format: "%.1f", frameRate)
            }
        }
        
        return VideoHealthReport(
            timestamp: Date(),
            state: healthState,
            memoryUsage: memoryUsage,
            cpuUsage: cpuUsage,
            playbackStatus: "playing", // This could be updated with actual playback status
            additionalInfo: additionalInfo
        )
    }
    
    private func generateHealthStatusReport() -> VideoHealthStatusReport {
        let memoryUsage = memoryManager.getUsedMemory()
        let cpuUsage = getCurrentCPUUsage()
        let healthStatus = getCurrentHealthStatus()
        
        // Get additional info about the asset
        var additionalInfo: [String: String] = [:]
        if let asset = currentAsset {
            additionalInfo["duration"] = String(format: "%.2f", asset.duration.seconds)
            additionalInfo["tracks"] = "\(asset.tracks.count)"
            
            if let videoTrack = asset.tracks(withMediaType: .video).first {
                let size = videoTrack.naturalSize
                additionalInfo["videoSize"] = "\(Int(size.width))x\(Int(size.height))"
                
                // nominalFrameRate is not optional, so no conditional binding needed
                let frameRate = videoTrack.nominalFrameRate
                additionalInfo["frameRate"] = String(format: "%.1f", frameRate)
            }
        }
        
        return VideoHealthStatusReport(
            timestamp: Date(),
            status: healthStatus,
            memoryUsage: memoryUsage,
            cpuUsage: cpuUsage,
            playbackStatus: "playing", // This could be updated with actual playback status
            additionalInfo: additionalInfo
        )
    }
    
    private func logHealthReport(_ report: VideoHealthReport) {
        let memoryMB = report.memoryUsage / (1024 * 1024)
        let formattedTime = DateFormatter.healthLogFormatter.string(from: report.timestamp)
        
        switch report.state {
        case .healthy:
            logger.info("🏥 [\(formattedTime)] Health: \(report.state.description) | Memory: \(memoryMB)MB | CPU: \(String(format: "%.1f", report.cpuUsage))%")
        case .warning:
            logger.warning("⚠️ [\(formattedTime)] Health: \(report.state.description) | Memory: \(memoryMB)MB | CPU: \(String(format: "%.1f", report.cpuUsage))%")
        case .critical:
            logger.error("🚨 [\(formattedTime)] Health: \(report.state.description) | Memory: \(memoryMB)MB | CPU: \(String(format: "%.1f", report.cpuUsage))%")
        }
        
        // Log additional info
        if !report.additionalInfo.isEmpty {
            let infoString = report.additionalInfo.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            logger.debug("🏥 Additional info: \(infoString)")
        }
    }
    
    private func handleHealthState(_ state: VideoHealthState) {
        switch state {
        case .healthy:
            // No action needed for healthy state
            break
            
        case .warning(let reason):
            logger.warning("🏥 Taking action for warning state: \(reason)")
            // Take moderate actions for warning state
            memoryManager.clearCache()
            
        case .critical(let reason):
            logger.error("🏥 Taking action for critical state: \(reason)")
            // Take aggressive actions for critical state
            memoryManager.handleMemoryWarning()
            
            // Additional critical actions
            URLCache.shared.removeAllCachedResponses()
            
            // Notify about critical health state
            NotificationCenter.default.post(
                name: .videoHealthCritical,
                object: nil,
                userInfo: ["reason": reason]
            )
        }
    }
    
    private func getCurrentCPUUsage() -> Float {
        var totalUsageOfCPU: Float = 0.0
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        let threadsResult = task_threads(mach_task_self_, &threadList, &threadCount)
        
        if threadsResult == KERN_SUCCESS, let threadList = threadList {
            for index in 0..<threadCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                
                let infoResult = thread_info(
                    threadList[Int(index)],
                    thread_flavor_t(THREAD_BASIC_INFO),
                    UnsafeMutableRawPointer(&threadInfo).assumingMemoryBound(to: integer_t.self),
                    &threadInfoCount
                )
                
                if infoResult == KERN_SUCCESS {
                    let threadBasicInfo = threadInfo
                    if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                        totalUsageOfCPU = totalUsageOfCPU + Float(threadBasicInfo.cpu_usage) / Float(TH_USAGE_SCALE)
                    }
                }
            }
            
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: threadList)),
                vm_size_t(threadCount * UInt32(MemoryLayout<thread_t>.size))
            )
        }
        
        return totalUsageOfCPU * 100.0
    }
    
    deinit {
        stopMonitoring()
        logger.info("🏥 VideoHealthMonitor deinitialized")
    }
}

// MARK: - Helper Extensions
extension DateFormatter {
    static let healthLogFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Notification Names
extension Notification.Name {
    static let videoHealthCritical = Notification.Name("videoHealthCritical")
}