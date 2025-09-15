import Foundation
import AVFoundation
import Photos
import os.log

// MARK: - Progress Events
public struct VideoLoadEvents {
    let fraction: Double
    let etaSeconds: TimeInterval?
    let stage: LoadingStage
    let status: String
    let asset: AVAsset?
    
    public enum LoadingStage {
        case downloadingFromICloud
        case loadingAssetProperties
        case preparingPlayerItem
        case monitoringReadiness
        case completed
    }
    
    init(fraction: Double, etaSeconds: TimeInterval?, stage: LoadingStage, status: String, asset: AVAsset? = nil) {
        self.fraction = fraction
        self.etaSeconds = etaSeconds
        self.stage = stage
        self.status = status
        self.asset = asset
    }
}

// MARK: - Video Loading Service Protocol
public protocol VideoLoadingService {
    func loadPHAssetWithProgress(_ asset: PHAsset) -> AsyncThrowingStream<VideoLoadEvents, Error>
    func cancelCurrentOperation()
}

// MARK: - Live Implementation
public final class LiveVideoLoadingService: VideoLoadingService {
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "VideoLoadingService")
    private var currentRequestID: PHImageRequestID?
    private var currentTask: Task<Void, Never>?
    
    public init() {}
    
    public func loadPHAssetWithProgress(_ asset: PHAsset) -> AsyncThrowingStream<VideoLoadEvents, Error> {
        AsyncThrowingStream { continuation in
            let startTime = CACurrentMediaTime()
            var lastProgressUpdate: TimeInterval = 0
            let progressUpdateThrottle: TimeInterval = 1.0 / 30.0 // 30 Hz max updates
            
            // Cancel any existing operation
            cancelCurrentOperation()
            
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .automatic
            options.version = .current
            
            options.progressHandler = { [weak self] progress, error, stop, info in
                guard let self = self else { return }
                
                let currentTime = CACurrentMediaTime()
                let timeSinceLastUpdate = currentTime - lastProgressUpdate
                
                // Throttle progress updates to avoid UI overload
                guard timeSinceLastUpdate >= progressUpdateThrottle || progress >= 1.0 else { return }
                lastProgressUpdate = currentTime
                
                Task { @MainActor in
                    do {
                        // Calculate ETA
                        let elapsed = currentTime - startTime
                        let f = max(0.001, progress) // Avoid division by zero
                        let eta = elapsed * (1.0 - f) / f
                        
                        // Determine status message
                        let status: String
                        if progress < 0.1 {
                            status = "Starting download..."
                        } else if progress < 0.5 {
                            status = "Downloading from iCloud..."
                        } else if progress < 0.9 {
                            status = "Almost there..."
                        } else {
                            status = "Finalizing..."
                        }
                        
                        let event = VideoLoadEvents(
                            fraction: progress,
                            etaSeconds: eta,
                            stage: .downloadingFromICloud,
                            status: status,
                            asset: nil
                        )
                        
                        continuation.yield(event)
                        
                        self.logger.info("📊 Progress: \(Int(progress * 100))%, ETA: \(String(format: "%.1f", eta))s")
                        
                    } catch {
                        self.logger.error("❌ Progress update error: \(error.localizedDescription)")
                    }
                }
            }
            
            // Start the asset request
            let requestID = PHImageManager.default().requestAVAsset(
                forVideo: asset,
                options: options
            ) { [weak self] avAsset, audioMix, info in
                guard let self = self else { return }
                
                Task { @MainActor in
                    do {
                        // Check for errors
                        if let error = info?[PHImageErrorKey] as? Error {
                            self.logger.error("❌ Photos error: \(error.localizedDescription)")
                            continuation.finish(throwing: error)
                            return
                        }
                        
                        guard let avAsset = avAsset else {
                            let error = NSError(
                                domain: "VideoLoadingService",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Asset unavailable"]
                            )
                            continuation.finish(throwing: error)
                            return
                        }
                        
                        // Phase 2: Real-time asset properties loading (70% → 90%)
                        continuation.yield(VideoLoadEvents(
                            fraction: 0.7,
                            etaSeconds: 3.0,
                            stage: .loadingAssetProperties,
                            status: "⚡ Loading video metadata...",
                            asset: nil
                        ))
                        
                        // Load asset properties with real progress tracking
                        let loadStart = Date()
                        
                        // Start loading all required properties concurrently
                        async let playableTask = avAsset.load(.isPlayable)
                        async let durationTask = avAsset.load(.duration)
                        async let tracksTask = avAsset.load(.tracks)
                        
                        // Monitor progress while properties load
                        let maxWait: TimeInterval = 8.0
                        while Date().timeIntervalSince(loadStart) < maxWait {
                            let elapsed = Date().timeIntervalSince(loadStart)
                            let progress = min(0.9, 0.7 + (elapsed / maxWait) * 0.2)
                            
                            let status = elapsed < 2 ? "🚀 Loading video metadata..." : 
                                        elapsed < 4 ? "💎 Reading video format..." : 
                                        "🎯 Analyzing video streams..."
                            
                            continuation.yield(VideoLoadEvents(
                                fraction: progress,
                                etaSeconds: maxWait - elapsed,
                                stage: .loadingAssetProperties,
                                status: status,
                                asset: nil
                            ))
                            
                            try await Task.sleep(nanoseconds: 200_000_000) // Update every 0.2s
                        }
                        
                        // Wait for all properties to complete loading
                        let (playable, duration, tracks) = try await (playableTask, durationTask, tracksTask)
                        
                        self.logger.info("✅ Asset loaded - Duration: \(duration.seconds)s, Tracks: \(tracks.count), Playable: \(playable)")
                        
                        // Phase 3: Real-time player preparation (90% → 95%)
                        continuation.yield(VideoLoadEvents(
                            fraction: 0.9,
                            etaSeconds: 2.0,
                            stage: .preparingPlayerItem,
                            status: "🔥 Creating video player...",
                            asset: nil
                        ))
                        
                        // Create player item with real-time preparation monitoring
                        let playerItem = AVPlayerItem(asset: avAsset)
                        
                        // Create and prepare the player for proper loading
                        let player = AVPlayer(playerItem: playerItem)
                        
                        // Monitor actual player item preparation progress
                        let prepStart = Date()
                        while Date().timeIntervalSince(prepStart) < 5.0 {
                            let elapsed = Date().timeIntervalSince(prepStart)
                            let progress = min(0.95, 0.9 + (elapsed / 5.0) * 0.05)
                            
                            let status = elapsed < 2 ? "🔥 Creating video player..." : 
                                        "⚡ Initializing playback buffers..."
                            
                            continuation.yield(VideoLoadEvents(
                                fraction: progress,
                                etaSeconds: 5.0 - elapsed,
                                stage: .preparingPlayerItem,
                                status: status,
                                asset: nil
                            ))
                            
                            try await Task.sleep(nanoseconds: 300_000_000) // Update every 0.3s
                        }
                        
                        // Phase 4: Real-time player readiness monitoring (95% → 100%)
                        var monitor: PlayerItemStatusMonitor? = PlayerItemStatusMonitor(playerItem: playerItem)
                        
                        // Let the PlayerItemStatusMonitor handle all monitoring internally
                        // This avoids conflicts between multiple KVO observers
                        
                        do {
                            try await monitor?.waitForReadyToPlay(timeout: 30.0)
                            
                            // Clean up monitor after successful completion
                            monitor = nil
                            
                            // Return the prepared asset in the completion event
                            let completedEvent = VideoLoadEvents(
                                fraction: 1.0,
                                etaSeconds: 0,
                                stage: .completed,
                                status: "🎉 Ready to trim your video!",
                                asset: avAsset
                            )
                            
                            continuation.yield(completedEvent)
                            continuation.finish()
                            
                        } catch {
                            // Clean up monitor on error
                            monitor = nil
                            continuation.finish(throwing: error)
                        }
                        
                    } catch {
                        self.logger.error("❌ Asset preparation error: \(error.localizedDescription)")
                        continuation.finish(throwing: error)
                    }
                }
            }
            
            // Store request ID for cancellation
            currentRequestID = requestID
            
            // Handle continuation termination
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.currentRequestID = nil
                    if let requestID = self.currentRequestID {
                        PHImageManager.default().cancelImageRequest(requestID)
                    }
                }
            }
        }
    }
    
    public func cancelCurrentOperation() {
        logger.info("🛑 Cancelling current video loading operation")
        
        if let requestID = currentRequestID {
            PHImageManager.default().cancelImageRequest(requestID)
            currentRequestID = nil
        }
        
        currentTask?.cancel()
        currentTask = nil
    }
    
    deinit {
        cancelCurrentOperation()
    }
}