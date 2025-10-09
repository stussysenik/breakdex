import SwiftUI
import OSLog
import Foundation

// MARK: - Memory Helper Utility
/// Utility for memory monitoring and diagnostics
public struct MemoryHelper {

    /// Gets current memory usage information
    public static func getCurrentMemoryUsage() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return "unknown"
        }

        let usedMB = Double(info.resident_size) / (1024 * 1024)
        return "\(String(format: "%.1f", usedMB))MB"
    }

    /// Gets detailed memory information
    public static func getDetailedMemoryInfo() -> (used: Double, available: Double, total: Double, percentage: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (0, 0, 0, 0)
        }

        let used = Double(info.resident_size) / (1024 * 1024) // Convert to MB
        let total = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024) // Convert to MB
        let available = total - used
        let percentage = (used / total) * 100

        return (used, available, total, percentage)
    }

    /// Gets memory pressure state
    public static func getMemoryPressureState() -> String {
        let info = getDetailedMemoryInfo()
        let percentage = info.percentage

        if percentage > 90 {
            return "critical"
        } else if percentage > 80 {
            return "high"
        } else if percentage > 70 {
            return "moderate"
        } else {
            return "normal"
        }
    }

    /// Logs current memory state
    public static func logMemoryState(context: String = "general") {
        let info = getDetailedMemoryInfo()
        let logger = Logger(subsystem: "com.breakingflashcards", category: "MemoryHelper")

        logger.info(" Memory State [\(context)]: Used=\(String(format: "%.1f", info.used))MB, Available=\(String(format: "%.1f", info.available))MB, Total=\(String(format: "%.1f", info.total))MB, Percentage=\(String(format: "%.1f", info.percentage))%")
    }

    /// Checks for memory warnings and returns true if memory pressure is high
    public static func isMemoryPressureHigh() -> Bool {
        let info = getDetailedMemoryInfo()
        return info.percentage > 80
    }

    /// Gets memory delta from baseline
    public static func getMemoryDelta(baseline: Double) -> Double {
        let current = getDetailedMemoryInfo().used
        return current - baseline
    }
}