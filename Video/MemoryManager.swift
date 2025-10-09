import Foundation
import OSLog
import UIKit

// MemoryManager.swift

// MARK: - Memory State
public enum MemoryState {
    case normal
    case warning
    case critical

    var description: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
}

// MARK: - Memory Manager Protocol
public protocol MemoryManager {
    func monitorMemoryUsage() -> AsyncStream<MemoryState>
    func handleMemoryWarning()
    func clearCache(excluding lockedURL: URL?)
    func getAvailableMemory() -> Int64
    func getUsedMemory() -> Int64
}

// MARK: - Memory Manager Implementation
public final class MemoryManagerImpl: MemoryManager {
    private let logger = Logger(
        subsystem: "com.breakingflashcards",
        category: "MemoryManager"
    )
    private let memoryNormalThreshold: Int64 = 200 * 1024 * 1024  // 200MB
    private let memoryWarningThreshold: Int64 = 100 * 1024 * 1024  // 100MB
    private let memoryCriticalThreshold: Int64 = 50 * 1024 * 1024  // 50MB

    private var continuation: AsyncStream<MemoryState>.Continuation?
    private var lastMemoryState: MemoryState = .normal
    private var memoryPressureObserver: NSObjectProtocol?

    public init() {
        setupMemoryPressureObservation()
        //        logInitialMemoryState()
    }

    private func setupMemoryPressureObservation() {
        memoryPressureObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }

        // logger.info("🧠 Memory pressure observation set up")
    }

    // private func logInitialMemoryState() {
    //     let availableMemory = getAvailableMemory()
    //     let usedMemory = getUsedMemory()
    //     let totalMemory = ProcessInfo.processInfo.physicalMemory

    //     logger.info("🧠 Initial memory state:")
    //     logger.info("   - Available: \(availableMemory / (1024 * 1024))MB")
    //     logger.info("   - Used: \(usedMemory / (1024 * 1024))MB")
    //     logger.info("   - Total: \(totalMemory / (1024 * 1024))MB")
    //     logger.info("   - Percentage used: \(Double(usedMemory) / Double(totalMemory) * 100)%")
    // }

    public func monitorMemoryUsage() -> AsyncStream<MemoryState> {
        return AsyncStream { continuation in
            self.continuation = continuation

            Task {
                while !Task.isCancelled {
                    let availableMemory = self.getAvailableMemory()
                    let usedMemory = getUsedMemory()
                    let state: MemoryState

                    if availableMemory < memoryCriticalThreshold {
                        state = .critical
                    } else if availableMemory < memoryWarningThreshold {
                        state = .warning
                    } else {
                        state = .normal
                    }

                    // Log state changes
                    if state != lastMemoryState {
                        logMemoryStateChange(
                            from: lastMemoryState,
                            to: state,
                            available: availableMemory,
                            used: usedMemory
                        )
                        lastMemoryState = state
                    }

                    // Take proactive actions based on memory state
                    handleMemoryState(state)

                    continuation.yield(state)

                    // Check memory every 5 seconds
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                }
            }
        }
    }

    private func logMemoryStateChange(
        from: MemoryState,
        to: MemoryState,
        available: Int64,
        used: Int64
    ) {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let percentageUsed = Double(used) / Double(totalMemory) * 100

        logger.info(
            "🧠 Memory state changed: \(from.description) → \(to.description)"
        )
        logger.info("   - Available: \(available / (1024 * 1024))MB")
        logger.info("   - Used: \(used / (1024 * 1024))MB")
        logger.info(
            "   - Percentage used: \(String(format: "%.1f", percentageUsed))%"
        )

        switch to {
        case .critical:
            logger.warning("🚨 CRITICAL MEMORY STATE REACHED")
        case .warning:
            logger.warning("⚠️ WARNING MEMORY STATE REACHED")
        case .normal:
            logger.info("✅ Normal memory state restored")
        }
    }

    private func handleMemoryState(_ state: MemoryState) {
        switch state {
        case .critical:
            logger.warning("🧠 Taking critical memory actions")
            performCriticalMemoryActions()
        case .warning:
            logger.info("🧠 Taking warning memory actions")
            performWarningMemoryActions()
        case .normal:
            // No actions needed for normal state
            break
        }
    }

    private func performCriticalMemoryActions() {
        // Aggressive cache clearing
        clearCache()

        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()

        // Cancel all URL sessions
        URLSession.shared.invalidateAndCancel()

        // Request garbage collection
        DispatchQueue.global(qos: .utility).async {
            // Force garbage collection
            DispatchQueue.main.async {
                // This is a hint to the system that we're in a critical memory state
                // The system may take additional actions
            }
        }

        logger.info("🧠 Critical memory actions completed")
    }

    private func performWarningMemoryActions() {
        // Moderate cache clearing
        clearCache()

        logger.info("🧠 Warning memory actions completed")
    }

    public func handleMemoryWarning() {
        logger.warning(
            "🧠 Memory warning received from system - taking critical actions"
        )

        // Take critical memory actions
        performCriticalMemoryActions()

        // Notify about memory pressure
        continuation?.yield(.critical)

        logger.info("🧠 System memory warning handled")
    }

    public func clearCache(excluding lockedURL: URL? = nil) {
        logger.info("🧠 Clearing video cache")

        // Clear video cache
        let tempDir = FileManager.default.temporaryDirectory
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: tempDir,
                includingPropertiesForKeys: nil
            )
            var deletedCount = 0
            var skippedCount = 0

            for file in contents
            where file.pathExtension == "mov" || file.pathExtension == "mp4" {
                // MARK: - CRITICAL FIX: Check if this file is locked by the current Add Move operation
                if let lockedURL = lockedURL, file == lockedURL {
                    logger.info(
                        "🧠 Skipping deletion of locked asset: \(file.lastPathComponent)"
                    )
                    skippedCount += 1
                    continue
                }

                try FileManager.default.removeItem(at: file)
                logger.debug(
                    "🧠 Deleted cached video file: \(file.lastPathComponent)"
                )
                deletedCount += 1
            }

            logger.info(
                "🧠 Cache clearing completed - deleted: \(deletedCount), skipped: \(skippedCount)"
            )

            if skippedCount > 0 {
                logger.info(
                    "🧠 Protected \(skippedCount) locked file(s) from deletion"
                )
            }
        } catch {
            logger.error(
                "🧠 Failed to clear video cache: \(error.localizedDescription)"
            )
        }

        // Clear image cache
        ImageCache.shared.clearCache()

        logger.info("🧠 Cache clearing completed")
    }

    public func getAvailableMemory() -> Int64 {
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

        if result == KERN_SUCCESS {
            let usedMemory = Int64(info.resident_size)
            let totalMemory = ProcessInfo.processInfo.physicalMemory
            return Int64(totalMemory) - usedMemory
        }

        return 0
    }

    public func getUsedMemory() -> Int64 {
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

        if result == KERN_SUCCESS {
            return Int64(info.resident_size)
        }

        return 0
    }

    deinit {
        // Clean up memory pressure observer
        if let observer = memoryPressureObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        // Finish the continuation
        continuation?.finish()

        logger.info("🧠 MemoryManager deinitialized")
    }
}

// MARK: - Image Cache Helper
private class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 50  // Max 50 images
        cache.totalCostLimit = 50 * 1024 * 1024  // 50MB
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}
