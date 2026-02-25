import AVFoundation
import Observation
import UIKit

@Observable
final class AdaptiveThumbnailGenerator {
    /// Sparse storage: index → thumbnail
    private(set) var thumbnails: [Int: UIImage] = [:]
    private(set) var isGenerating = false
    private(set) var totalCount = 0

    private let asset: AVAsset
    private let imageGenerator: AVAssetImageGenerator
    private let cache = NSCache<NSNumber, UIImage>()
    private let operationQueue = OperationQueue()

    private var duration: TimeInterval = 0
    private var pendingIndices = Set<Int>()
    private var thumbnailSize: CGSize

    /// Duration tiers
    private enum Tier {
        case short      // < 2 min: generate all upfront
        case medium     // 2–10 min: batches of 20
        case long       // 10–30 min: on-demand only
    }

    private var tier: Tier {
        if duration <= 120 { return .short }
        if duration <= 600 { return .medium }
        return .long
    }

    private var prefetchWindow: Int {
        switch tier {
        case .short:  return totalCount
        case .medium: return 10
        case .long:   return 5
        }
    }

    init(asset: AVAsset, thumbnailSize: CGSize = CGSize(width: 100, height: 60)) {
        self.asset = asset
        self.thumbnailSize = thumbnailSize
        self.imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = thumbnailSize
        imageGenerator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        imageGenerator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)

        cache.countLimit = 80
        cache.totalCostLimit = 30 * 1024 * 1024 // 30MB

        operationQueue.maxConcurrentOperationCount = 3
        operationQueue.qualityOfService = .userInitiated
    }

    /// Call once with the video duration and desired count
    func configure(duration: TimeInterval, count: Int) {
        self.duration = duration
        self.totalCount = count

        if tier == .short {
            loadThumbnails(for: 0..<count)
        }
    }

    /// Update visible range — triggers on-demand loading + eviction
    func updateVisibleRange(_ range: Range<Int>) {
        let lo = max(0, range.lowerBound - prefetchWindow)
        let hi = min(totalCount, range.upperBound + prefetchWindow)
        let needed = (lo..<hi).filter { thumbnails[$0] == nil && !pendingIndices.contains($0) }

        if !needed.isEmpty {
            loadThumbnails(for: needed)
        }

        // Evict thumbnails far outside visible range (keep in NSCache though)
        if tier != .short {
            let evictBelow = max(0, range.lowerBound - prefetchWindow * 2)
            let evictAbove = min(totalCount, range.upperBound + prefetchWindow * 2)
            for key in thumbnails.keys where key < evictBelow || key >= evictAbove {
                thumbnails.removeValue(forKey: key)
            }
        }
    }

    /// Get thumbnail for index (may return nil if not yet loaded)
    func thumbnail(at index: Int) -> UIImage? {
        if let img = thumbnails[index] { return img }
        if let cached = cache.object(forKey: NSNumber(value: index)) {
            thumbnails[index] = cached
            return cached
        }
        return nil
    }

    // MARK: - Private

    private func loadThumbnails<S: Sequence>(for indices: S) where S.Element == Int {
        guard duration > 0, totalCount > 0 else { return }
        isGenerating = true

        let interval = duration / Double(totalCount)
        var times: [(Int, NSValue)] = []

        for index in indices {
            guard index >= 0, index < totalCount, !pendingIndices.contains(index) else { continue }
            pendingIndices.insert(index)
            let seconds = Double(index) * interval
            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            times.append((index, NSValue(time: time)))
        }

        guard !times.isEmpty else {
            isGenerating = false
            return
        }

        operationQueue.addOperation { [weak self] in
            guard let self else { return }
            let group = DispatchGroup()
            let generator = self.imageGenerator
            let cache = self.cache

            for (index, timeValue) in times {
                group.enter()
                generator.generateCGImagesAsynchronously(forTimes: [timeValue]) { [weak self] _, cgImage, _, _, _ in
                    defer { group.leave() }
                    guard let cgImage else { return }
                    let image = UIImage(cgImage: cgImage)
                    cache.setObject(image, forKey: NSNumber(value: index))

                    DispatchQueue.main.async { [weak self] in
                        self?.thumbnails[index] = image
                        self?.pendingIndices.remove(index)
                    }
                }
            }

            group.wait()
            DispatchQueue.main.async { [weak self] in
                self?.isGenerating = false
            }
        }
    }

    func cancelAll() {
        imageGenerator.cancelAllCGImageGeneration()
        operationQueue.cancelAllOperations()
        pendingIndices.removeAll()
        isGenerating = false
    }
}
