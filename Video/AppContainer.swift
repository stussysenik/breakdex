import Foundation
import CoreData

// MARK: - App Container
@MainActor
public final class AppContainer {
    public static let shared = AppContainer()
    
    // MARK: - Core Services
    private(set) lazy var memoryManager: MemoryManager = {
        return MemoryManagerImpl()
    }()
    
    private(set) lazy var memoryErrorHandler: MemoryErrorHandler = {
        return MemoryErrorHandler(memoryManager: memoryManager)
    }()
    
    private(set) lazy var stateManager: VideoStateManager = {
        return VideoStateManagerImpl(memoryManager: memoryManager)
    }()
    
    private(set) lazy var logger: AppLogger = {
        let consoleLogger = ConsoleLogger()
        let fileLogger = FileLogger()
        let analyticsLogger = AnalyticsLogger()
        return CompositeLogger(loggers: [consoleLogger, fileLogger, analyticsLogger])
    }()
    
    // MARK: - Video Processing Services
    private(set) lazy var modernVideoLoadingService: ModernVideoLoadingService = {
        return ModernVideoLoadingService()
    }()

    private(set) lazy var videoLoadingService: BreakingFlashcards.VideoLoadingService = {
        return LiveVideoLoadingService(memoryManager: memoryManager, logger: logger)
    }()
    
    private(set) lazy var videoProcessor: VideoProcessor = {
        return VideoProcessorImpl(logger: logger)
    }()
    
    private(set) lazy var videoSaver: VideoSaver = {
        return VideoSaverImpl(logger: logger)
    }()
    
    private(set) lazy var videoProcessingPipeline: VideoProcessingPipeline = {
        return VideoProcessingPipelineImpl(
            loadingService: videoLoadingService,
            videoProcessor: videoProcessor,
            videoSaver: videoSaver,
            memoryManager: memoryManager,
            stateManager: stateManager,
            logger: logger
        )
    }()
    
    private(set) lazy var videoHealthMonitor: VideoHealthMonitor = {
        return VideoHealthMonitorImpl(memoryManager: memoryManager)
    }()

    // MARK: - Persistence Services
    private(set) lazy var movePersistenceService: MovePersistenceService = {
        return MovePersistenceService(
            viewContext: PersistenceController.shared.container.viewContext,
            videoSaver: videoSaver
        )
    }()

    // MARK: - Add Move Services
    private(set) lazy var addMoveSaveCoordinator: AddMoveSaveCoordinator = {
        return AddMoveSaveCoordinator(
            movePersistenceService: movePersistenceService,
            videoProcessingPipeline: videoProcessingPipeline,
            logger: logger
        )
    }()
    
    // MARK: - Memory Management
    func setupMemoryMonitoring() {
        Task {
            for await memoryState in memoryManager.monitorMemoryUsage() {
                switch memoryState {
                case .critical:
                    logger.critical("🚨 CRITICAL MEMORY STATE DETECTED", metadata: nil)
                    // Take immediate action using memory error handler
                    memoryErrorHandler.handleCriticalMemoryState()
                    
                case .warning:
                    logger.warning("⚠️ WARNING MEMORY STATE DETECTED", metadata: nil)
                    // Take preventive action using memory error handler
                    memoryErrorHandler.handleWarningMemoryState()
                    
                case .normal:
                    // No action needed
                    break
                }
            }
        }
    }
    
    // MARK: - Cleanup
    func cleanup() {
        logger.info("🧹 Cleaning up AppContainer resources", metadata: nil)
        
        // Clear all caches
        memoryManager.clearCache(excluding: nil)
        
        // Attempt memory recovery as part of cleanup
        memoryErrorHandler.attemptMemoryRecovery()
        
        // Reset state manager
        Task {
            try? await stateManager.transition(to: .idle)
        }
        
        logger.info("✅ AppContainer cleanup completed", metadata: nil)
    }
    
    private init() {
        logger.info("🏗️ AppContainer initialized", metadata: nil)
        setupMemoryMonitoring()
    }
    
    deinit {
        Task { @MainActor in
            cleanup()
        }
    }
}