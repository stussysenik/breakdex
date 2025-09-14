import Foundation
import AVFoundation
import Combine

@MainActor
public class PreviewOptimizedReadinessMonitor {
    private var cancellables = Set<AnyCancellable>()
    private var readinessTimer: Timer?
    private let timeoutInterval: TimeInterval = 15.0 // Shorter timeout for preview
    private let logger: AppLogger
    private let correlationID = UUID().uuidString
    
    public init(logger: AppLogger? = nil) {
        self.logger = logger ?? ConsoleLogger()
        self.logger.info("⏱️ PreviewOptimizedReadinessMonitor initialized", metadata: ["correlationID": correlationID])
    }
    
    public func waitForPlayerReady(_ player: AVPlayer) async throws {
        logger.info("⏱️ Waiting for preview player to be ready", metadata: ["correlationID": correlationID])
        
        return try await withCheckedThrowingContinuation { continuation in
            // Check if already ready
            if player.status == .readyToPlay {
                logger.info("✅ Preview player already ready", metadata: ["correlationID": correlationID])
                continuation.resume()
                return
            }
            
            // Set up publisher for status changes
            player.publisher(for: \.status)
                .receive(on: RunLoop.main)
                .sink { [weak self] status in
                    guard let self = self else { return }
                    
                    switch status {
                    case .readyToPlay:
                        self.logger.info("✅ Preview player is ready to play", metadata: ["correlationID": self.correlationID])
                        continuation.resume()
                    case .failed:
                        self.logger.error("❌ Preview player failed to load", metadata: ["correlationID": self.correlationID])
                        if let error = player.error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(throwing: VideoProcessingError.playerInitializationFailed)
                        }
                    case .unknown:
                        // Still loading, continue waiting
                        break
                    @unknown default:
                        break
                    }
                }
                .store(in: &cancellables)
            
            // Set up timeout
            readinessTimer = Timer.scheduledTimer(withTimeInterval: timeoutInterval, repeats: false) { _ in
                self.logger.error("❌ Preview player readiness timeout", metadata: ["correlationID": self.correlationID])
                continuation.resume(throwing: VideoProcessingError.readinessTimeout)
            }
        }
    }
    
    public func cancelMonitoring() {
        logger.info("🔄 Canceling preview readiness monitoring", metadata: ["correlationID": correlationID])
        
        cancellables.removeAll()
        readinessTimer?.invalidate()
        readinessTimer = nil
        
        logger.info("✅ Preview readiness monitoring canceled", metadata: ["correlationID": correlationID])
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.cancelMonitoring()
        }
    }
}