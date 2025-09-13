import SwiftUI
import AVKit
import Combine

// MARK: - Video Player View Model Protocol
@MainActor
public protocol VideoPlayerViewModelProtocol: ObservableObject, Equatable, Hashable {
    // MARK: - Associated Types
    associatedtype State: Equatable, Hashable
    
    // MARK: - Published Properties
    var state: State { get }
    var shouldPlay: Bool { get }
    var healthStatus: VideoHealthStatus { get }
    
    // MARK: - Public Accessors
    var avPlayer: AVPlayer? { get }
    var isPlayerReady: Bool { get }
    
    // MARK: - Public Methods
    func loadVideo(fromPhotosIdentifier identifier: String, quarterTurns: Int)
    func loadVideo(fromURL url: URL, quarterTurns: Int)
    func loadVideo(fromMove move: Move, quarterTurns: Int)
    func setRotation(_ quarterTurns: Int)
    func startPlayback()
    func teardown()
    func pauseForTrimming()
    func resumeAfterTrimming()
    func waitForReady() async throws
}

// MARK: - Default Implementation for Equatable and Hashable
public extension VideoPlayerViewModelProtocol {
    static func == (lhs: Self, rhs: Self) -> Bool {
        // This will be overridden by the implementing classes
        return false
    }
    
    func hash(into hasher: inout Hasher) {
        // This will be overridden by the implementing classes
        hasher.combine(state)
    }
}