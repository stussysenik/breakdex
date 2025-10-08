import Foundation
import AVFoundation
import OSLog

// MARK: - Video Health State
public enum VideoHealthState: Equatable {
    case healthy
    case warning(reason: String)
    case critical(reason: String)
    
    var isHealthy: Bool {
        switch self {
        case .healthy:
            return true
        case .warning, .critical:
            return false
        }
    }
    
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
    func setLockedAssetURL(_ url: URL?)
    func clearLockedAssetURL()
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
public final class VideoHealthMonitorImpl: VideoHealthMonitor {
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "VideoHealthMonitor")
    private let memoryManager: MemoryManager
    private var monitoringTask: Task<Void, Never>?
    private var continuation: AsyncStream<VideoHealthReport>.Continuation?
    private var statusContinuation: AsyncStream<VideoHealthStatusReport>.Continuation?
    private var currentAsset: AVAsset?

    // MARK: - CRITICAL FIX: Asset locking mechanism to prevent race condition
    private var lockedAssetURL: URL? {
        didSet {
            guard oldValue != lockedAssetURL else { return }
            logger.info("🏥 Locked asset URL updated: \(self.lockedAssetURL?.lastPathComponent ?? "nil")")
        }
    }
    
    // MARK: - Lifecycle Optimization
    private var isMonitoringActive = false
    private var lastHealthCheck: Date = .distantPast
    private var pauseCount = 0
    private var resumeCount = 0
    private let monitoringSessionId = UUID()
    
    // Monitoring intervals
    private let healthCheckInterval: TimeInterval = 3.0 // Increased to 3 seconds to reduce overhead
    private let memoryWarningThreshold: Int64 = 150 * 1024 * 1024 // 150MB
    private let memoryCriticalThreshold: Int64 = 50 * 1024 * 1024 // 50MB
    private let cpuWarningThreshold: Float = 80.0 // 80% CPU usage
    private let cpuCriticalThreshold: Float = 95.0 // 95% CPU usage
    
    init(memoryManager: MemoryManager) {
        self.memoryManager = memoryManager
        logger.info("🏥 VideoHealthMonitor initialized")
    }
    
    public func startMonitoring(asset: AVAsset) {
        logger.info("🏥 Starting video health monitoring [Session: \(self.monitoringSessionId.uuidString.prefix(8))]")
        
        // 💡 OPTIMIZATION: Check if we're already monitoring this asset
        if isMonitoringActive && currentAsset == asset {
            logger.info("🏥 Already monitoring this asset - skipping restart")
            return
        }
        
        // Stop any existing monitoring
        stopMonitoring()
        
        currentAsset = asset
        isMonitoringActive = true
        lastHealthCheck = Date()
        
        // Start the monitoring task with optimized lifecycle
        monitoringTask = Task {
            await monitorVideoHealth()
        }
        
        logger.info("🏥 Video health monitoring started successfully [Session: \(self.monitoringSessionId.uuidString.prefix(8))]")
    }
    
    public func stopMonitoring() {
        logger.info("🏥 Stopping video health monitoring [Session: \(self.monitoringSessionId.uuidString.prefix(8))]")

        isMonitoringActive = false

        monitoringTask?.cancel()
        monitoringTask = nil
        continuation?.finish()
        continuation = nil
        statusContinuation?.finish()
        statusContinuation = nil
        currentAsset = nil

        // MARK: - CRITICAL FIX: Clear locked asset URL when stopping monitoring
        lockedAssetURL = nil

        // 💡 OPTIMIZATION: Reset lifecycle tracking
        lastHealthCheck = .distantPast

        logger.info("🏥 Video health monitoring stopped [Session: \(self.monitoringSessionId.uuidString.prefix(8))]")
    }

    // MARK: - Asset Locking Mechanism

    /// Sets the locked asset URL to prevent premature deletion during memory cleanup
    public func setLockedAssetURL(_ url: URL?) {
        lockedAssetURL = url
        logger.info("🏥 Locked asset URL set to: \(url?.lastPathComponent ?? "nil")")
    }

