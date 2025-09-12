import Foundation
import AVFoundation
import Combine
import OSLog

@MainActor
public class EnhancedVideoCoordinator: ObservableObject {
    public enum State: Equatable, Hashable {
        case loading(progress: Double, status: String)
        case ready(AVPlayer)
        case error(EnhancedVideoError)
        case recovering(error: EnhancedVideoError, recoveryMessage: String)
        
        // Implement Equatable
        public static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.loading(let lhsProgress, let lhsStatus), .loading(let rhsProgress, let rhsStatus)):
                return lhsProgress == rhsProgress && lhsStatus == rhsStatus
            case (.ready(let lhsPlayer), .ready(let rhsPlayer)):
                return lhsPlayer == rhsPlayer
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError.errorDescription == rhsError.errorDescription
            case (.recovering(let lhsError, let lhsMessage), .recovering(let rhsError, let rhsMessage)):
                return lhsError.errorDescription == rhsError.errorDescription && lhsMessage == rhsMessage
            default:
                return false
            }
        }
        
        // Implement Hashable
        public func hash(into hasher: inout Hasher) {
            switch self {
            case .loading(let progress, let status):
                hasher.combine("loading")
                hasher.combine(progress)
                hasher.combine(status)
            case .ready(let player):
                hasher.combine("ready")
                hasher.combine(ObjectIdentifier(player))
            case .error(let error):
                hasher.combine("error")
                hasher.combine(error.errorDescription)
            case .recovering(let error, let message):
                hasher.combine("recovering")
                hasher.combine(error.errorDescription)
                hasher.combine(message)
            }
        }
    }
    
    @Published public private(set) var state: State = .loading(progress: 0.0, status: "Initializing...")
    
    private let assetLoader: UpdatedVideoAssetLoader
    private let playerInitializer: PlayerInitializer
    private let readinessMonitor: ReadinessMonitor
    private let memoryManager: MemoryManager
    private let videoHealthMonitor: VideoHealthMonitor
    private let errorHandler: EnhancedVideoErrorHandler
    private let logger: AppLogger
    private var correlationID: String = ""
    private var currentTask: Task<Void, Never>?
    private var currentAsset: AVAsset?
    
    // Recovery retry configuration
    private let maxRecoveryAttempts: Int = 3
    private var recoveryAttempts: Int = 0
    
    public init(
        assetLoader: UpdatedVideoAssetLoader,
        playerInitializer: PlayerInitializer,
        readinessMonitor: ReadinessMonitor,
        memoryManager: MemoryManager,
        videoHealthMonitor: VideoHealthMonitor,
        errorHandler: EnhancedVideoErrorHandler,
        logger: AppLogger
    ) {
        self.assetLoader = assetLoader
        self.playerInitializer = playerInitializer
        self.readinessMonitor = readinessMonitor
        self.memoryManager = memoryManager
        self.videoHealthMonitor = videoHealthMonitor
        self.errorHandler = errorHandler
        self.logger = logger
        self.correlationID = UUID().uuidString
        
        logger.info("🎮 EnhancedVideoCoordinator initialized", metadata: ["correlationID": correlationID])
        
        // Set up notification observer for critical health events
        NotificationCenter.default.addObserver(
            forName: .videoHealthCritical,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleVideoHealthCritical(notification)
        }
    }
    
    public func loadVideo(from source: UpdatedVideoAssetLoader.Source, quarterTurns: Int = 0) async {
        logger.info("🔄 Starting video load", metadata: ["correlationID": correlationID])
        
        // Cancel any existing task
        currentTask?.cancel()
        
        // Reset recovery attempts
        recoveryAttempts = 0
        
        // Reset state
        state = .loading(progress: 0.0, status: "Initializing...")
        
        // Start new task
        currentTask = Task {
            await loadVideoWithRecovery(from: source, quarterTurns: quarterTurns)
        }
    }
    
    // MARK: - Private Loading Methods
    
    private func loadVideoWithRecovery(from source: UpdatedVideoAssetLoader.Source, quarterTurns: Int) async {
        do {
            // Step 1: Load asset
            updateLoadingState(progress: 0.2, status: "Loading asset...")
            logger.info("🔄 Loading asset", metadata: ["correlationID": correlationID])
            let asset = try await assetLoader.loadAsset(from: source)
            self.currentAsset = asset
            logger.info("✅ Asset loaded successfully", metadata: ["correlationID": correlationID])
            
            // Check for cancellation
            if Task.isCancelled { return }
            
            // Start health monitoring
            videoHealthMonitor.startMonitoring(asset: asset)
            
            // Step 2: Create player
            updateLoadingState(progress: 0.5, status: "Creating player...")
            logger.info("🔄 Creating player", metadata: ["correlationID": correlationID])
            let player = try await playerInitializer.createPlayer(from: asset, quarterTurns: quarterTurns)
            logger.info("✅ Player created successfully", metadata: ["correlationID": correlationID])
            
            // Check for cancellation
            if Task.isCancelled { return }
            
            // Step 3: Wait for player to be ready
            updateLoadingState(progress: 0.8, status: "Preparing player...")
            logger.info("🔄 Waiting for player to be ready", metadata: ["correlationID": correlationID])
            try await readinessMonitor.waitForPlayerReady(player)
            logger.info("✅ Player is ready", metadata: ["correlationID": correlationID])
            
            // Check for cancellation
            if Task.isCancelled { return }
            
            // Update state
            state = .ready(player)
            logger.info("✅ Video load completed successfully", metadata: ["correlationID": correlationID])
            
        } catch {
            // Handle error with recovery
            await handleErrorWithRecovery(error)
        }
    }
    
    private func handleErrorWithRecovery(_ error: Error) async {
        // Convert to EnhancedVideoError
        let videoError = errorHandler.handle(error, correlationID: correlationID)
        
        // Log the error
        logger.error("❌ Video load failed: \(videoError.errorDescription ?? "Unknown error")", metadata: [
            "correlationID": correlationID,
            "error": error.localizedDescription,
            "severity": videoError.severity.description
        ])
        
        // Check if we should attempt recovery
        if recoveryAttempts < maxRecoveryAttempts && videoError.severity != .low {
            recoveryAttempts += 1
            
            // Update state to recovering
            state = .recovering(error: videoError, recoveryMessage: "Attempting recovery...")
            logger.info("🔄 Attempting recovery (attempt \(recoveryAttempts)/\(maxRecoveryAttempts))", metadata: [
                "correlationID": correlationID,
                "error": videoError.errorDescription ?? "Unknown"
            ])
            
            // Attempt recovery
            let recoveryResult = errorHandler.attemptRecovery(for: videoError, correlationID: correlationID)
            
            if recoveryResult.isSuccess {
                logger.info("✅ Recovery successful: \(recoveryResult.message)", metadata: ["correlationID": correlationID])
                
                // If we have a current asset, try to reload it
                if let asset = currentAsset {
                    do {
                        // Create player with the existing asset
                        updateLoadingState(progress: 0.5, status: "Recreating player...")
                        let player = try await playerInitializer.createPlayer(from: asset, quarterTurns: 0)
                        
                        // Wait for player to be ready
                        updateLoadingState(progress: 0.8, status: "Preparing player...")
                        try await readinessMonitor.waitForPlayerReady(player)
                        
                        // Update state to ready
                        state = .ready(player)
                        logger.info("✅ Video reload after recovery completed successfully", metadata: ["correlationID": correlationID])
                        return
                    } catch {
                        // If recreation fails, continue to error state
                        await handleErrorWithRecovery(error)
                        return
                    }
                } else {
                    // If we don't have a current asset, we can't recover
                    state = .error(videoError)
                    return
                }
            } else {
                logger.warning("⚠️ Recovery failed: \(recoveryResult.message)", metadata: ["correlationID": correlationID])
                
                // If recovery failed, check if we should try again
                if recoveryAttempts < maxRecoveryAttempts {
                    // Wait a moment before retrying
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    
                    // Try to load again (this will increment recoveryAttempts)
                    // Note: In a real implementation, we would need to know the original source
                    // For now, we'll just go to error state
                    state = .error(videoError)
                } else {
                    // Max attempts reached
                    state = .error(videoError)
                }
            }
        } else {
            // No recovery attempted or max attempts reached
            state = .error(videoError)
        }
    }
    
    private func updateLoadingState(progress: Double, status: String) {
        state = .loading(progress: progress, status: status)
        logger.info("🔄 Loading state updated: \(status) (\(Int(progress * 100))%)", metadata: [
            "correlationID": correlationID,
            "progress": progress,
            "status": status
        ])
    }
    
    private func handleVideoHealthCritical(_ notification: Notification) {
        logger.warning("🏥 Received video health critical notification", metadata: [
            "correlationID": correlationID,
            "reason": notification.userInfo?["reason"] as? String ?? "Unknown"
        ])
        
        // If we're in a ready state, we should attempt to recover
        if case .ready = state {
            // Create a health critical error
            let reason = notification.userInfo?["reason"] as? String ?? "Unknown health issue"
            let healthError = EnhancedVideoError.videoHealthCritical(reason: reason)
            
            // Handle the error with recovery
            Task {
                await handleErrorWithRecovery(healthError)
            }
        }
    }
    
    // MARK: - Public Methods
    
    public func teardown() {
        logger.info("🔄 Tearing down enhanced video coordinator", metadata: ["correlationID": correlationID])
        
        // Cancel any existing task
        currentTask?.cancel()
        currentTask = nil
        
        // Stop health monitoring
        videoHealthMonitor.stopMonitoring()
        
        // Cancel readiness monitoring
        readinessMonitor.cancelMonitoring()
        
        // Reset state
        state = .loading(progress: 0.0, status: "Initializing...")
        
        // Clear memory
        memoryManager.clearCache()
        
        // Clear current asset
        currentAsset = nil
        
        // Reset recovery attempts
        recoveryAttempts = 0
        
        logger.info("✅ Teardown completed", metadata: ["correlationID": correlationID])
    }
    
    public func startPlayback() {
        logger.info("▶️ Starting playback", metadata: ["correlationID": correlationID])
        
        if case .ready(let player) = state {
            player.play()
            logger.info("✅ Playback started", metadata: ["correlationID": correlationID])
        } else {
            logger.warning("⚠️ Cannot start playback - player not ready", metadata: ["correlationID": correlationID])
        }
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.teardown()
        }
    }
}