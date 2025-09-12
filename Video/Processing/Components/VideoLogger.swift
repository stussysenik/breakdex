import Foundation
import OSLog

public struct VideoLogger {
    private static let logger = Logger(subsystem: "com.breakingflashcards", category: "VideoProcessing")
    
    public static func generateCorrelationID() -> String {
        return UUID().uuidString
    }
    
    public static func log(_ message: String, category: String, correlationID: String? = nil) {
        let correlationPrefix = correlationID != nil ? "[\(correlationID!)] " : ""
        logger.info("🎬 VIDEO_\(category.uppercased()): \(correlationPrefix)\(message)")
    }
    
    public static func error(_ message: String, error: Error, category: String, correlationID: String? = nil) {
        let correlationPrefix = correlationID != nil ? "[\(correlationID!)] " : ""
        logger.error("🎬 VIDEO_\(category.uppercased()): \(correlationPrefix)\(message): \(error.localizedDescription)")
    }
    
    public static func warning(_ message: String, category: String, correlationID: String? = nil) {
        let correlationPrefix = correlationID != nil ? "[\(correlationID!)] " : ""
        logger.warning("🎬 VIDEO_\(category.uppercased()): \(correlationPrefix)\(message)")
    }
    
    public static func debug(_ message: String, category: String, correlationID: String? = nil) {
        let correlationPrefix = correlationID != nil ? "[\(correlationID!)] " : ""
        logger.debug("🎬 VIDEO_\(category.uppercased()): \(correlationPrefix)\(message)")
    }
    
    // Memory logging helper
    public static func logMemoryUsage(context: String, category: String, correlationID: String? = nil) {
        let memory = os_proc_available_memory()
        let memoryMB = Double(memory) / (1024 * 1024)
        let correlationPrefix = correlationID != nil ? "[\(correlationID!)] " : ""
        logger.info("🎬 VIDEO_\(category.uppercased()): \(correlationPrefix)MEMORY [\(context)]: \(String(format: "%.1f", memoryMB)) MB available")
    }
}