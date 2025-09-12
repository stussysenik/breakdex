import SwiftUI
import AVKit
import Combine
import OSLog

@MainActor
public final class VideoPlayerViewModel: ObservableObject, @preconcurrency Equatable, @preconcurrency Hashable {
    public static func == (lhs: VideoPlayerViewModel, rhs: VideoPlayerViewModel) -> Bool {
        lhs.coordinator.state == rhs.coordinator.state
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(coordinator.state)
    }
    
    // MARK: - Public Properties
    
    public enum State {
        case loading
        case playing(player: AVPlayer)
        case error(message: String)
    }
    
    @Published public private(set) var state: State = .loading
    @Published public private(set) var shouldPlay: Bool = false
    
    // MARK: - Private Properties
    
    private let coordinator: VideoCoordinator
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Accessors
    
    /// Public getter for AVPlayer access (for logging and debugging)
    var avPlayer: AVPlayer? {
        if case .ready(let player) = coordinator.state {
            return player
        }
        return nil
    }
    
    var isPlayerReady: Bool {
        if case .ready = coordinator.state {
            return true
        }
        return false
    }
    
    // MARK: - Initialization
    
    /// Initialize with asset and rotation for immediate use
    public init(asset: AVAsset, rotationQuarterTurns: Int = 0) {
        self.coordinator = VideoCoordinator()
        
        // Subscribe to coordinator state changes
        coordinator.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] coordinatorState in
                self?.updateState(from: coordinatorState)
            }
            .store(in: &cancellables)
        
        // Load the video
        Task {
            // For now, we'll create a temporary URL from the asset
            // In a real implementation, we would pass the asset directly or use a different approach
            if let urlAsset = asset as? AVURLAsset {
                await coordinator.loadVideo(from: .url(urlAsset.url), quarterTurns: rotationQuarterTurns)
            }
        }
    }
    
    /// Legacy initializer for backward compatibility
    public init() {
        self.coordinator = VideoCoordinator()
        
        // Subscribe to coordinator state changes
        coordinator.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] coordinatorState in
                self?.updateState(from: coordinatorState)
            }
            .store(in: &cancellables)
    }
    
    deinit {
        Task { @MainActor [weak coordinator] in
            coordinator?.teardown()
        }
    }
    
    // MARK: - State Management
    
    private func updateState(from coordinatorState: VideoCoordinator.State) {
        switch coordinatorState {
        case .loading:
            state = .loading
        case .ready(let player):
            state = .playing(player: player)
        case .error(let videoError):
            state = .error(message: videoError.errorDescription ?? "Unknown error")
        }
    }
    
    // MARK: - Public Methods
    
    /// Load video from a Photos identifier
    public func loadVideo(fromPhotosIdentifier identifier: String, quarterTurns: Int = 0) {
        Task {
            await coordinator.loadVideo(from: .photos(identifier: identifier), quarterTurns: quarterTurns)
        }
    }
    
    /// Load video from a URL
    public func loadVideo(fromURL url: URL, quarterTurns: Int = 0) {
        Task {
            await coordinator.loadVideo(from: .url(url), quarterTurns: quarterTurns)
        }
    }
    
    /// Load video from a Move object
    public func loadVideo(fromMove move: Move, quarterTurns: Int = 0) {
        Task {
            await coordinator.loadVideo(from: .move(move), quarterTurns: quarterTurns)
        }
    }
    
    /// Set video rotation
    public func setRotation(_ quarterTurns: Int) {
        // We need to reload the video with the new rotation
        // For now, this is a simplified implementation
        // In a real implementation, we would preserve the current asset and just change the rotation
        if case .playing(let player) = state,
           let currentItem = player.currentItem,
           let urlAsset = currentItem.asset as? AVURLAsset {
            loadVideo(fromURL: urlAsset.url, quarterTurns: quarterTurns)
        }
    }
    
    /// Start playback
    public func startPlayback() {
        coordinator.startPlayback()
    }
    
    /// Teardown the player
    public func teardown() {
        Task { @MainActor in
            coordinator.teardown()
        }
        state = .loading
        shouldPlay = false
    }
    
    /// Wait for the player to be ready
    public func waitForReady() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            // Check if already ready
            if case .playing = state {
                continuation.resume()
                return
            }
            
            // Set up a publisher to listen for state changes
            let cancellable = $state
                .dropFirst() // Skip the current value
                .sink { newState in
                    if case .playing = newState {
                        continuation.resume()
                    } else if case .error(let message) = newState {
                        continuation.resume(throwing: VideoError.playbackFailed(underlyingError: NSError(domain: "VideoPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: message])))
                    }
                }
            
            // Store the cancellable to keep it alive
            self.cancellables.insert(cancellable)
            
            // Set up a timeout in case the player never becomes ready
            Task {
                try await Task.sleep(nanoseconds: 30 * 1_000_000_000) // 30 seconds
                cancellable.cancel()
                self.cancellables.remove(cancellable)
                continuation.resume(throwing: VideoError.readinessTimeout)
            }
        }
    }
    
    // MARK: - Legacy Methods
    
    /// Legacy method for backward compatibility
    func setSource(asset: AVAsset, quarterTurns: Int) {
        // For now, we'll create a temporary URL from the asset
        // In a real implementation, we would pass the asset directly or use a different approach
        if let urlAsset = asset as? AVURLAsset {
            loadVideo(fromURL: urlAsset.url, quarterTurns: quarterTurns)
        }
    }
}