    /// Clears the locked asset URL to allow cleanup of temporary files
    public func clearLockedAssetURL() {
        let previousURL = lockedAssetURL
        lockedAssetURL = nil
        logger.info("🏥 Locked asset URL cleared: \(previousURL?.lastPathComponent ?? "nil")")
    }
    
    public func pauseMonitoring() {
        pauseCount += 1
        logger.info("🏥 Pausing video health monitoring [Pause #\(self.pauseCount), Session: \(self.monitoringSessionId.uuidString.prefix(8))]")
        logger.info("🏥 Current monitoring task exists: \(self.monitoringTask != nil)")
        logger.info("🏥 Asset preserved: \(self.currentAsset != nil)")

        // MARK: - CRITICAL FIX: Allow pausing even if not currently active
        // This prevents errors during rapid state transitions
        guard isMonitoringActive else {
            logger.warning("🏥 ⚠️ Attempted to pause monitoring when not active")
            return
        }

        isMonitoringActive = false

        self.monitoringTask?.cancel()
        self.monitoringTask = nil
        // MARK: - CRITICAL FIX: Keep continuations and asset for quick resume
        // This preserves state across pause/resume cycles
        
        logger.info("🏥 📊 Memory after monitoring pause: \(self.memoryManager.getAvailableMemory() / (1024*1024)) MB available")
        
        logger.info("🏥 ✅ Video health monitoring paused successfully [Pause #\(self.pauseCount)]")
    }
    
