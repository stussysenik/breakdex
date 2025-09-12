import Foundation
import OSLog

// MARK: - App Logger Protocol
public protocol AppLogger {
    func info(_ message: String, metadata: [String: Any]?)
    func warning(_ message: String, metadata: [String: Any]?)
    func error(_ message: String, metadata: [String: Any]?)
    func critical(_ message: String, metadata: [String: Any]?)
    func debug(_ message: String, metadata: [String: Any]?)
}

// MARK: - Memory Logger Protocol
public protocol MemoryLogger {
    func logMemoryState(_ context: String, correlationId: String?, component: String)
    func logMemoryWarning(_ message: String, correlationId: String?, component: String, metadata: [String: Any]?)
    func logMemoryError(_ message: String, correlationId: String?, component: String, metadata: [String: Any]?)
    func logMemoryEvent(_ event: String, correlationId: String?, component: String, metadata: [String: Any]?)
}

// MARK: - Memory Log Entry
public struct MemoryLogEntry {
    let timestamp: Date
    let correlationId: String?
    let component: String
    let context: String
    let availableMemory: Int64
    let usedMemory: Int64
    let totalMemory: Int64
    let percentageUsed: Double
    let eventType: MemoryEventType
    let message: String
    let metadata: [String: Any]?
}

// MARK: - Memory Event Type
public enum MemoryEventType {
    case state
    case warning
    case error
    case event
    case cacheClearing
    case assetCleanup
    
    var description: String {
        switch self {
        case .state: return "State"
        case .warning: return "Warning"
        case .error: return "Error"
        case .event: return "Event"
        case .cacheClearing: return "Cache Clearing"
        case .assetCleanup: return "Asset Cleanup"
        }
    }
}

// MARK: - Logger Types
enum LoggerType {
    case console
    case file
    case analytics
}

// MARK: - Console Logger
final class ConsoleLogger: AppLogger {
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "ConsoleLogger")
    
    func info(_ message: String, metadata: [String: Any]?) {
        logger.info("ℹ️ \(message)")
        if let metadata = metadata {
            logger.debug("📋 Metadata: \(metadata)")
        }
    }
    
    func warning(_ message: String, metadata: [String: Any]?) {
        logger.warning("⚠️ \(message)")
        if let metadata = metadata {
            logger.debug("📋 Metadata: \(metadata)")
        }
    }
    
    func error(_ message: String, metadata: [String: Any]?) {
        logger.error("❌ \(message)")
        if let metadata = metadata {
            logger.debug("📋 Metadata: \(metadata)")
        }
    }
    
    func critical(_ message: String, metadata: [String: Any]?) {
        logger.critical("🚨 \(message)")
        if let metadata = metadata {
            logger.debug("📋 Metadata: \(metadata)")
        }
    }
    
    func debug(_ message: String, metadata: [String: Any]?) {
        logger.debug("🐛 \(message)")
        if let metadata = metadata {
            logger.debug("📋 Metadata: \(metadata)")
        }
    }
}

// MARK: - File Logger
final class FileLogger: AppLogger {
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "FileLogger")
    private let logFileURL: URL
    
    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        logFileURL = documents.appendingPathComponent("BreakingFlashcards.log")
        
        // Create log file if it doesn't exist
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }
    }
    
    func info(_ message: String, metadata: [String: Any]?) {
        writeToLog("ℹ️ [INFO] \(message)", metadata: metadata)
    }
    
    func warning(_ message: String, metadata: [String: Any]?) {
        writeToLog("⚠️ [WARNING] \(message)", metadata: metadata)
    }
    
    func error(_ message: String, metadata: [String: Any]?) {
        writeToLog("❌ [ERROR] \(message)", metadata: metadata)
    }
    
    func critical(_ message: String, metadata: [String: Any]?) {
        writeToLog("🚨 [CRITICAL] \(message)", metadata: metadata)
    }
    
    func debug(_ message: String, metadata: [String: Any]?) {
        writeToLog("🐛 [DEBUG] \(message)", metadata: metadata)
    }
    
    private func writeToLog(_ message: String, metadata: [String: Any]?) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        var logMessage = "[\(timestamp)] \(message)\n"
        
        if let metadata = metadata {
            logMessage += "Metadata: \(metadata)\n"
        }
        
        do {
            let data = logMessage.data(using: .utf8)!
            let fileHandle = try FileHandle(forWritingTo: logFileURL)
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        } catch {
            logger.error("Failed to write to log file: \(error.localizedDescription)")
        }
    }
}

