import AVFoundation
import Combine
import Foundation
import OSLog
import SwiftUI

// DiagnosticLoggingHelper.swift

// MARK: - Diagnostic Logging Helper
/// Comprehensive logging utility for enhanced diagnostics, performance monitoring, and debugging
/// Provides structured logging with timing, resource monitoring, and contextual metadata
public class DiagnosticLoggingHelper {

    // MARK: - Properties
    private let logger: Logger
    private let category: String

    // MARK: - Performance Tracking
    private var activeTimers: [String: CFAbsoluteTime] = [:]
    private var performanceMetrics: [String: [TimeInterval]] = [:]

    // MARK: - Resource Monitoring
    private var memoryBaseline: Double = 0
    private var cpuBaseline: Double = 0

    // MARK: - Configuration
    private let enablePerformanceTracking: Bool
    private let enableResourceMonitoring: Bool
    private let enableDetailedContext: Bool

    // MARK: - Log Levels
    public enum LogLevel: Int, CaseIterable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case critical = 4

        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🚨"
            }
        }

        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
    }

    // MARK: - Initialization
    public init(
        category: String,
        subsystem: String = "com.breakingflashcards",
        enablePerformanceTracking: Bool = true,
        enableResourceMonitoring: Bool = true,
        enableDetailedContext: Bool = true
    ) {
        self.category = category
        self.logger = Logger(subsystem: subsystem, category: category)
        self.enablePerformanceTracking = enablePerformanceTracking
        self.enableResourceMonitoring = enableResourceMonitoring
        self.enableDetailedContext = enableDetailedContext

        // Establish resource baselines
        if enableResourceMonitoring {
            self.memoryBaseline = getCurrentMemoryUsage()
            self.cpuBaseline = getCurrentCPUUsage()

            logInfo(
                "🔧 Diagnostic logging initialized",
                metadata: [
                    "performance_tracking": "\(enablePerformanceTracking)",
                    "resource_monitoring": "\(enableResourceMonitoring)",
                    "detailed_context": "\(enableDetailedContext)",
                    "memory_baseline_mb":
                        "\(String(format: "%.1f", memoryBaseline))",
                    "cpu_baseline_percent":
                        "\(String(format: "%.1f", cpuBaseline))",
                ]
            )
        }
    }

    // MARK: - Core Logging Methods

    /// Logs a debug message with optional metadata
    public func logDebug(_ message: String, metadata: [String: String] = [:]) {
        log(.debug, message, metadata: metadata)
    }

    /// Logs an info message with optional metadata
    public func logInfo(_ message: String, metadata: [String: String] = [:]) {
        log(.info, message, metadata: metadata)
    }

    /// Logs a warning message with optional metadata
    public func logWarning(_ message: String, metadata: [String: String] = [:])
    {
        log(.warning, message, metadata: metadata)
    }

    /// Logs an error message with optional metadata
    public func logError(
        _ message: String,
        error: Error? = nil,
        metadata: [String: String] = [:]
    ) {
        var enhancedMetadata = metadata
        if let error = error {
            enhancedMetadata["error_type"] = String(describing: type(of: error))
            enhancedMetadata["error_message"] = error.localizedDescription
            enhancedMetadata["error_domain"] = (error as NSError).domain
            enhancedMetadata["error_code"] = "\((error as NSError).code)"
        }
        log(.error, message, metadata: enhancedMetadata)
    }

    /// Logs a critical message with optional metadata and stack trace
    public func logCritical(
        _ message: String,
        error: Error? = nil,
        metadata: [String: String] = [:]
    ) {
        var enhancedMetadata = metadata
        if let error = error {
            enhancedMetadata["error_type"] = String(describing: type(of: error))
            enhancedMetadata["error_message"] = error.localizedDescription
        }

        // Add stack trace for critical errors
        let stackTrace = Thread.callStackSymbols.joined(separator: " | ")
        enhancedMetadata["stack_trace"] = stackTrace

        log(.critical, message, metadata: enhancedMetadata)
    }

    // MARK: - Private Core Logging
    private func log(
        _ level: LogLevel,
        _ message: String,
        metadata: [String: String] = [:]
    ) {
        var finalMessage = "\(level.emoji) [\(category)]: \(message)"

        // Add resource information if enabled
        if enableResourceMonitoring
            && (level == .warning || level == .error || level == .critical)
        {
            let memoryInfo = getMemoryInfo()
            let cpuUsage = getCurrentCPUUsage()
            finalMessage +=
                " [Mem: \(String(format: "%.1f", memoryInfo.used))MB | CPU: \(String(format: "%.1f", cpuUsage))%]"
        }

        // Add metadata if enabled
        if enableDetailedContext && !metadata.isEmpty {
            let metadataString = metadata.map { key, value in
                "\(key)=\"\(value)\""
            }.joined(separator: ", ")
            finalMessage += " [\(metadataString)]"
        }

        logger.log(level: level.osLogType, "\(finalMessage)")
    }

    // MARK: - Performance Timing

    /// Starts timing an operation
    public func startTiming(_ operation: String) {
        guard enablePerformanceTracking else { return }
        activeTimers[operation] = CFAbsoluteTimeGetCurrent()
        logDebug("⏱️ Started timing: \(operation)")
    }

    /// Stops timing an operation and logs the duration
    public func stopTiming(_ operation: String) {
        guard enablePerformanceTracking else { return }
        guard let startTime = activeTimers.removeValue(forKey: operation) else {
            logWarning(
                "⏱️ Attempted to stop timing for unknown operation: \(operation)"
            )
            return
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        logDebug(
            "⏱️ Completed timing: \(operation) - duration: \(String(format: "%.3f", duration))s"
        )

        // Store performance metrics
        performanceMetrics[operation, default: []].append(duration)

        // Log if operation took longer than expected
        let threshold: TimeInterval = 1.0  // 1 second threshold
        if duration > threshold {
            logWarning(
                "⏱️ Performance: \(operation) took longer than expected (\(String(format: "%.3f", duration))s > \(threshold)s)"
            )
        }
    }

    /// Times an operation automatically using a closure
    public func timeOperation<T>(_ operation: String, _ block: () throws -> T)
        rethrows -> T
    {
        startTiming(operation)
        defer { stopTiming(operation) }
        return try block()
    }

    /// Times an async operation automatically using a closure
    public func timeOperation<T>(
        _ operation: String,
        _ block: () async throws -> T
    ) async rethrows -> T {
        startTiming(operation)
        defer { stopTiming(operation) }
        return try await block()
    }

    // MARK: - Resource Monitoring

    /// Gets current memory usage information
    public func getMemoryInfo() -> (
        used: Double, free: Double, total: Double, percentage: Double
    ) {
        guard enableResourceMonitoring else { return (0, 0, 0, 0) }

        var info = mach_task_basic_info()
        var count =
            mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            logError(
                "Failed to get memory info",
                metadata: ["kern_result": "\(result)"]
            )
            return (0, 0, 0, 0)
        }

        let used = Double(info.resident_size) / (1024 * 1024)  // Convert to MB
        let total =
            Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024)  // Convert to MB
        let free = total - used
        let percentage = (used / total) * 100

        return (used, free, total, percentage)
    }

    /// Gets current CPU usage
    public func getCurrentCPUUsage() -> Double {
        guard enableResourceMonitoring else { return 0 }

        var totalUsageOfCPU: Double = 0
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0

        let threadsResult = task_threads(
            mach_task_self_,
            &threadList,
            &threadCount
        )

        guard threadsResult == KERN_SUCCESS, let threadList = threadList else {
            logError(
                "Failed to get thread list",
                metadata: ["kern_result": "\(threadsResult)"]
            )
            return 0
        }

        for index in 0..<threadCount {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)

            let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_info(
                        threadList[Int(index)],
                        thread_flavor_t(THREAD_BASIC_INFO),
                        $0,
                        &threadInfoCount
                    )
                }
            }

            if infoResult == KERN_SUCCESS {
                let threadBasicInfo = threadInfo
                if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                    totalUsageOfCPU +=
                        Double(threadBasicInfo.cpu_usage)
                        / Double(TH_USAGE_SCALE)
                }
            }
        }

        vm_deallocate(
            mach_task_self_,
            vm_address_t(UInt(bitPattern: threadList)),
            vm_size_t(threadCount * UInt32(MemoryLayout<thread_t>.size))
        )

        return totalUsageOfCPU * 100  // Convert to percentage
    }

    /// Gets current memory usage (simplified version)
    private func getCurrentMemoryUsage() -> Double {
        return getMemoryInfo().used
    }

    // MARK: - Performance Metrics

    /// Logs performance statistics for all tracked operations
    public func logPerformanceSummary() {
        guard enablePerformanceTracking && !performanceMetrics.isEmpty else {
            return
        }

        logInfo(" Performance Metrics Summary")
        for (operation, timings) in performanceMetrics {
            let count = timings.count
            let average = timings.reduce(0, +) / Double(count)
            let min = timings.min() ?? 0
            let max = timings.max() ?? 0

            logInfo(
                "📈 \(operation): avg=\(String(format: "%.3f", average))s, min=\(String(format: "%.3f", min))s, max=\(String(format: "%.3f", max))s, count=\(count)"
            )
        }
    }

    /// Gets the number of active timers (for diagnostic purposes)
    public func getActiveTimersCount() -> Int {
        return activeTimers.count
    }

    /// Gets the names of active timers (for diagnostic purposes)
    public func getActiveTimerNames() -> [String] {
        return Array(activeTimers.keys)
    }

    /// Safely stops all active timers and returns their names
    public func stopAllActiveTimers() -> [String] {
        let timerNames = Array(activeTimers.keys)
        for timerName in timerNames {
            stopTiming(timerName)
        }
        return timerNames
    }

    // MARK: - User Interaction Logging

    /// Logs user interaction with timing and context
    public func logUserInteraction(
        _ interaction: String,
        metadata: [String: String] = [:]
    ) {
        var enhancedMetadata = metadata
        enhancedMetadata["timestamp"] = "\(Date())"

        logInfo(
            "👆 User Interaction: \(interaction)",
            metadata: enhancedMetadata
        )
    }

    /// Logs user gesture information
    public func logGesture(
        _ gesture: String,
        state: String,
        location: CGPoint? = nil,
        metadata: [String: String] = [:]
    ) {
        var enhancedMetadata = metadata
        enhancedMetadata["gesture_state"] = state

        if let location = location {
            enhancedMetadata["location_x"] = "\(location.x)"
            enhancedMetadata["location_y"] = "\(location.y)"
        }

        logDebug("👐 Gesture: \(gesture) - \(state)", metadata: enhancedMetadata)
    }

    // MARK: - State Change Logging

    /// Logs state changes with before/after context
    public func logStateChange<T: Equatable>(
        _ operation: String,
        from: T,
        to: T,
        metadata: [String: String] = [:]
    ) {
        var enhancedMetadata = metadata
        enhancedMetadata["from_state"] = "\(from)"
        enhancedMetadata["to_state"] = "\(to)"
        enhancedMetadata["state_change"] = from != to ? "changed" : "unchanged"

        logInfo("🔄 State Change: \(operation)", metadata: enhancedMetadata)
    }

    // MARK: - Animation Logging

    /// Logs animation events with detailed timing and context
    public func logAnimation(
        _ animationType: String,
        metadata: [String: String] = [:]
    ) {
        var enhancedMetadata = metadata
        enhancedMetadata["animation_timestamp"] = "\(Date())"

        if enableResourceMonitoring {
            let memoryInfo = getMemoryInfo()
            let cpuUsage = getCurrentCPUUsage()
            enhancedMetadata["memory_usage_mb"] =
                "\(String(format: "%.1f", memoryInfo.used))"
            enhancedMetadata["cpu_usage_percent"] =
                "\(String(format: "%.1f", cpuUsage))"
        }

        logDebug("🎬 Animation: \(animationType)", metadata: enhancedMetadata)
    }

    /// Logs animation warnings and potential conflicts
    public func logAnimationWarning(
        _ warningType: String,
        metadata: [String: String] = [:]
    ) {
        var enhancedMetadata = metadata
        enhancedMetadata["warning_timestamp"] = "\(Date())"
        enhancedMetadata["animation_warning_type"] = warningType

        if enableResourceMonitoring {
            let memoryInfo = getMemoryInfo()
            let cpuUsage = getCurrentCPUUsage()
            enhancedMetadata["memory_usage_mb"] =
                "\(String(format: "%.1f", memoryInfo.used))"
            enhancedMetadata["cpu_usage_percent"] =
                "\(String(format: "%.1f", cpuUsage))"
        }

        logWarning(
            "⚠️ Animation Warning: \(warningType)",
            metadata: enhancedMetadata
        )
    }

    /// Logs animation performance metrics
    public func logAnimationPerformance(
        _ performanceType: String,
        metadata: [String: String] = [:]
    ) {
        var enhancedMetadata = metadata
        enhancedMetadata["performance_timestamp"] = "\(Date())"

        if enableResourceMonitoring {
            let memoryInfo = getMemoryInfo()
            let cpuUsage = getCurrentCPUUsage()
            enhancedMetadata["memory_usage_mb"] =
                "\(String(format: "%.1f", memoryInfo.used))"
            enhancedMetadata["cpu_usage_percent"] =
                "\(String(format: "%.1f", cpuUsage))"
        }

        logInfo(
            " Animation Performance: \(performanceType)",
            metadata: enhancedMetadata
        )
    }

    /// Logs SwiftUI animation lifecycle events
    public func logSwiftUIAnimationLifecycle(
        _ lifecycleEvent: String,
        viewName: String,
        metadata: [String: String] = [:]
    ) {
        var enhancedMetadata = metadata
        enhancedMetadata["lifecycle_event"] = lifecycleEvent
        enhancedMetadata["view_name"] = viewName
        enhancedMetadata["swiftui_version"] = "5.0"

        logDebug(
            "🔄 SwiftUI Animation Lifecycle: \(lifecycleEvent) on \(viewName)",
            metadata: enhancedMetadata
        )
    }

    // MARK: - Resource Warning Monitoring

    /// Checks for resource warnings and logs them
    public func checkResourceWarnings() {
        guard enableResourceMonitoring else { return }

        let memoryInfo = getMemoryInfo()
        let cpuUsage = getCurrentCPUUsage()

        // Memory warnings
        let memoryWarningThreshold = 80.0  // 80%
        let memoryCriticalThreshold = 90.0  // 90%

        if memoryInfo.percentage > memoryCriticalThreshold {
            logCritical(
                "🚨 Memory usage critical",
                metadata: [
                    "memory_percent":
                        "\(String(format: "%.1f", memoryInfo.percentage))%",
                    "memory_used_mb":
                        "\(String(format: "%.1f", memoryInfo.used))",
                    "threshold": "\(memoryCriticalThreshold)%",
                ]
            )
        } else if memoryInfo.percentage > memoryWarningThreshold {
            logWarning(
                "⚠️ Memory usage high",
                metadata: [
                    "memory_percent":
                        "\(String(format: "%.1f", memoryInfo.percentage))%",
                    "memory_used_mb":
                        "\(String(format: "%.1f", memoryInfo.used))",
                    "threshold": "\(memoryWarningThreshold)%",
                ]
            )
        }

        // CPU warnings
        let cpuWarningThreshold = 80.0  // 80%

        if cpuUsage > cpuWarningThreshold {
            logWarning(
                "⚠️ CPU usage high",
                metadata: [
                    "cpu_percent": "\(String(format: "%.1f", cpuUsage))%",
                    "threshold": "\(cpuWarningThreshold)%",
                ]
            )
        }
    }

    // MARK: - Deinitialization
    deinit {
        // Perform synchronous cleanup to avoid retain cycles
        let activeTimersCount = activeTimers.count
        if !activeTimers.isEmpty {
            // Use a simple logger for deinit messages to avoid any complex operations
            let categoryCopy = self.category
            let deinitLogger = Logger(
                subsystem: "BreakingFlashcards",
                category: "DiagnosticLoggingHelper"
            )
            deinitLogger.info(
                "🗑️ DiagnosticLoggingHelper deinitialized for category: \(categoryCopy) - cleaned up \(activeTimersCount) active timers"
            )
        }
    }
}

