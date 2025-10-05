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
    
    // MARK: - Core Video Services
    private(set) lazy var unifiedPlayerManager: UnifiedPlayerManager = {
        let manager = UnifiedPlayerManager()
        logger.info("🏗️ APP_CONTAINER: UnifiedPlayerManager initialized as single source of truth", metadata: nil)
        return manager
    }()

    private(set) lazy var modernVideoLoadingService: ModernVideoLoadingService = {
        return ModernVideoLoadingService()
    }()

    // 🗑️ DEPRECATED: Legacy video loading service - will be removed in favor of unified system
    // private(set) lazy var videoLoadingService: breakdex.VideoLoadingService = {
    //     return LiveVideoLoadingService(memoryManager: memoryManager, logger: logger)
    // }()
    
    private(set) lazy var videoProcessor: VideoProcessor = {
        return VideoProcessorImpl(logger: logger)
    }()
    
    private(set) lazy var videoSaver: VideoSaver = {
        return VideoSaverImpl(logger: logger)
    }()
    
    private(set) lazy var videoProcessingPipeline: VideoProcessingPipeline = {
        return VideoProcessingPipelineImpl(
            loadingService: modernVideoLoadingService, // Using modern service instead of legacy
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
    
    // MARK: - Enhanced Cleanup
    func cleanup() {
        let cleanupStart = CFAbsoluteTimeGetCurrent()
        logger.info("🧹 ENHANCED AppContainer cleanup starting...", metadata: nil)

        // 🎯 CRITICAL: Cleanup unified player manager first to prevent retain cycles
        unifiedPlayerManager.cleanup()
        logger.info("🧹 UnifiedPlayerManager cleanup completed", metadata: nil)

        // Clear all caches
        memoryManager.clearCache(excluding: nil)
        logger.info("🧹 Memory cache cleared", metadata: nil)

        // Attempt memory recovery as part of cleanup
        memoryErrorHandler.attemptMemoryRecovery()
        logger.info("🧹 Memory recovery attempted", metadata: nil)

        // Reset state manager
        Task {
            try? await stateManager.transition(to: .idle)
        }

        let cleanupDuration = CFAbsoluteTimeGetCurrent() - cleanupStart
        logger.info("✅ ENHANCED AppContainer cleanup completed in \(String(format: "%.3f", cleanupDuration * 1000))ms", metadata: nil)
        logger.info("🔒 ALL RESOURCES CLEANED UP - MEMORY SAFE ✅", metadata: nil)
    }
    
    private init() {
        logger.info("🏗️ AppContainer initialized with enhanced video architecture", metadata: nil)
        logger.info("🎯 UnifiedPlayerManager is now the single source of truth for video players", metadata: nil)
        logger.info("🗑️ Legacy video services deprecated and will be removed", metadata: nil)
        setupMemoryMonitoring()
    }
    
    deinit {
        Task { @MainActor in
            cleanup()
        }
    }
}
