import Foundation
import AVFoundation
import Combine

@MainActor
public class PreviewOptimizedVideoCoordinator: ObservableObject {
    public enum State: Equatable, Hashable {
        case loading
        case ready(AVPlayer)
        case error(VideoError)
        
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
    private var memoryCheckTimer: Timer?
    
    init(
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
        
        // Start periodic memory checks for preview
        startMemoryChecks()
    }
    
    public func loadVideo(from source: PreviewOptimizedVideoAssetLoader.Source, quarterTurns: Int = 0) async {
        logger.info("🔄 Starting preview video load", metadata: ["correlationID": correlationID])
        
        // Cancel any existing task
        currentTask?.cancel()
        
        // Reset state
        state = .loading
        
        // Perform immediate memory cleanup before loading
        memoryManager.clearCache()
        
        // Start new task
        currentTask = Task {
            do {
                // Step 1: Load asset with preview optimizations
                logger.info("🔄 Loading preview asset", metadata: ["correlationID": correlationID])
                let asset = try await assetLoader.loadAsset(from: source)
                logger.info("✅ Preview asset loaded successfully", metadata: ["correlationID": correlationID])
                
                // Check for cancellation
                if Task.isCancelled { return }
                
                // Step 2: Create player with preview optimizations
                logger.info("🔄 Creating preview player", metadata: ["correlationID": correlationID])
                let player = try await playerInitializer.createPlayer(from: asset, quarterTurns: quarterTurns)
                logger.info("✅ Preview player created successfully", metadata: ["correlationID": correlationID])
                
                // Check for cancellation
                if Task.isCancelled { return }
                
                // Step 3: Wait for player to be ready with shorter timeout for preview
                logger.info("🔄 Waiting for preview player to be ready", metadata: ["correlationID": correlationID])
                try await readinessMonitor.waitForPlayerReady(player)
                logger.info("✅ Preview player is ready", metadata: ["correlationID": correlationID])
                
                // Check for cancellation
                if Task.isCancelled { return }
                
                // Apply preview-specific player optimizations
                optimizePlayerForPreview(player)
                
                // Update state
                state = .ready(player)
                logger.info("✅ Preview video load completed successfully", metadata: ["correlationID": correlationID])
                
            } catch {
                // Handle error with preview-specific error handling
                let videoError = VideoErrorHandler.handle(error, correlationID: correlationID)
                state = .error(videoError)
                logger.error("❌ Preview video load failed: \(videoError.errorDescription ?? "Unknown error")", metadata: [
                    "correlationID": correlationID,
                    "error": error.localizedDescription
                ])
                
                // Perform additional cleanup on error
                memoryManager.clearCache()
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
        
        // Stop memory checks
        memoryCheckTimer?.invalidate()
        memoryCheckTimer = nil
        
        // Reset state
        state = .loading
        
        // Aggressive memory cleanup for preview
        memoryManager.clearCache()
        
        logger.info("✅ Preview teardown completed", metadata: ["correlationID": correlationID])
    }
    
    public func startPlayback() {
        logger.info("▶️ Starting preview playback", metadata: ["correlationID": correlationID])
        
        if case .ready(let player) = state {
            // Apply preview-specific playback optimizations
            player.currentItem?.preferredPeakBitRate = 2_000_000 // 2 Mbps for preview
            player.currentItem?.preferredForwardBufferDuration = 1.0 // Smaller buffer for preview
            
            player.play()
            logger.info("✅ Preview playback started", metadata: ["correlationID": correlationID])
        } else {
            logger.warning("⚠️ Cannot start preview playback - player not ready", metadata: ["correlationID": correlationID])
        }
    }
    
    // MARK: - Private Methods
    
    private func startMemoryChecks() {
        // Set up periodic memory checks for preview
        memoryCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkMemoryAndOptimize()
            }
        }
    }
    
    private func checkMemoryAndOptimize() {
        let availableMemory = memoryManager.getAvailableMemory()
        let memoryThreshold: Int64 = 50 * 1024 * 1024 // 50MB threshold for preview
        
        if availableMemory < memoryThreshold {
            logger.warning("⚠️ Low memory during preview: \(availableMemory / (1024 * 1024))MB", metadata: ["correlationID": correlationID])
            
            // If player is ready, apply more aggressive optimizations
            if case .ready(let player) = state {
                player.currentItem?.preferredPeakBitRate = 1_000_000 // Reduce to 1 Mbps
                player.currentItem?.preferredForwardBufferDuration = 0.5 // Reduce buffer further
                
                // Pause playback to free up memory
                player.pause()
                
                logger.info("⚠️ Applied aggressive memory optimizations for preview", metadata: ["correlationID": correlationID])
            }
            
            // Clear cache
            memoryManager.clearCache()
        }
    }
    
    private func optimizePlayerForPreview(_ player: AVPlayer) {
        guard let playerItem = player.currentItem else { return }
        
        // Set preview-specific player optimizations
        playerItem.preferredPeakBitRate = 2_000_000 // 2 Mbps for preview
        playerItem.preferredForwardBufferDuration = 1.0 // Smaller buffer for preview
        
        // Set lower resolution if available
        if let videoTracks = player.currentItem?.asset.tracks(withMediaType: .video),
           !videoTracks.isEmpty {
            // The asset loader already handles lower quality for preview
            // but we can apply additional player-specific optimizations here
        }
        
        logger.info("✅ Applied preview optimizations to player", metadata: ["correlationID": correlationID])
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.teardown()
        }
    }
}

// MARK: - Preview Optimized Readiness Monitor
class PreviewOptimizedReadinessMonitor {
    private var monitoringTask: Task<Void, Error>?
    private let timeout: TimeInterval = 10.0 // Shorter timeout for preview
    
    func waitForPlayerReady(_ player: AVPlayer) async throws {
        // Cancel any existing monitoring
        cancelMonitoring()
        
        // Start new monitoring task with shorter timeout for preview
        monitoringTask = Task {
            try await withCheckedThrowingContinuation { continuation in
                // Check if already ready
                if player.status == .readyToPlay {
                    continuation.resume()
                    return
                }
                
                // Set up a publisher to listen for status changes
                let cancellable = player.publisher(for: \.status)
                    .dropFirst() // Skip the current value
                    .sink { status in
                        if status == .readyToPlay {
                            continuation.resume()
                        } else if status == .failed {
                            continuation.resume(throwing: NSError(domain: "VideoPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Player failed to become ready"]))
                        }
                    }
                
                // Set up a timeout with shorter duration for preview
                Task {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    cancellable.cancel()
                    continuation.resume(throwing: NSError(domain: "VideoPlayer", code: -2, userInfo: [NSLocalizedDescriptionKey: "Preview player readiness timeout"]))
                }
            }
        }
        
        try await monitoringTask?.value
    }
    
    func cancelMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }
}