// MARK: - Analytics Logger
final class AnalyticsLogger: AppLogger {
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "AnalyticsLogger")
    
    func info(_ message: String, metadata: [String: Any]?) {
        // In a real implementation, this would send events to analytics service
        logger.info("📊 Analytics Event: \(message)")
    }
    
    func warning(_ message: String, metadata: [String: Any]?) {
        logger.warning("📊 Analytics Warning: \(message)")
    }
    
    func error(_ message: String, metadata: [String: Any]?) {
        logger.error("📊 Analytics Error: \(message)")
    }
    
    func critical(_ message: String, metadata: [String: Any]?) {
        logger.critical("📊 Analytics Critical: \(message)")
    }
    
    func debug(_ message: String, metadata: [String: Any]?) {
        logger.debug("📊 Analytics Debug: \(message)")
    }
}

// MARK: - Composite Logger
final class CompositeLogger: AppLogger {
    private let loggers: [AppLogger]
    
    init(loggers: [AppLogger]) {
        self.loggers = loggers
    }
    
    func info(_ message: String, metadata: [String: Any]?) {
        loggers.forEach { $0.info(message, metadata: metadata) }
    }
    
    func warning(_ message: String, metadata: [String: Any]?) {
        loggers.forEach { $0.warning(message, metadata: metadata) }
    }
    
    func error(_ message: String, metadata: [String: Any]?) {
        loggers.forEach { $0.error(message, metadata: metadata) }
    }
    
    func critical(_ message: String, metadata: [String: Any]?) {
        loggers.forEach { $0.critical(message, metadata: metadata) }
    }
    
    func debug(_ message: String, metadata: [String: Any]?) {
        loggers.forEach { $0.debug(message, metadata: metadata) }
    }
}

// MARK: - Memory Logger Implementation
final class MemoryLoggerImpl: MemoryLogger {
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "MemoryLogger")
    private let memoryManager: MemoryManager
    private let logEntries: [MemoryLogEntry] = []
    
    init(memoryManager: MemoryManager) {
        self.memoryManager = memoryManager
    }
    
    // Public accessors for memory information to avoid direct access to private memoryManager
    func getAvailableMemory() -> Int64 {
        return memoryManager.getAvailableMemory()
    }
    
    func getUsedMemory() -> Int64 {
        return memoryManager.getUsedMemory()
    }
    
    func logMemoryState(_ context: String, correlationId: String?, component: String) {
        let entry = createMemoryLogEntry(
            context: context,
            correlationId: correlationId,
            component: component,
            eventType: .state,
            message: "Memory state at \(context)"
        )
        
        logMemoryEntry(entry)
    }
    
    func logMemoryWarning(_ message: String, correlationId: String?, component: String, metadata: [String: Any]?) {
        let entry = createMemoryLogEntry(
            context: "Warning",
            correlationId: correlationId,
            component: component,
            eventType: .warning,
            message: message,
            metadata: metadata
        )
        
        logMemoryEntry(entry)
    }
    
    func logMemoryError(_ message: String, correlationId: String?, component: String, metadata: [String: Any]?) {
        let entry = createMemoryLogEntry(
            context: "Error",
            correlationId: correlationId,
            component: component,
            eventType: .error,
            message: message,
            metadata: metadata
        )
        
        logMemoryEntry(entry)
    }
    
    func logMemoryEvent(_ event: String, correlationId: String?, component: String, metadata: [String: Any]?) {
        let entry = createMemoryLogEntry(
            context: "Event",
            correlationId: correlationId,
            component: component,
            eventType: .event,
            message: event,
            metadata: metadata
        )
        
        logMemoryEntry(entry)
    }
    
    // MARK: - Private Methods
    
    private func createMemoryLogEntry(
        context: String,
        correlationId: String?,
        component: String,
        eventType: MemoryEventType,
        message: String,
        metadata: [String: Any]? = nil
    ) -> MemoryLogEntry {
        let availableMemory = memoryManager.getAvailableMemory()
        let usedMemory = memoryManager.getUsedMemory()
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let percentageUsed = Double(usedMemory) / Double(totalMemory) * 100
        
        return MemoryLogEntry(
            timestamp: Date(),
            correlationId: correlationId,
            component: component,
            context: context,
            availableMemory: availableMemory,
            usedMemory: usedMemory,
            totalMemory: Int64(totalMemory),
            percentageUsed: percentageUsed,
            eventType: eventType,
            message: message,
            metadata: metadata
        )
    }
    
    func logMemoryEntry(_ entry: MemoryLogEntry) {
        let formattedTime = DateFormatter.memoryLogFormatter.string(from: entry.timestamp)
        let correlationIdString = entry.correlationId != nil ? "[\(entry.correlationId!)]" : ""
        
        let memoryInfo = "Available: \(entry.availableMemory / (1024 * 1024))MB, Used: \(entry.usedMemory / (1024 * 1024))MB (\(String(format: "%.1f", entry.percentageUsed))%)"
        
        let logMessage = "[\(formattedTime)] \(correlationIdString) [\(entry.component)] \(entry.eventType.description): \(entry.message) | \(memoryInfo)"
        
        switch entry.eventType {
        case .state:
            logger.info("🧠 \(logMessage)")
        case .warning:
            logger.warning("⚠️ \(logMessage)")
        case .error:
            logger.error("❌ \(logMessage)")
        case .event:
            logger.info("📊 \(logMessage)")
        case .cacheClearing:
            logger.info("🧹 \(logMessage)")
        case .assetCleanup:
            logger.info("🗑️ \(logMessage)")
        }
        
        // Log metadata if present
        if let metadata = entry.metadata, !metadata.isEmpty {
            let metadataString = metadata.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            logger.debug("📋 Metadata: \(metadataString)")
        }
    }
}

