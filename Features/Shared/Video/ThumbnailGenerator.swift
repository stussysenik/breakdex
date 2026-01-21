import Foundation
import Photos
import AVFoundation
import UIKit
import OSLog

// MARK: - Thumbnail Generator
/// Efficient video thumbnail generator with caching and preloading support.
/// Uses AVAssetImageGenerator for instant keyframe access to eliminate
/// "Preparing video..." delays in the UI.

@MainActor
final class ThumbnailGenerator: ObservableObject {

    // MARK: - Singleton

    static let shared = ThumbnailGenerator()

    // MARK: - Properties

    /// In-memory cache for generated thumbnails
    private let cache = NSCache<NSString, UIImage>()

    /// Track pending generation tasks to avoid duplicates
    private var pendingTasks: Set<String> = []

    /// Logger for debugging
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🖼️ THUMBNAIL")

    /// Maximum cache cost (approximate bytes)
    private let maxCacheCost = 50 * 1024 * 1024  // 50 MB

    /// Default thumbnail size
    static let defaultSize = CGSize(width: 400, height: 400)

    // MARK: - Initialization

    private init() {
        cache.totalCostLimit = maxCacheCost
        cache.countLimit = 100

        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Memory Management

    @objc private func handleMemoryWarning() {
        logger.info("🖼️ Memory warning - clearing thumbnail cache")
        cache.removeAllObjects()
    }

    /// Clear all cached thumbnails
    func clearCache() {
        cache.removeAllObjects()
        logger.info("🖼️ Thumbnail cache cleared")
    }

    // MARK: - Cache Key Generation

    /// Generates a unique cache key for a thumbnail
    private func cacheKey(identifier: String, time: Double, size: CGSize) -> NSString {
        return "\(identifier)_\(time)_\(Int(size.width))x\(Int(size.height))" as NSString
    }

    // MARK: - Thumbnail Generation

    /// Generates a thumbnail for a video at a specific time
    /// - Parameters:
    ///   - photosIdentifier: The Photos library local identifier
    ///   - time: The time in seconds to extract the frame
    ///   - size: The desired thumbnail size (default: 400x400)
    /// - Returns: UIImage if successful, nil otherwise
    func thumbnail(
        for photosIdentifier: String,
        at time: Double = 0,
        size: CGSize = defaultSize
    ) async -> UIImage? {
        guard !photosIdentifier.isEmpty else {
            return nil
        }

        let key = cacheKey(identifier: photosIdentifier, time: time, size: size)

        // Check cache first
        if let cached = cache.object(forKey: key) {
            logger.debug("🖼️ Cache hit for \(photosIdentifier)")
            return cached
        }

        // Avoid duplicate generation
        guard !pendingTasks.contains(key as String) else {
            logger.debug("🖼️ Already generating thumbnail for \(photosIdentifier)")
            // Wait a bit and try cache again
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            return cache.object(forKey: key)
        }

        pendingTasks.insert(key as String)
        defer { pendingTasks.remove(key as String) }

        // Fetch the AVAsset
        guard let asset = await PhotosAssetLoader.fetchAsset(with: photosIdentifier) else {
            logger.warning("🖼️ Failed to fetch asset for \(photosIdentifier)")
            return nil
        }

        // Generate thumbnail
        let image = await generateThumbnail(from: asset, at: time, size: size)

        if let image = image {
            // Cache with estimated cost
            let cost = Int(image.size.width * image.size.height * 4)
            cache.setObject(image, forKey: key, cost: cost)
            logger.debug("🖼️ Generated and cached thumbnail for \(photosIdentifier)")
        }

        return image
    }

    /// Generates thumbnail directly from an AVAsset
    /// - Parameters:
    ///   - asset: The AVAsset to extract frame from
    ///   - time: The time in seconds
    ///   - size: The desired size
    /// - Returns: UIImage if successful
    func generateThumbnail(
        from asset: AVAsset,
        at time: Double = 0,
        size: CGSize = defaultSize
    ) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = size
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)

        let cmTime = CMTime(seconds: max(0, time), preferredTimescale: 600)

