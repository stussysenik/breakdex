import Foundation
import AVFoundation
import Photos
import os.log
import CoreData

// MARK: - Progress Events
public enum VideoLoadEvent {
    case progress(fraction: Double, status: String)
    case success(asset: AVAsset)
}

// MARK: - Video Loading Service Protocol
public protocol VideoLoadingService {
    func loadPHAssetWithProgress(_ asset: PHAsset) -> AsyncThrowingStream<VideoLoadEvent, Error>
    func cancelCurrentOperation()
}

// MARK: - Live Implementation
public final class LiveVideoLoadingService: VideoLoadingService {
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "VideoLoadingService")
    private var currentRequestID: PHImageRequestID?
    private let memoryManager: MemoryManager
    private let appLogger: AppLogger
    
    public enum Source {
        case photos(PHAsset)
        case url(URL)
        case asset(AVAsset)
    }
    
    public enum VideoLoadingError: Error, LocalizedError {
        case assetNotFound
        case avAssetCreationFailed
        case unsupportedFileType
        case dataUnavailable
        case memoryLimitExceeded(used: Int64, available: Int64)
        
        public var errorDescription: String? {
            switch self {
            case .assetNotFound:
                return "Could not find the video asset."
            case .avAssetCreationFailed:
                return "Failed to create a playable video asset."
            case .unsupportedFileType:
                return "The selected file type is not a supported video format."
            case .dataUnavailable:
                return "Could not retrieve video data for the selected item."
            case .memoryLimitExceeded(let used, let available):
                return "Memory limit exceeded. Used: \(used)MB, Available: \(available)MB"
            }
        }
    }
    
    public init(memoryManager: MemoryManager, logger: AppLogger) {
        self.memoryManager = memoryManager
        self.appLogger = logger
    }
    
    private func checkMemoryBeforeLoading() throws {
        let availableMemory = memoryManager.getAvailableMemory()
        let memoryThreshold: Int64 = 200 * 1024 * 1024 // 200MB
        
        if availableMemory < memoryThreshold {
            appLogger.warning("⚠️ Low memory before loading asset: \(availableMemory / (1024 * 1024))MB", metadata: nil)
            memoryManager.clearCache()
            
            // If still low, throw error
            if memoryManager.getAvailableMemory() < memoryThreshold {
                let error = VideoLoadingError.memoryLimitExceeded(
                    used: memoryManager.getUsedMemory() / (1024 * 1024),
                    available: availableMemory / (1024 * 1024)
                )
                appLogger.error("❌ Memory limit exceeded: \(error.localizedDescription)", metadata: nil)
                throw error
            }
        }
    }
    
    public func loadAssetWithProgress(from source: Source) -> AsyncThrowingStream<VideoLoadEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try checkMemoryBeforeLoading()
                    
                    switch source {
                    case .photos(let phAsset):
                        let phAssetStream = loadPHAssetWithProgress(phAsset)
                        for try await event in phAssetStream {
                            continuation.yield(event)
                        }
                    case .url(let url):
                        try await loadURLAssetWithProgress(url: url, continuation: continuation)
                    case .asset(let asset):
                        try await loadPreloadedAssetWithProgress(asset: asset, continuation: continuation)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func loadURLAssetWithProgress(url: URL, continuation: AsyncThrowingStream<VideoLoadEvent, Error>.Continuation) async throws {
        // For URL assets, we can simulate progress since they load quickly
        continuation.yield(.progress(fraction: 0.3, status: "Loading video file..."))
        
        let asset = AVURLAsset(url: url)
        
        // Load basic properties
        continuation.yield(.progress(fraction: 0.6, status: "Reading video metadata..."))
        try await asset.load(.isPlayable, .duration, .tracks)
        
        continuation.yield(.progress(fraction: 0.8, status: "Preparing player..."))
        
        // Create player and monitor buffering
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        let monitor = await PlayerItemStatusMonitor(playerItem: playerItem)

        try await monitor.awaitReadyAndBuffered(timeout: 15.0, onProgress: { bufferProgress in
            let overallProgress = 0.8 + (bufferProgress * 0.2)
            continuation.yield(.progress(fraction: overallProgress, status: "Buffering video..."))
        })
        
        continuation.yield(.success(asset: asset))
        continuation.finish()
    }
    
    private func loadPreloadedAssetWithProgress(asset: AVAsset, continuation: AsyncThrowingStream<VideoLoadEvent, Error>.Continuation) async throws {
        // For pre-loaded assets, simulate quick progress
        continuation.yield(.progress(fraction: 0.8, status: "Preparing player..."))
        
        // Create player and monitor buffering
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        let monitor = await PlayerItemStatusMonitor(playerItem: playerItem)

        try await monitor.awaitReadyAndBuffered(timeout: 15.0, onProgress: { bufferProgress in
            let overallProgress = 0.8 + (bufferProgress * 0.2)
            continuation.yield(.progress(fraction: overallProgress, status: "Buffering video..."))
        })
        
        continuation.yield(.success(asset: asset))
        continuation.finish()
    }
    
    public func loadPHAssetWithProgress(_ asset: PHAsset) -> AsyncThrowingStream<VideoLoadEvent, Error> {
        AsyncThrowingStream { continuation in
            // Cancel any previous request before starting a new one.
            cancelCurrentOperation()
            
            // Check memory before loading
            do {
                try checkMemoryBeforeLoading()
            } catch {
                continuation.finish(throwing: error)
                return
            }

            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat // Request high quality for trimming.
            
            // STAGE 1: iCloud Download Progress (0% -> 70%)
            options.progressHandler = { progress, _, _, _ in
                let scaledProgress = progress * 0.7 // Scale to 0-70% range
                let status = progress < 0.9 ? "Downloading from iCloud..." : "Finalizing download..."
                continuation.yield(.progress(fraction: scaledProgress, status: status))
            }

            currentRequestID = PHImageManager.default().requestAVAsset(
                forVideo: asset,
                options: options
            ) { [weak self] avAsset, _, info in
                guard let self = self else { return }
                
                Task {
                    do {
                        if let error = info?[PHImageErrorKey] as? Error {
                            continuation.finish(throwing: error)
                            return
                        }
                        guard let loadedAsset = avAsset else {
                            throw NSError(domain: "VideoLoadingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "AVAsset is nil."])
                        }

                        // STAGE 2: Loading Asset Properties (70% -> 100%)
                        continuation.yield(.progress(fraction: 0.7, status: "Loading video metadata..."))
                        try await loadedAsset.load(.isPlayable, .duration, .tracks)
                        continuation.yield(.progress(fraction: 0.95, status: "Preparing asset..."))
                        
                        // YIELD FINAL RESULT
                        continuation.yield(.success(asset: loadedAsset))
                        continuation.finish()

                    } catch {
                        continuation.finish(throwing: error)
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
    }
    
    deinit {
        cancelCurrentOperation()
    }
}