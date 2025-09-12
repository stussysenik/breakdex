import Foundation
import AVFoundation
import Combine

@MainActor
public class VideoCoordinator: ObservableObject {
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
    
    private let assetLoader = VideoAssetLoader()
    private let playerInitializer = PlayerInitializer()
    private let readinessMonitor = ReadinessMonitor()
    private var correlationID: String = ""
    private var currentTask: Task<Void, Never>?
    
    public init() {
        correlationID = VideoLogger.generateCorrelationID()
        VideoLogger.log("VideoCoordinator initialized", category: "COORDINATOR", correlationID: correlationID)
    }
    
    public func loadVideo(from source: VideoAssetLoader.Source, quarterTurns: Int = 0) async {
        VideoLogger.log("Starting video load", category: "COORDINATOR", correlationID: correlationID)
        
        // Cancel any existing task
        currentTask?.cancel()
        
        // Reset state
        state = .loading
        
        // Start new task
        currentTask = Task {
            do {
                // Step 1: Load asset
                VideoLogger.log("Loading asset", category: "COORDINATOR", correlationID: correlationID)
                let asset = try await assetLoader.loadAsset(from: source)
                VideoLogger.log("Asset loaded successfully", category: "COORDINATOR", correlationID: correlationID)
                
                // Check for cancellation
                if Task.isCancelled { return }
                
                // Step 2: Create player
                VideoLogger.log("Creating player", category: "COORDINATOR", correlationID: correlationID)
                let player = try await playerInitializer.createPlayer(from: asset, quarterTurns: quarterTurns)
                VideoLogger.log("Player created successfully", category: "COORDINATOR", correlationID: correlationID)
                
                // Check for cancellation
                if Task.isCancelled { return }
                
                // Step 3: Wait for player to be ready
                VideoLogger.log("Waiting for player to be ready", category: "COORDINATOR", correlationID: correlationID)
                try await readinessMonitor.waitForPlayerReady(player)
                VideoLogger.log("Player is ready", category: "COORDINATOR", correlationID: correlationID)
                
                // Check for cancellation
                if Task.isCancelled { return }
                
                // Update state
                state = .ready(player)
                VideoLogger.log("Video load completed successfully", category: "COORDINATOR", correlationID: correlationID)
                
            } catch {
                // Handle error
                let videoError = VideoErrorHandler.handle(error, correlationID: correlationID)
                state = .error(videoError)
                VideoLogger.error("Video load failed: \(videoError.errorDescription ?? "Unknown error")", error: error, category: "COORDINATOR", correlationID: correlationID)
            }
        }
    }
    
    public func teardown() {
        VideoLogger.log("Tearing down video coordinator", category: "COORDINATOR", correlationID: correlationID)
        
        // Cancel any existing task
        currentTask?.cancel()
        currentTask = nil
        
        // Cancel readiness monitoring
        readinessMonitor.cancelMonitoring()
        
        // Reset state
        state = .loading
        
        VideoLogger.log("Teardown completed", category: "COORDINATOR", correlationID: correlationID)
    }
    
    public func startPlayback() {
        VideoLogger.log("Starting playback", category: "COORDINATOR", correlationID: correlationID)
        
        if case .ready(let player) = state {
            player.play()
            VideoLogger.log("Playback started", category: "COORDINATOR", correlationID: correlationID)
        } else {
            VideoLogger.warning("Cannot start playback - player not ready", category: "COORDINATOR", correlationID: correlationID)
        }
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.teardown()
        }
    }
}