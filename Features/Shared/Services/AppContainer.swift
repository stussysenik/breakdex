import Foundation
import AVFoundation
import PhotosUI

// MARK: - AppContainer
/// Main dependency injection container for the breakdex app
/// Provides centralized access to shared services and utilities
@MainActor
class AppContainer {

    // MARK: - Singleton
    static let shared = AppContainer()

    private init() {}

    // MARK: - Video Services
    /// Modern video loading service with resilience and error handling
    lazy var modernVideoLoadingService = SimpleModernVideoLoadingService()

    /// Video processing pipeline for trimming and export operations
    lazy var videoProcessingPipeline = SimpleVideoProcessingPipeline()

    /// Move persistence service for Core Data operations
    lazy var movePersistenceService = MovePersistenceService(viewContext: PersistenceController.shared.container.viewContext, videoSaver: SimpleVideoSaver())

    /// Timecode calculation service for video time operations
    lazy var timecodeCalculationServiceInstance = TimecodeCalculationService()

    /// Unified player manager for video playback
    lazy var unifiedPlayerManagerInstance = UnifiedPlayerManager()

    // MARK: - Convenience Accessors
    /// Provides access to the timecode calculation service
    var timecodeCalculationService: TimecodeCalculationService {
        return timecodeCalculationServiceInstance
    }

    /// Provides access to the unified player manager
    var unifiedPlayerManager: UnifiedPlayerManager {
        return unifiedPlayerManagerInstance
    }
}

// MARK: - Service Protocols and Implementations

/// Protocol for video loading services
protocol AppContainerVideoLoadingService {
    func loadVideo(from item: any Sendable) async throws -> AVAsset
}

/// Simple implementation of video loading service
class SimpleModernVideoLoadingService: AppContainerVideoLoadingService {
    func loadVideo(from item: any Sendable) async throws -> AVAsset {
        // Implementation would load video from PhotosPickerItem
        // For now, return a placeholder to avoid compilation errors
        throw NSError(domain: "NotImplemented", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video loading not implemented"])
    }
}