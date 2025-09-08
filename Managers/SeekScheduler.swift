
import Foundation
import AVFoundation
import Combine

final class SeekScheduler {
    private let player: AVPlayer
    private let asset: AVAsset // Added asset property
    private let seekQueue = DispatchQueue(label: "com.breakingflashcards.seek-scheduler", qos: .userInitiated)
    private var latestTargetTime: CMTime?
    private var currentSeekCompletion: ((Bool) -> Void)?
    private var isSeeking = false
    
    // For latency measurement (optional, for future enhancements)
    private var seekStartTime: Date?
    private let latencyThreshold: TimeInterval = 0.1 // Example threshold: 100ms
    
    init(player: AVPlayer, asset: AVAsset) {
        self.player = player
        self.asset = asset
    }
    
    func seek(to time: CMTime, completion: ((Bool) -> Void)? = nil) {
        seekQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.latestTargetTime = time
            self.currentSeekCompletion = completion
            
            self.performSeekIfNeeded()
        }
    }
    
    private func performSeekIfNeeded() {
        guard !self.isSeeking, let targetTime = self.latestTargetTime else {
            return
        }
        
        self.isSeeking = true
        self.latestTargetTime = nil // Clear the latest target as we are about to seek to it
        self.seekStartTime = Date() // Record seek start time
        
        let completionHandler = self.currentSeekCompletion
        self.currentSeekCompletion = nil
        
        // Use relaxed tolerances
        self.player.seek(to: targetTime, toleranceBefore: .positiveInfinity, toleranceAfter: .positiveInfinity) { [weak self] finished in
            self?.seekQueue.async {
                guard let self = self else { return }
                
                self.isSeeking = false
                
                // Measure latency and trigger fallback if too high
                if let startTime = self.seekStartTime {
                    let latency = Date().timeIntervalSince(startTime)
                    print("Seek latency: \(latency) seconds")
                    if latency > self.latencyThreshold {
                        print("Seek latency too high (\(latency)s), considering fallback mechanism.")
                        // TODO: Implement actual fallback (e.g., stepByCount or generateImage)
                    }
                }
                
                completionHandler?(finished)
                
                // If there's a new seek request that came in while we were seeking, perform it
                self.performSeekIfNeeded()
            }
        }
    }
    
    // Placeholder for potential fallback methods
    func stepByCount(count: Int) {
        // Implement frame stepping if needed
    }
    
    func generateImage(at time: CMTime) {
        // Implement AVAssetImageGenerator if needed
    }
}
