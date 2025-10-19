import OSLog
import Foundation
import Photos

// MARK: - Simple Logger
/// Essentialist Logger wrapper around OSLog
/// Provides simple interface for consistent logging across the app
struct Logger {
    let subsystem: String
    let category: String
    private let osLog: OSLog

    /// Default logger for the app
    static let main = Logger(subsystem: "com.stussysenik.breakdex", category: "main")

    /// Initialize logger with subsystem and category
    init(subsystem: String = "com.stussysenik.breakdex", category: String) {
        self.subsystem = subsystem
        self.category = category
        self.osLog = OSLog(subsystem: subsystem, category: category)
    }

    /// Log info message
    func info(_ message: String) {
        os_log(.info, log: osLog, "%{public}@", message)
    }

    /// Log debug message
    func debug(_ message: String) {
        os_log(.debug, log: osLog, "%{public}@", message)
    }

    /// Log error message
    func error(_ message: String) {
        os_log(.error, log: osLog, "%{public}@", message)
    }

    /// Log fault message (critical error)
    func fault(_ message: String) {
        os_log(.fault, log: osLog, "%{public}@", message)
    }

    /// Log warning message
    func warning(_ message: String) {
        os_log(.default, log: osLog, "%{public}@", message)
    }

    /// Log info with emoji (enhanced traceability)
    func info(_ message: String, emoji: String) {
        let emojiMessage = "\(emoji) \(message)"
        os_log(.info, log: osLog, "%{public}@", emojiMessage)
    }

    /// Log debug with emoji
    func debug(_ message: String, emoji: String) {
        let emojiMessage = "\(emoji) \(message)"
        os_log(.debug, log: osLog, "%{public}@", emojiMessage)
    }

    /// Log error with emoji
    func error(_ message: String, emoji: String) {
        let emojiMessage = "\(emoji) \(message)"
        os_log(.error, log: osLog, "%{public}@", emojiMessage)
    }

    /// Log warning with emoji
    func warning(_ message: String, emoji: String) {
        let emojiMessage = "\(emoji) \(message)"
        os_log(.default, log: osLog, "%{public}@", emojiMessage)
    }
}

// MARK: - Predefined Loggers
/// Convenient predefined loggers for different parts of the app
extension Logger {
    /// AddMove feature logger
    static let addMove = Logger(category: "AddMove")

    /// Arsenal feature logger
    static let arsenal = Logger(category: "Arsenal")

    /// Review feature logger
    static let review = Logger(category: "Review")

    /// Video processing logger
    static let video = Logger(category: "Video")

    /// CoreData logger
    static let coreData = Logger(category: "CoreData")

    /// Network logger
    static let network = Logger(category: "Network")

    /// Performance logger
    static let performance = Logger(category: "Performance")
}

// MARK: - Logging Extensions
/// Convenient extensions for common logging scenarios
extension Logger {
    /// Log function entry (useful for debugging)
    func logFunctionEntry(_ functionName: String = #function) {
        debug("→ Entering \(functionName)", emoji: "🟢")
    }

    /// Log function exit
    func logFunctionExit(_ functionName: String = #function) {
        debug("← Exiting \(functionName)", emoji: "✅")
    }

    /// Log error with function context
    func logError(_ error: Error, functionName: String = #function) {
        self.error("❌ Error in \(functionName): \(error.localizedDescription)", emoji: "❌")
    }

    /// Log state transition
    func logStateTransition(from: Any, to: Any, context: String = "") {
        let contextInfo = context.isEmpty ? "" : " (\(context))"
        info("🔄 State transition: \(from) → \(to)\(contextInfo)", emoji: "🔄")
    }

    /// Log performance timing
    func logTiming(_ operation: String, duration: TimeInterval) {
        let durationString = String(format: "%.2f", duration)
        info("⏱️ \(operation): \(durationString)s", emoji: "⏱️")
    }
}

