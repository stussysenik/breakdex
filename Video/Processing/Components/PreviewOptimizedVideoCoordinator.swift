import Foundation
import AVFoundation
import Combine

@MainActor
public class PreviewOptimizedVideoCoordinator: ObservableObject {
    public enum State: Equatable, Hashable {
        case loading
        case ready(AVPlayer)
        case error(VideoProcessingError)
        
        // Implement Equatable
        public static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading):
                return true
            case (.ready(let lhsPlayer), .ready(let rhsPlayer)):
                return lhsPlayer == rhsPlayer
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError.errorDescription == rhsError.errorDescription
            default:
                return false
            }
        }
        
        // Implement Hashable
        public func hash(into hasher: inout Hasher) {
            switch self {
            case .loading:
                hasher.combine("loading")
            case .ready(let player):
                hasher.combine("ready")
                hasher.combine(ObjectIdentifier(player))
            case .error(let error):
                hasher.combine("error")
                hasher.combine(error.errorDescription)
            }
        }
    }
    
    @Published public private(set) var state: State = .loading
    
    private let assetLoader: PreviewOptimizedVideoAssetLoader
    private let playerInitializer: PreviewOptimizedVideoPlayerInitializer
    private let readinessMonitor: PreviewOptimizedReadinessMonitor
    private let memoryManager: MemoryManager
    private let logger: AppLogger
    private var correlationID: String = ""
    private var currentTask: Task<Void, Never>?
    
    public init(
        assetLoader: PreviewOptimizedVideoAssetLoader,
        playerInitializer: PreviewOptimizedVideoPlayerInitializer,
        readinessMonitor: PreviewOptimizedReadinessMonitor,
        memoryManager: MemoryManager,
        logger: AppLogger
    ) {
        self.assetLoader = assetLoader
        self.playerInitializer = playerInitializer
        self.readinessMonitor = readinessMonitor
        self.memoryManager = memoryManager
        self.logger = logger
        self.correlationID = UUID().uuidString
        
        logger.info("🎮 PreviewOptimizedVideoCoordinator initialized", metadata: ["correlationID": correlationID])
    }
    
    public func loadVideo(from source: PreviewOptimizedVideoAssetLoader.Source, quarterTurns: Int = 0) async {
        logger.info("🔄 Starting preview video load", metadata: ["correlationID": correlationID])
        
        // Cancel any existing task
        currentTask?.cancel()
        
        // Reset state
        state = .loading
        
        // Start new task
        currentTask = Task {
            do {
                // Step 1: Load asset
                logger.info("🔄 Loading preview asset", metadata: ["correlationID": correlationID])
                let asset = try await assetLoader.loadAsset(from: source)
                logger.info("✅ Preview asset loaded successfully", metadata: ["correlationID": correlationID])
                
                // Check for cancellation
                if Task.isCancelled { return }
                
                // Step 2: Create player
                logger.info("🔄 Creating preview player", metadata: ["correlationID": correlationID])
                let player = try await playerInitializer.createPlayer(from: asset, quarterTurns: quarterTurns)
                logger.info("✅ Preview player created successfully", metadata: ["correlationID": correlationID])
                
                // Check for cancellation
                if Task.isCancelled { return }
                
                // Step 3: Wait for player to be ready
                logger.info("🔄 Waiting for preview player to be ready", metadata: ["correlationID": correlationID])
                try await readinessMonitor.waitForPlayerReady(player)
                logger.info("✅ Preview player is ready", metadata: ["correlationID": correlationID])
                
                // Check for cancellation
                if Task.isCancelled { return }
                
                // Update state
                state = .ready(player)
                logger.info("✅ Preview video load completed successfully", metadata: ["correlationID": correlationID])
                
            } catch {
                // Handle error
                let videoError: VideoProcessingError = .videoLoadingFailed(identifier: correlationID, underlyingError: error)
                state = .error(videoError)
                logger.error("❌ Preview video load failed: \(videoError.errorDescription ?? "Unknown error")", metadata: [
                    "correlationID": correlationID,
                    "error": error.localizedDescription
                ])
            }
        }
    }
    
    public func teardown() {
        logger.info("🔄 Tearing down preview video coordinator", metadata: ["correlationID": correlationID])
        
        // Cancel any existing task
        currentTask?.cancel()
        currentTask = nil
        
        // Cancel readiness monitoring
        readinessMonitor.cancelMonitoring()
        
        // Reset state
        state = .loading
        
        // Clear memory
        memoryManager.clearCache()
        
        logger.info("✅ Preview teardown completed", metadata: ["correlationID": correlationID])
    }
    
    public func startPlayback() {
        logger.info("▶️ Starting preview playback", metadata: ["correlationID": correlationID])
        
        if case .ready(let player) = state {
            player.play()
            logger.info("✅ Preview playback started", metadata: ["correlationID": correlationID])
        } else {
            logger.warning("⚠️ Cannot start preview playback - player not ready", metadata: ["correlationID": correlationID])
        }
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.teardown()
        }
    }
}