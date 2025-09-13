import SwiftUI
import AVKit
import OSLog

// MARK: - VideoPlayerCacheManager Protocol
protocol VideoPlayerCacheManagerProtocol {
    func cacheVideoPlayerViewModel(_ viewModel: any VideoPlayerViewModelProtocol, for asset: AVAsset, photosIdentifier: String?, rotation: Int)
    func getCachedPlayerViewModel(asset: AVAsset, photosIdentifier: String?, rotation: Int) -> (any VideoPlayerViewModelProtocol)?
    func clearCache()
    func ensureCacheCapacity()
}

// MARK: - Video Player Cache Manager
@MainActor
class VideoPlayerCacheManager: VideoPlayerCacheManagerProtocol {
    
    // MARK: - Properties
    private var videoPlayerCache: [String: any VideoPlayerViewModelProtocol] = [:]
    private let maxCacheSize = 2
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "VideoPlayerCacheManager")
    
    // MARK: - Initialization
    init() {
        logger.info("🗄️ VIDEO_CACHE: Initialized with max cache size: \(self.maxCacheSize)")
    }
    
    // MARK: - Public API
    
    /// Cache a video player view model for future use
    func cacheVideoPlayerViewModel(_ viewModel: any VideoPlayerViewModelProtocol, for asset: AVAsset, photosIdentifier: String?, rotation: Int) {
        let cacheKey = generateCacheKey(asset: asset, photosIdentifier: photosIdentifier, rotation: rotation)
        
        // Ensure cache doesn't exceed maximum size
        ensureCacheCapacity()
        
        videoPlayerCache[cacheKey] = viewModel
        logger.info("🗄️ VIDEO_CACHE: 📦 Cached view model for key: \(cacheKey.prefix(8))...")
        logger.info("🗄️ VIDEO_CACHE: 📊 Total cache entries: \(self.videoPlayerCache.count)")
    }
    
    /// Get cached player view model for the given asset and rotation
    func getCachedPlayerViewModel(asset: AVAsset, photosIdentifier: String?, rotation: Int) -> (any VideoPlayerViewModelProtocol)? {
        let cacheKey = generateCacheKey(asset: asset, photosIdentifier: photosIdentifier, rotation: rotation)
        logger.info("🗄️ VIDEO_CACHE: 🔍 Looking for cached player with key: \(cacheKey.prefix(8))...")
        
        if let cachedViewModel = self.videoPlayerCache[cacheKey] {
            logger.info("🗄️ VIDEO_CACHE: 🚀 Cache HIT! Found cached view model")
            logger.info("🗄️ VIDEO_CACHE: 🎯 Cached player state: \(String(describing: cachedViewModel.state))")
            return cachedViewModel
        } else {
            logger.warning("🗄️ VIDEO_CACHE: ⚠️ Cache MISS! No view model found for key: \(cacheKey.prefix(8))...")
            logger.info("🗄️ VIDEO_CACHE: 🔑 Available cache keys: \(Array(self.videoPlayerCache.keys.map { $0.prefix(8) }))")
            return nil
        }
    }
    
    /// Clear all cached video player view models
    func clearCache() {
        logger.info("🗄️ VIDEO_CACHE: 🗑️ Clearing all cached video player view models")
        logger.info("🗄️ VIDEO_CACHE: 📊 Removing \(self.videoPlayerCache.count) cached entries")
        self.videoPlayerCache.removeAll()
        logger.info("🗄️ VIDEO_CACHE: ✅ Cache cleared successfully")
    }
    
    /// Ensure cache capacity by removing oldest entries if needed
    func ensureCacheCapacity() {
        guard self.videoPlayerCache.count >= self.maxCacheSize else { 
            logger.info("🗄️ VIDEO_CACHE: 📊 Cache capacity OK (\(self.videoPlayerCache.count)/\(self.maxCacheSize))")
            return 
        }
        
        logger.info("🗄️ VIDEO_CACHE: 🧹 Cache capacity reached, removing oldest entry")
        logger.info("🗄️ VIDEO_CACHE: 📊 Current cache size: \(self.videoPlayerCache.count), max size: \(self.maxCacheSize)")
        
        // Remove the first entry (simple LRU)
        if let firstKey = self.videoPlayerCache.keys.first {
            self.videoPlayerCache.removeValue(forKey: firstKey)
            logger.info("🗄️ VIDEO_CACHE: Removed cached view model: \(firstKey.prefix(8))...")
            logger.info("🗄️ VIDEO_CACHE: 📊 New cache size: \(self.videoPlayerCache.count)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Generate a unique cache key for video player view models
    private func generateCacheKey(asset: AVAsset, photosIdentifier: String?, rotation: Int) -> String {
        if let urlAsset = asset as? AVURLAsset {
            let key = "\(urlAsset.url.absoluteString)_rotation_\(rotation)"
            logger.info("🗄️ VIDEO_CACHE: 🔑 Generated URL-based cache key: \(key.prefix(20))...")
            return key
        } else if let identifier = photosIdentifier {
            let key = "\(identifier)_rotation_\(rotation)"
            logger.info("🗄️ VIDEO_CACHE: 🔑 Generated photos-based cache key: \(key.prefix(20))...")
            return key
        } else {
            let key = "\(ObjectIdentifier(asset).hashValue)_rotation_\(rotation)"
            logger.info("🗄️ VIDEO_CACHE: 🔑 Generated object-based cache key: \(key.prefix(20))...")
            return key
        }
    }
    
    // MARK: - Debug Properties
    
    /// Current cache count for debugging
    var cacheCount: Int {
        return self.videoPlayerCache.count
    }
    
    /// All cache keys for debugging
    var cacheKeys: [String] {
        return Array(self.videoPlayerCache.keys)
    }
}