        do {
            // Use the modern async API if available
            if #available(iOS 16.0, *) {
                let (cgImage, _) = try await generator.image(at: cmTime)
                return UIImage(cgImage: cgImage)
            } else {
                // Fallback for older iOS
                return await withCheckedContinuation { continuation in
                    var actualTime = CMTime.zero
                    do {
                        let cgImage = try generator.copyCGImage(at: cmTime, actualTime: &actualTime)
                        continuation.resume(returning: UIImage(cgImage: cgImage))
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
        } catch {
            logger.error("🖼️ Failed to generate thumbnail: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Preloading

    /// Preloads thumbnails for a list of moves
    /// Call this during list initialization for smooth scrolling
    /// - Parameters:
    ///   - moves: Array of Move objects to preload
    ///   - size: Thumbnail size (default: 400x400)
    func preloadThumbnails(for moves: [Move], size: CGSize = defaultSize) async {
        logger.info("🖼️ Starting preload for \(moves.count) moves")

        // Use a task group for concurrent loading with limited parallelism
        await withTaskGroup(of: Void.self) { group in
            var count = 0
            for move in moves {
                guard let identifier = move.photosIdentifier else { continue }

                // Use trim start time as the thumbnail time, or 0 if not set
                let time = move.trimStartTime > 0 ? move.trimStartTime : 0

                // Skip if already cached
                let key = cacheKey(identifier: identifier, time: time, size: size)
                if cache.object(forKey: key) != nil {
                    continue
                }

                group.addTask { [weak self] in
                    _ = await self?.thumbnail(for: identifier, at: time, size: size)
                }

                count += 1

                // Limit concurrent tasks to 4 to avoid overwhelming the system
                if count >= 4 {
                    await group.next()
                    count -= 1
                }
            }
        }

        logger.info("🖼️ Preload complete")
    }

    /// Preloads a single thumbnail with priority
    /// - Parameters:
    ///   - move: The Move to preload
    ///   - size: Thumbnail size
    func preloadThumbnail(for move: Move, size: CGSize = defaultSize) async {
        guard let identifier = move.photosIdentifier else { return }
        let time = move.trimStartTime > 0 ? move.trimStartTime : 0
        _ = await thumbnail(for: identifier, at: time, size: size)
    }

    // MARK: - Timeline Strip Generation

    /// Generates a series of thumbnails for a timeline strip
    /// - Parameters:
    ///   - photosIdentifier: The Photos library identifier
    ///   - count: Number of frames to generate
    ///   - startTime: Start time in seconds
    ///   - endTime: End time in seconds
    ///   - size: Size of each thumbnail
    /// - Returns: Array of UIImages
    func timelineStrip(
        for photosIdentifier: String,
        count: Int,
        startTime: Double,
        endTime: Double,
        size: CGSize = CGSize(width: 80, height: 80)
    ) async -> [UIImage] {
        guard !photosIdentifier.isEmpty, count > 0, endTime > startTime else {
            return []
        }

        guard let asset = await PhotosAssetLoader.fetchAsset(with: photosIdentifier) else {
            return []
        }

        let interval = (endTime - startTime) / Double(count)
        var images: [UIImage] = []

        for i in 0..<count {
            let time = startTime + (Double(i) * interval)
            if let image = await generateThumbnail(from: asset, at: time, size: size) {
                images.append(image)
            }
        }

        return images
    }

    // MARK: - Cache Status

    /// Returns whether a thumbnail is cached
    func isCached(identifier: String, time: Double = 0, size: CGSize = defaultSize) -> Bool {
        let key = cacheKey(identifier: identifier, time: time, size: size)
        return cache.object(forKey: key) != nil
    }

    /// Returns the cached thumbnail if available (synchronous)
    func cachedThumbnail(for identifier: String, at time: Double = 0, size: CGSize = defaultSize) -> UIImage? {
        let key = cacheKey(identifier: identifier, time: time, size: size)
        return cache.object(forKey: key)
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

/// Async thumbnail image view with loading state
struct AsyncThumbnailView: View {
    let photosIdentifier: String
    let time: Double
    let size: CGSize

    @State private var image: UIImage?
    @State private var isLoading = true

    init(
        photosIdentifier: String,
        time: Double = 0,
        size: CGSize = ThumbnailGenerator.defaultSize
    ) {
        self.photosIdentifier = photosIdentifier
        self.time = time
        self.size = size
    }

    init(move: Move) {
        self.photosIdentifier = move.photosIdentifier ?? ""
        self.time = move.trimStartTime > 0 ? move.trimStartTime : 0
        self.size = ThumbnailGenerator.defaultSize
    }

    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else if isLoading {
                // Skeleton loading state
                Rectangle()
                    .fill(Color.backgroundSecondary)
                    .overlay(
                        ProgressView()
                            .tint(.textSecondary)
                    )
            } else {
                // Error/placeholder state
                Rectangle()
                    .fill(Color.backgroundSecondary)
                    .overlay(
                        Image(systemName: "film")
                            .font(.largeTitle)
                            .foregroundColor(.textSecondary)
                    )
            }
        }
        .animation(MotionSystem.micro, value: image != nil)
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        // Check cache first (synchronous)
        if let cached = ThumbnailGenerator.shared.cachedThumbnail(
            for: photosIdentifier,
            at: time,
            size: size
        ) {
            image = cached
            isLoading = false
            return
        }

        // Load asynchronously
        isLoading = true
        image = await ThumbnailGenerator.shared.thumbnail(
            for: photosIdentifier,
            at: time,
            size: size
        )
        isLoading = false
    }
}

// MARK: - Preview

#if DEBUG
struct ThumbnailGenerator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Thumbnail Generator Demo")
                .font(.ibmPlexMono(size: 20, weight: .bold))

            // Placeholder for demo
            AsyncThumbnailView(photosIdentifier: "test-identifier")
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("Thumbnails load asynchronously\nwith caching for smooth scrolling")
                .font(.ibmPlexMono(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
#endif