// MARK: - Convenience Extensions
extension DiagnosticLoggingHelper {

    /// Creates a standardized metadata dictionary for video operations
    public func videoMetadata(
        asset: AVAsset? = nil,
        duration: CMTime? = nil,
        rotation: Int? = nil,
        isReady: Bool? = nil
    ) -> [String: String] {
        var metadata: [String: String] = [:]

        if let asset = asset {
            metadata["asset_duration"] = "\(asset.duration.seconds)"
            metadata["asset_tracks"] = "\(asset.tracks.count)"
        }

        if let duration = duration {
            metadata["duration"] = "\(duration.seconds)"
        }

        if let rotation = rotation {
            metadata["rotation_degrees"] = "\(rotation * 90)"
        }

        if let isReady = isReady {
            metadata["is_ready"] = "\(isReady)"
        }

        return metadata
    }

    /// Creates a standardized metadata dictionary for user interactions
    public func interactionMetadata(
        buttonType: String? = nil,
        gestureType: String? = nil,
        duration: TimeInterval? = nil,
        success: Bool? = nil
    ) -> [String: String] {
        var metadata: [String: String] = [:]

        if let buttonType = buttonType {
            metadata["button_type"] = buttonType
        }

        if let gestureType = gestureType {
            metadata["gesture_type"] = gestureType
        }

        if let duration = duration {
            metadata["interaction_duration"] =
                "\(String(format: "%.3f", duration))"
        }

        if let success = success {
            metadata["success"] = "\(success)"
        }

        return metadata
    }
}