// MARK: - Centralized Memory Logger (Compatibility)
/// Simple compatibility shim to replace missing CentralizedMemoryLogger
/// Following essentialism - just use OSLog directly
typealias CentralizedMemoryLogger = Logger

extension CentralizedMemoryLogger {
    static let shared = Logger.main

    /// Generate correlation ID for tracking operations
    func generateCorrelationId(for component: String) -> String {
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let uuid = UUID().uuidString.prefix(8).uppercased()
        return "\(component.prefix(3).uppercased())-\(timestamp)-\(uuid)"
    }

    /// Log memory state (compatibility method)
    func logMemoryState(context: String, correlationId: String, component: String) {
        info("📊 Memory State [\(correlationId)]: \(context) - Component: \(component)")
    }

    /// Clear correlation ID (compatibility method)
    func clearCorrelationId(for component: String) {
        debug("🧹 Cleared correlation ID for component: \(component)")
    }
}

// MARK: - Diagnostic Logging Helper (Compatibility)
/// Simple compatibility shim for missing DiagnosticLoggingHelper
struct DiagnosticLoggingHelper {
    static func log(_ message: String, level: LogLevel = .info) {
        switch level {
        case .info:
            Logger.main.info(message)
        case .debug:
            Logger.main.debug(message)
        case .error:
            Logger.main.error(message)
        case .fault:
            Logger.main.fault(message)
        }
    }

    enum LogLevel {
        case info
        case debug
        case error
        case fault
    }

    init(category: String) {
        // Simple initialization that matches existing usage
    }

    func logInfo(_ message: String, metadata: [String: String] = [:]) {
        Logger.main.info(message)
    }

    func logWarning(_ message: String, metadata: [String: String] = [:]) {
        Logger.main.warning(message)
    }

    func logError(_ message: String, metadata: [String: String] = [:]) {
        Logger.main.error(message)
    }

    func startTiming(_ operation: String) {
        // Simple timing stub
    }

    func stopTiming(_ operation: String) {
        // Simple timing stub
    }

    func logDebug(_ message: String) {
        Logger.main.debug(message)
    }

    func logDebug(_ message: String, metadata: [String: String] = [:]) {
        let metadataString = metadata.isEmpty ? "" : " | \(metadata)"
        Logger.main.debug("\(message)\(metadataString)")
    }
}

// MARK: - AlbumManagerError
/// Public error enum for album management operations
/// Extracted to top-level for proper accessibility across modules
public enum AlbumManagerError: Error {
    case permissionDenied
    case albumCreationFailed(Error)
    case albumNotFound
    case atomicOperationFailed(Error)
    case photoLibraryUnavailable
    case transientFailure(Error)
    case duplicateCreationAttempt
    case invalidAlbumState
}

// MARK: - AlbumManager (Compatibility Stub)
/// Simple AlbumManager stub for PhotosPersistenceService compatibility
/// Following essentialism - minimal implementation needed for compilation
public class AlbumManager {
    public static let shared = AlbumManager()

    private init() {}

    public struct OperationMetrics {
        let operationType: String
        let duration: TimeInterval
        let success: Bool
        let cacheHit: Bool
        let retryCount: Int
    }

    public func setup() async throws {
        // Essentialist stub - no actual setup needed for compilation
    }

    public func getBreakDexAlbum() async throws -> PHAssetCollection {
        // Essentialist stub - create a simple album or throw error
        throw AlbumManagerError.albumNotFound
    }

    public func getOperationMetrics() -> [OperationMetrics] {
        // Essentialist stub - return empty metrics
        return []
    }
}

// MARK: - AddMove Error
/// Simple error enum for AddMove functionality
public enum AddMoveError: Error, LocalizedError {
    case duplicateMoveName
    case invalidMoveData
    case videoProcessingFailed

    public var errorDescription: String? {
        switch self {
        case .duplicateMoveName:
            return "A move with this name already exists"
        case .invalidMoveData:
            return "Invalid move data provided"
        case .videoProcessingFailed:
            return "Video processing failed"
        }
    }
}