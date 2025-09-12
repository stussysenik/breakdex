import Foundation
import OSLog
import UIKit

// MARK: - Memory Error Handler
public class MemoryErrorHandler {
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "MemoryErrorHandler")
    private let memoryManager: MemoryManager
    
    // Memory thresholds for different actions
    private let criticalMemoryThreshold: Int64 = 50 * 1024 * 1024 // 50MB
    private let warningMemoryThreshold: Int64 = 100 * 1024 * 1024 // 100MB
    private let normalMemoryThreshold: Int64 = 200 * 1024 * 1024 // 200MB
    
    // Recovery strategies
    private var recoveryStrategies: [MemoryRecoveryStrategy] = []
    
    public init(memoryManager: MemoryManager) {
        self.memoryManager = memoryManager
        setupRecoveryStrategies()
        setupMemoryWarningNotification()
    }
    
    // MARK: - Setup Methods
    
    private func setupRecoveryStrategies() {
        // Add recovery strategies in order of aggressiveness
        recoveryStrategies.append(CacheClearingStrategy())
        recoveryStrategies.append(URLCacheClearingStrategy())
        recoveryStrategies.append(SessionInvalidationStrategy())
        recoveryStrategies.append(AggressiveMemoryRecoveryStrategy())
    }
    
    private func setupMemoryWarningNotification() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemMemoryWarning()
        }
    }
    
    // MARK: - Public Methods
    
    /// Checks current memory state and takes appropriate actions
    public func checkMemoryState() -> MemoryState {
        let availableMemory = memoryManager.getAvailableMemory()
        
        if availableMemory < criticalMemoryThreshold {
            handleCriticalMemoryState()
            return .critical
        } else if availableMemory < warningMemoryThreshold {
            handleWarningMemoryState()
            return .warning
        } else {
            return .normal
        }
    }
    
    /// Handles system memory warning
    public func handleSystemMemoryWarning() {
        logger.warning("🚨 System memory warning received")
        
        // Log current memory state
        logCurrentMemoryState()
        
        // Attempt recovery using all strategies
        attemptMemoryRecovery()
        
        // Notify about critical state
        NotificationCenter.default.post(
            name: .memoryStateDidChange,
            object: MemoryState.critical
        )
    }
    
    /// Attempts to recover from memory issues
    /// - Returns: True if recovery was successful, false otherwise
    @discardableResult
    public func attemptMemoryRecovery() -> Bool {
        logger.info("🔄 Attempting memory recovery")
        
        let initialMemory = memoryManager.getAvailableMemory()
        logger.info("🧠 Initial available memory: \(initialMemory / (1024 * 1024))MB")
        
        var recoverySuccessful = false
        
        // Try each recovery strategy in order
        for strategy in recoveryStrategies {
            logger.info("🔄 Attempting recovery strategy: \(strategy.name)")
            
            if strategy.execute(memoryManager: memoryManager) {
                let recoveredMemory = memoryManager.getAvailableMemory()
                logger.info("✅ Recovery strategy '\(strategy.name)' successful")
                logger.info("🧠 Memory after recovery: \(recoveredMemory / (1024 * 1024))MB")
                
                // Check if we've recovered enough memory
                if recoveredMemory > normalMemoryThreshold {
                    recoverySuccessful = true
                    break
                }
            } else {
                logger.warning("⚠️ Recovery strategy '\(strategy.name)' failed")
            }
        }
        
        // Log final state
        let finalMemory = memoryManager.getAvailableMemory()
        logger.info("🧠 Final available memory: \(finalMemory / (1024 * 1024))MB")
        
        if recoverySuccessful {
            logger.info("✅ Memory recovery successful")
            NotificationCenter.default.post(
                name: .memoryRecoverySucceeded,
                object: nil
            )
        } else {
            logger.error("❌ Memory recovery failed")
            NotificationCenter.default.post(
                name: .memoryRecoveryFailed,
                object: nil
            )
        }
        
        return recoverySuccessful
    }
    
    /// Gets a user-friendly error message based on current memory state
    public func getUserFriendlyErrorMessage() -> String {
        let availableMemory = memoryManager.getAvailableMemory()
        let availableMB = availableMemory / (1024 * 1024)
        
        if availableMemory < criticalMemoryThreshold {
            return "Critical memory error. Only \(availableMB)MB available. Please close other apps and try again."
        } else if availableMemory < warningMemoryThreshold {
            return "Low memory warning. Only \(availableMB)MB available. Consider closing other apps for better performance."
        } else {
            return "Memory usage is optimal."
        }
    }
    
    /// Gets recovery suggestions for the user
    public func getRecoverySuggestions() -> [String] {
        let availableMemory = memoryManager.getAvailableMemory()
        var suggestions: [String] = []
        
        if availableMemory < criticalMemoryThreshold {
            suggestions.append("Close other apps running in the background")
            suggestions.append("Restart your device to free up memory");
            suggestions.append("Try using smaller video files");
            suggestions.append("Clear app cache from settings");
        } else if availableMemory < warningMemoryThreshold {
            suggestions.append("Close unused apps to improve performance");
            suggestions.append("Avoid using large video files");
        }
        
        return suggestions
    }
    
    // MARK: - Private Methods
    
    public func handleCriticalMemoryState() {
        logger.warning("🚨 Critical memory state detected")
        logCurrentMemoryState()
        
        // Attempt aggressive recovery
        attemptMemoryRecovery()
        
        // Notify UI to show critical memory warning
        NotificationCenter.default.post(
            name: .memoryStateDidChange,
            object: MemoryState.critical
        )
    }
    
    public func handleWarningMemoryState() {
        logger.warning("⚠️ Warning memory state detected")
        logCurrentMemoryState()
        
        // Attempt moderate recovery
        if let firstStrategy = recoveryStrategies.first {
            firstStrategy.execute(memoryManager: memoryManager)
        }
        
        // Notify UI to show memory warning
        NotificationCenter.default.post(
            name: .memoryStateDidChange,
            object: MemoryState.warning
        )
    }
    
    private func logCurrentMemoryState() {
        let availableMemory = memoryManager.getAvailableMemory()
        let usedMemory = memoryManager.getUsedMemory()
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let percentageUsed = Double(usedMemory) / Double(totalMemory) * 100
        
        logger.info("🧠 Current memory state:")
        logger.info("   - Available: \(availableMemory / (1024 * 1024))MB")
        logger.info("   - Used: \(usedMemory / (1024 * 1024))MB")
        logger.info("   - Total: \(totalMemory / (1024 * 1024))MB")
        logger.info("   - Percentage used: \(String(format: "%.1f", percentageUsed))%")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        logger.info("🧠 MemoryErrorHandler deinitialized")
    }
}