    public func resumeMonitoring() {
        resumeCount += 1
        logger.info("🏥 Resuming video health monitoring [Resume #\(self.resumeCount), Session: \(self.monitoringSessionId.uuidString.prefix(8))]")
        logger.info("🏥 Current asset available: \(self.currentAsset != nil)")
        logger.info("🏥 Current monitoring task exists: \(self.monitoringTask != nil)")

        guard !isMonitoringActive else {
            logger.warning("🏥 ⚠️ Attempted to resume monitoring when already active")
            return
        }

        // MARK: - CRITICAL FIX: Handle asset availability more gracefully
        // The asset may be temporarily unavailable during state transitions
        guard let asset = self.currentAsset else {
            logger.warning("🏥 ⚠️ Cannot resume monitoring - no asset available")
            logger.info("🏥 This indicates asset was lost during state transition")

            // MARK: - CRITICAL FIX: Set monitoring state to inactive but don't fail
            // This allows future resume attempts when asset becomes available
            isMonitoringActive = false
            return
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        isMonitoringActive = true
        lastHealthCheck = Date()
        
        // 💡 OPTIMIZATION: Check if enough time has passed since last check to avoid rapid cycling
        let timeSinceLastCheck = Date().timeIntervalSince(lastHealthCheck)
        if timeSinceLastCheck < healthCheckInterval {
            logger.info("🏥 ⏭️ Skipping immediate resume - last check was \(String(format: "%.1f", timeSinceLastCheck))s ago")
        }
        
        // Restart monitoring with existing asset
        self.monitoringTask = Task {
            await self.monitorVideoHealth()
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let resumeTime = (endTime - startTime) * 1000
        logger.info("🏥 ⚡ Monitoring resume took \(String(format: "%.2f", resumeTime))ms")
        logger.info("🏥 📊 Memory after monitoring resume: \(self.memoryManager.getAvailableMemory() / (1024*1024)) MB available")
        
        logger.info("🏥 ✅ Video health monitoring resumed successfully [Resume #\(self.resumeCount)]")
    }
    
    public func getCurrentHealth() -> VideoHealthState {
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
    
    public func getCurrentHealthStatus() -> VideoHealthStatus {
        let healthState = getCurrentHealth()
        return VideoHealthStatus.from(healthState)
    }
    
    public func getHealthReports() -> AsyncStream<VideoHealthReport> {
        return AsyncStream { continuation in
            self.continuation = continuation
        }
    }
    
    public func getHealthStatusReports() -> AsyncStream<VideoHealthStatusReport> {
        return AsyncStream { continuation in
            self.statusContinuation = continuation
        }
    }
    
    // MARK: - Private Methods
    
    private func monitorVideoHealth() async {
        await withTaskCancellationHandler {
            var consecutiveHealthyChecks = 0
            let maxConsecutiveHealthyBeforeReducedLogging = 5
            
            while !Task.isCancelled {
                guard isMonitoringActive else {
                    // If monitoring was paused while loop was running, exit gracefully
                    logger.info("🏥 Monitoring became inactive - stopping health checks")
                    break
                }
                
                let report = generateHealthReport()
                let statusReport = generateHealthStatusReport()
                
                // 💡 OPTIMIZATION: Reduce logging for consecutive healthy states
                let shouldLogVerbosely = !report.state.isHealthy || consecutiveHealthyChecks < maxConsecutiveHealthyBeforeReducedLogging
                
                if shouldLogVerbosely {
                    // Log the health report
                    logHealthReport(report)
                } else if consecutiveHealthyChecks == maxConsecutiveHealthyBeforeReducedLogging {
                    logger.info("🏥 📊 System consistently healthy - reducing log frequency")
                }
                
                // Send the report to the stream (always send for downstream consumers)
                continuation?.yield(report)
                statusContinuation?.yield(statusReport)
                
                // Take action based on health state
                handleHealthState(report.state)
                
                // Track consecutive healthy checks
                if report.state == .healthy {
                    consecutiveHealthyChecks += 1
                } else {
                    consecutiveHealthyChecks = 0
                }
                
                // Update last health check time
                lastHealthCheck = Date()
                
                // Wait for the next check with adaptive interval
                let adaptiveInterval = report.state == .healthy ? healthCheckInterval * 1.5 : healthCheckInterval
                try? await Task.sleep(nanoseconds: UInt64(adaptiveInterval * 1_000_000_000))
            }
        } onCancel: {
            logger.info("🏥 Video health monitoring cancelled [Session: \(self.monitoringSessionId.uuidString.prefix(8))]")
        }
    }
    
    private func generateHealthReport() -> VideoHealthReport {
        let memoryUsage = memoryManager.getUsedMemory()
        let cpuUsage = getCurrentCPUUsage()
        let healthState = getCurrentHealth()
        
        // Get additional info about the asset
        var additionalInfo: [String: String] = [:]
        Task {
            await getAssetInfo(for: currentAsset, into: &additionalInfo)
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
        Task {
            await getAssetInfo(for: currentAsset, into: &additionalInfo)
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
    
    // MARK: - Asset Information Helper
    private func getAssetInfo(for asset: AVAsset?, into additionalInfo: inout [String: String]) async {
        guard let asset = asset else { return }
        
        do {
            let duration = try await asset.load(.duration)
            additionalInfo["duration"] = String(format: "%.2f", duration.seconds)
            
            let tracks = try await asset.load(.tracks)
            additionalInfo["tracks"] = "\(tracks.count)"
            
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            if let videoTrack = videoTracks.first {
                let naturalSize = try await videoTrack.load(.naturalSize)
                additionalInfo["videoSize"] = "\(Int(naturalSize.width))x\(Int(naturalSize.height))"
                
                let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
                additionalInfo["frameRate"] = String(format: "%.1f", nominalFrameRate)
            }
        } catch {
            logger.warning("🏥 Failed to load asset info: \(error.localizedDescription)")
        }
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
            memoryManager.clearCache(excluding: lockedAssetURL)
            
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
                
                let infoResult = withUnsafeMutableBytes(of: &threadInfo) { pointer in
                    thread_info(
                        threadList[Int(index)],
                        thread_flavor_t(THREAD_BASIC_INFO),
                        pointer.baseAddress!.assumingMemoryBound(to: integer_t.self),
                        &threadInfoCount
                    )
                }
                
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