// MARK: - Centralized Memory Logging System
public final class CentralizedMemoryLogger {
    public static let shared = CentralizedMemoryLogger()
    
    private let memoryLogger: MemoryLogger
    private var correlationIds: [String: String] = [:]
    
    private init() {
        // Initialize with a memory manager
        let memoryManager = MemoryManagerImpl()
        self.memoryLogger = MemoryLoggerImpl(memoryManager: memoryManager)
    }
    
    public func generateCorrelationId(for operation: String) -> String {
        let uuid = UUID().uuidString.prefix(8).lowercased()
        let timestamp = DateFormatter.timestampFormatter.string(from: Date())
        let correlationId = "\(operation)-\(timestamp)-\(uuid)"
        
        correlationIds[operation] = correlationId
        
        memoryLogger.logMemoryEvent(
            "Generated correlation ID for \(operation)",
            correlationId: correlationId,
            component: "CentralizedMemoryLogger",
            metadata: ["operation": operation]
        )
        
        return correlationId
    }
    
    public func getCorrelationId(for operation: String) -> String? {
        return correlationIds[operation]
    }
    
    public func clearCorrelationId(for operation: String) {
        if let correlationId = correlationIds[operation] {
            memoryLogger.logMemoryEvent(
                "Cleared correlation ID for \(operation)",
                correlationId: correlationId,
                component: "CentralizedMemoryLogger",
                metadata: ["operation": operation]
            )
            
            correlationIds.removeValue(forKey: operation)
        }
    }
    
    public func logMemoryState(context: String, correlationId: String? = nil, component: String) {
        memoryLogger.logMemoryState(context, correlationId: correlationId, component: component)
    }
    
    public func logMemoryWarning(message: String, correlationId: String? = nil, component: String, metadata: [String: Any]? = nil) {
        memoryLogger.logMemoryWarning(message, correlationId: correlationId, component: component, metadata: metadata)
    }
    
    public func logMemoryError(message: String, correlationId: String? = nil, component: String, metadata: [String: Any]? = nil) {
        memoryLogger.logMemoryError(message, correlationId: correlationId, component: component, metadata: metadata)
    }
    
    public func logMemoryEvent(event: String, correlationId: String? = nil, component: String, metadata: [String: Any]? = nil) {
        memoryLogger.logMemoryEvent(event, correlationId: correlationId, component: component, metadata: metadata)
    }
    
    public func logCacheClearing(correlationId: String? = nil, component: String, details: String) {
        let availableMemory: Int64
        let usedMemory: Int64
        
        if let loggerImpl = memoryLogger as? MemoryLoggerImpl {
            availableMemory = loggerImpl.getAvailableMemory()
            usedMemory = loggerImpl.getUsedMemory()
        } else {
            availableMemory = 0
            usedMemory = 0
        }
        
        let entry = MemoryLogEntry(
            timestamp: Date(),
            correlationId: correlationId,
            component: component,
            context: "Cache Clearing",
            availableMemory: availableMemory,
            usedMemory: usedMemory,
            totalMemory: Int64(ProcessInfo.processInfo.physicalMemory),
            percentageUsed: 0,
            eventType: .cacheClearing,
            message: details,
            metadata: nil
        )
        
        // Log the entry directly
        if let loggerImpl = memoryLogger as? MemoryLoggerImpl {
            loggerImpl.logMemoryEntry(entry)
        }
    }
    
    public func logAssetCleanup(correlationId: String? = nil, component: String, details: String) {
        let availableMemory: Int64
        let usedMemory: Int64
        
        if let loggerImpl = memoryLogger as? MemoryLoggerImpl {
            availableMemory = loggerImpl.getAvailableMemory()
            usedMemory = loggerImpl.getUsedMemory()
        } else {
            availableMemory = 0
            usedMemory = 0
        }
        
        let entry = MemoryLogEntry(
            timestamp: Date(),
            correlationId: correlationId,
            component: component,
            context: "Asset Cleanup",
            availableMemory: availableMemory,
            usedMemory: usedMemory,
            totalMemory: Int64(ProcessInfo.processInfo.physicalMemory),
            percentageUsed: 0,
            eventType: .assetCleanup,
            message: details,
            metadata: nil
        )
        
        // Log the entry directly
        if let loggerImpl = memoryLogger as? MemoryLoggerImpl {
            loggerImpl.logMemoryEntry(entry)
        }
    }
}

// MARK: - Date Formatter Extensions
private extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    static let memoryLogFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}