// MARK: - Memory Recovery Strategy Protocol
private protocol MemoryRecoveryStrategy {
    var name: String { get }
    func execute(memoryManager: MemoryManager) -> Bool
}

// MARK: - Concrete Recovery Strategies

/// Clears video and image cache
private class CacheClearingStrategy: MemoryRecoveryStrategy {
    let name = "Cache Clearing"
    
    func execute(memoryManager: MemoryManager) -> Bool {
        memoryManager.clearCache()
        return true
    }
}

/// Clears URL cache
private class URLCacheClearingStrategy: MemoryRecoveryStrategy {
    let name = "URL Cache Clearing"
    
    func execute(memoryManager: MemoryManager) -> Bool {
        URLCache.shared.removeAllCachedResponses()
        return true
    }
}

/// Invalidates URL sessions
private class SessionInvalidationStrategy: MemoryRecoveryStrategy {
    let name = "Session Invalidation"
    
    func execute(memoryManager: MemoryManager) -> Bool {
        URLSession.shared.invalidateAndCancel()
        return true
    }
}

/// Aggressive memory recovery including garbage collection hint
private class AggressiveMemoryRecoveryStrategy: MemoryRecoveryStrategy {
    let name = "Aggressive Memory Recovery"
    
    func execute(memoryManager: MemoryManager) -> Bool {
        // Clear all caches
        memoryManager.clearCache()
        URLCache.shared.removeAllCachedResponses()
        URLSession.shared.invalidateAndCancel()
        
        // Request garbage collection
        DispatchQueue.global(qos: .utility).async {
            // This is a hint to the system that we're in a critical memory state
            let _ = DispatchQueue.main.sync {
                // Force a synchronous task on main thread to encourage garbage collection
                return true
            }
        }
        
        return true
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let memoryStateDidChange = Notification.Name("memoryStateDidChange")
    static let memoryRecoverySucceeded = Notification.Name("memoryRecoverySucceeded")
    static let memoryRecoveryFailed = Notification.Name("memoryRecoveryFailed")
}