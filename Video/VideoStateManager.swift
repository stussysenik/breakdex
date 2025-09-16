import Foundation
import OSLog

// MARK: - Video State Manager Protocol
protocol VideoStateManager {
    var currentState: VideoState { get }
    func transition(to state: VideoState) async throws
    func canTransition(to state: VideoState) -> Bool
}

// MARK: - Video State Manager Implementation
final class VideoStateManagerImpl: VideoStateManager {
    private(set) var currentState: VideoState = .idle
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "VideoStateManager")
    private let memoryManager: MemoryManager
    
    init(memoryManager: MemoryManager) {
        self.memoryManager = memoryManager
        logger.info("🎮 VideoStateManager initialized with state: \(self.currentState.rawValue)")
    }
    
    func transition(to newState: VideoState) async throws {
        logger.info("🎮 Attempting state transition from \(self.currentState.rawValue) to \(newState.rawValue)")
        
        // Check if transition is valid
        guard canTransition(to: newState) else {
            let error = VideoProcessingError.invalidStateTransition(from: currentState, to: newState)
            logger.error("🎮 Invalid state transition: \(error.localizedDescription)")
            throw error
        }
        
        // Check memory before transitioning to states that require more memory
        if [.loading, .processing].contains(newState) {
            let availableMemory = memoryManager.getAvailableMemory()
            let warningThreshold: Int64 = 100 * 1024 * 1024 // 100MB
            
            if availableMemory < warningThreshold {
                let error = VideoProcessingError.memoryLimitExceeded(
                    used: memoryManager.getUsedMemory() / (1024 * 1024),
                    available: availableMemory / (1024 * 1024)
                )
                logger.error("🎮 Memory limit exceeded: \(error.localizedDescription)")
                throw error
            }
        }
        
        // Perform the transition
        let oldState = currentState
        currentState = newState
        
        logger.info("🎮 State transition successful: \(oldState.rawValue) → \(self.currentState.rawValue)")
        
        // Perform state-specific actions
        switch newState {
        case .loading:
            await handleLoadingState()
        case .error:
            await handleErrorState()
        case .idle:
            await handleIdleState()
        default:
            break
        }
    }
    
    func canTransition(to state: VideoState) -> Bool {
        return currentState.canTransition(to: state)
    }
    
    // MARK: - State-Specific Handlers
    
    private func handleLoadingState() async {
        logger.info("🎮 Handling loading state - setting up memory monitoring")
        
        // Monitor memory usage during loading
        for await memoryState in memoryManager.monitorMemoryUsage() {
            switch memoryState {
            case .critical:
                logger.warning("🎮 Critical memory state during loading - clearing cache")
                memoryManager.clearCache()
                
                // If memory is still critical, transition to error state
                if memoryManager.getAvailableMemory() < (50 * 1024 * 1024) { // 50MB
                    do {
                        try await transition(to: .error)
                    } catch {
                        logger.error("🎮 Failed to transition to error state: \(error.localizedDescription)")
                    }
                    return
                }
            case .warning:
                logger.info("🎮 Memory warning during loading - clearing non-essential cache")
                memoryManager.clearCache()
            case .normal:
                break
            }
        }
    }
    
    private func handleErrorState() async {
        logger.info("🎮 Handling error state - performing cleanup")
        
        // Clear any cached resources
        memoryManager.clearCache()
        
        // Log error state for debugging
        logger.error("🎮 Video processing entered error state")
    }
    
    private func handleIdleState() async {
        logger.info("🎮 Handling idle state - performing cleanup")
        
        // Clear all caches when returning to idle
        memoryManager.clearCache()
    }
}