import SwiftUI
import AVKit
import Combine
import CoreData

/// Defines a generic video source for the player
public enum VideoSource {
    case photos(identifier: String)
    case url(URL)
    case move(Move)
}

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
    func loadVideo(from source: VideoSource, quarterTurns: Int)
    func setRotation(_ quarterTurns: Int)
    func startPlayback()
    func teardown()
    func pauseForTrimming()
    func resumeAfterTrimming()
    func waitForReady() async throws
    func seek(to time: CMTime)
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