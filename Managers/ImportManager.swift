import Foundation
import Photos
import AVFoundation
import OSLog

// MARK: - Import Errors
public enum ImportManagerError: Error, LocalizedError {
    case assetNotFound
    case maxRetriesExceeded
    case networkUnavailable
    case insufficientDiskSpace
    case assetCorrupted
    case permissionDenied
    case unknown(Error?)

    public var errorDescription: String? {
        switch self {
        case .assetNotFound:
            return "The requested video asset could not be found in your Photos library."
        case .maxRetriesExceeded:
            return "Unable to download the video from iCloud after multiple attempts. Please check your internet connection and try again."
        case .networkUnavailable:
            return "Network connection is required to download this video from iCloud."
        case .insufficientDiskSpace:
            return "There is not enough available storage space to download this video."
        case .assetCorrupted:
            return "The video file appears to be corrupted or damaged."
        case .permissionDenied:
            return "Permission to access Photos library was denied."
        case .unknown(let error):
            return error?.localizedDescription ?? "An unknown error occurred while importing the video."
        }
    }
}

// MARK: - Import Configuration
public struct ImportConfiguration {
    public let maxRetries: Int
    public let initialDelay: TimeInterval
    public let backoffMultiplier: Double
    public let jitterFactor: Double
    public let timeout: TimeInterval

    public static let `default` = ImportConfiguration(
        maxRetries: 5,
        initialDelay: 1.0,
        backoffMultiplier: 2.0,
        jitterFactor: 0.25,
        timeout: 60.0
    )

    public static let aggressive = ImportConfiguration(
        maxRetries: 3,
        initialDelay: 0.5,
        backoffMultiplier: 1.5,
        jitterFactor: 0.1,
        timeout: 30.0
    )

    public static let conservative = ImportConfiguration(
        maxRetries: 8,
        initialDelay: 2.0,
        backoffMultiplier: 3.0,
        jitterFactor: 0.3,
        timeout: 120.0
    )
}

// MARK: - Import Manager Actor
/// A resilient actor that handles video asset imports with retry logic and exponential backoff
/// Designed to handle network interruptions during iCloud downloads robustly
public actor ImportManager {

    // MARK: - Properties
    private let configuration: ImportConfiguration
    private let imageManager = PHImageManager.default()
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "ImportManager")
    private let diagnosticLogger = DiagnosticLoggingHelper(category: "ImportManager")

    // MARK: - State Management
    private var retryCounts: [String: Int] = [:]
    private var activeImports: Set<String> = []
    private var lastImportAttempt: [String: Date] = [:]

    // MARK: - Initialization
    public init(configuration: ImportConfiguration = .default) {
        self.configuration = configuration
        logger.info("🚀 IMPORT_MANAGER: Initialized with configuration - maxRetries: \(configuration.maxRetries), initialDelay: \(configuration.initialDelay)s")
    }

    // MARK: - Public API

    /// Fetch AVAsset for a PHAsset with resilient retry logic
    /// - Parameter asset: The PHAsset to fetch
    /// - Returns: AVAsset ready for use
    /// - Throws: ImportManagerError if unable to fetch after retries
    public func fetchAVAsset(for asset: PHAsset) async throws -> AVAsset {
        let assetIdentifier = asset.localIdentifier
        let correlationId = "import-\(UUID().uuidString.prefix(8))"

        logger.info("🚀 IMPORT_MANAGER: Starting fetch for asset \(assetIdentifier.prefix(20))... [\(correlationId)]")
        diagnosticLogger.logInfo("Starting resilient AVAsset fetch", metadata: [
            "correlation_id": correlationId,
            "asset_identifier": assetIdentifier,
            "asset_duration": "\(asset.duration)",
            "asset_type": "\(asset.mediaType.rawValue)",
            "max_retries": "\(configuration.maxRetries)"
        ])

        // Check if already importing (prevent duplicate imports)
        if activeImports.contains(assetIdentifier) {
            logger.warning("⚠️ IMPORT_MANAGER: Asset already being imported, waiting [\(correlationId)]")
            // Wait for existing import to complete
            while activeImports.contains(assetIdentifier) {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }

        // Initialize retry count
        retryCounts[assetIdentifier] = 0
        activeImports.insert(assetIdentifier)
        lastImportAttempt[assetIdentifier] = Date()

        defer {
            activeImports.remove(assetIdentifier)
            retryCounts.removeValue(forKey: assetIdentifier)
            lastImportAttempt.removeValue(forKey: assetIdentifier)
        }

        // Retry loop with exponential backoff
        while let attempt = retryCounts[assetIdentifier], attempt < configuration.maxRetries {
            do {
                logger.info("🔄 IMPORT_MANAGER: Attempt \(attempt + 1)/\(self.configuration.maxRetries) for asset \(assetIdentifier.prefix(20))... [\(correlationId)]")

                let avAsset = try await attemptAVAssetFetch(for: asset, correlationId: correlationId)

                // Success!
                logger.info("✅ IMPORT_MANAGER: Successfully fetched AVAsset for \(assetIdentifier.prefix(20))... after \(attempt + 1) attempt(s) [\(correlationId)]")
                diagnosticLogger.logInfo("AVAsset fetch successful", metadata: [
                    "correlation_id": correlationId,
                    "asset_identifier": assetIdentifier,
                    "attempts": "\(attempt + 1)",
                    "total_duration_ms": "0",
                    "asset_duration": "\(try await avAsset.load(.duration).seconds)",
                    "retry_successful": "true"
                ])

                return avAsset

            } catch let error as NSError where isRetryable(error) {
                retryCounts[assetIdentifier, default: 0] += 1
                let currentAttempt = retryCounts[assetIdentifier]!

                logger.warning("⚠️ IMPORT_MANAGER: Attempt \(currentAttempt) failed for asset \(assetIdentifier.prefix(20))... - \(error.localizedDescription) [\(correlationId)]")
                diagnosticLogger.logWarning("AVAsset fetch attempt failed", metadata: [
                    "correlation_id": correlationId,
                    "asset_identifier": assetIdentifier,
                    "attempt": "\(currentAttempt)",
                    "error_code": "\(error.code)",
                    "error_domain": error.domain,
                    "retryable": "true"
                ])

                // Check if we should retry
                if currentAttempt < configuration.maxRetries {
                    let delay = calculateBackoff(for: currentAttempt - 1)
                    logger.info("⏳ IMPORT_MANAGER: Waiting \(String(format: "%.2f", delay))s before retry \(currentAttempt + 1) [\(correlationId)]")
                    diagnosticLogger.logInfo("Scheduling retry with backoff", metadata: [
                        "correlation_id": correlationId,
                        "current_attempt": "\(currentAttempt)",
                        "max_attempts": "\(configuration.maxRetries)",
                        "delay_seconds": "\(String(format: "%.2f", delay))",
                        "backoff_multiplier": "\(configuration.backoffMultiplier)"
                    ])

                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    logger.error("❌ IMPORT_MANAGER: Max retries exceeded for asset \(assetIdentifier.prefix(20))... [\(correlationId)]")
                    diagnosticLogger.logError("Max retries exceeded for AVAsset fetch", metadata: [
                        "correlation_id": correlationId,
                        "asset_identifier": assetIdentifier,
                        "total_attempts": "\(currentAttempt)",
                        "final_error": error.localizedDescription,
                        "user_impact": "Cannot download video from iCloud - check internet connection"
                    ])
                    throw NSError(domain: "ImportManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Max retries exceeded for AVAsset fetch"])
                }

            } catch {
                // Non-retryable error
                logger.error("❌ IMPORT_MANAGER: Non-retryable error for asset \(assetIdentifier.prefix(20))... - \(error.localizedDescription) [\(correlationId)]")
                diagnosticLogger.logError("Non-retryable error in AVAsset fetch", error: error, metadata: [
                    "correlation_id": correlationId,
                    "asset_identifier": assetIdentifier,
                    "error_type": "\(type(of: error))",
                    "user_impact": "Cannot load video - permanent failure"
                ])

                throw error
            }
        }

        // Should not reach here, but just in case
        logger.error("❌ IMPORT_MANAGER: Unexpected exit from retry loop for asset \(assetIdentifier.prefix(20))... [\(correlationId)]")
        throw NSError(domain: "ImportManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unexpected exit from retry loop"])
    }

    // MARK: - Private Methods

    /// Attempt to fetch AVAsset with proper timeout and error handling
    private func attemptAVAssetFetch(for asset: PHAsset, correlationId: String) async throws -> AVAsset {
        diagnosticLogger.startTiming("avasset_fetch_attempt")

        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true // Crucial for iCloud assets
        options.deliveryMode = .highQualityFormat
        options.version = .current

        logger.info("📡 IMPORT_MANAGER: Requesting AVAsset with network access: \(options.isNetworkAccessAllowed) [\(correlationId)]")

        return try await withThrowingTaskGroup(of: AVAsset?.self) { taskGroup in

            // Main fetch task
            taskGroup.addTask {
                try await self.requestAVAssetWithTimeout(for: asset, options: options, correlationId: correlationId)
            }

            // Timeout task
            taskGroup.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.configuration.timeout * 1_000_000_000))
                return nil
            }

            // Wait for first result
            for try await result in taskGroup {
                if let asset = result {
                    taskGroup.cancelAll()
                    diagnosticLogger.stopTiming("avasset_fetch_attempt")
                    return asset
                } else {
                    // Timeout occurred
                    taskGroup.cancelAll()
                    diagnosticLogger.stopTiming("avasset_fetch_attempt")
                    throw NSError(domain: "ImportManager", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "AVAsset fetch timed out after \(configuration.timeout)s"
                    ])
                }
            }

            // Should not reach here
            diagnosticLogger.stopTiming("avasset_fetch_attempt")
            throw NSError(domain: "ImportManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unexpected exit from retry loop"])
        }
    }

    /// Request AVAsset from PHImageManager with proper error handling
    private func requestAVAssetWithTimeout(for asset: PHAsset, options: PHVideoRequestOptions, correlationId: String) async throws -> AVAsset {
        return try await withCheckedThrowingContinuation { continuation in
            let requestStartTime = Date()

            self.logger.info("🎯 IMPORT_MANAGER: Starting PHImageManager.requestAVAsset [\(correlationId)]")

            self.imageManager.requestAVAsset(forVideo: asset, options: options) { [weak self] avAsset, audioMix, info in
                let requestDuration = Date().timeIntervalSince(requestStartTime)
                Task { [weak self] in
                    await self?.handleAVAssetResponse(
                        avAsset: avAsset,
                        audioMix: audioMix,
                        info: info,
                        requestDuration: requestDuration,
                        continuation: continuation,
                        correlationId: correlationId
                    )
                }
            }
        }
    }

    /// Handle the response from PHImageManager
    private func handleAVAssetResponse(
        avAsset: AVAsset?,
        audioMix: AVAudioMix?,
        info: [AnyHashable: Any]?,
        requestDuration: TimeInterval,
        continuation: CheckedContinuation<AVAsset, Error>,
        correlationId: String
    ) {
        logger.info("📡 IMPORT_MANAGER: PHImageManager response received in \(String(format: "%.2f", requestDuration))s [\(correlationId)]")

        if let error = info?[PHImageErrorKey] as? Error {
            logger.error("❌ IMPORT_MANAGER: PHImageManager error: \(error.localizedDescription) [\(correlationId)]")
            continuation.resume(throwing: error)
        } else if let asset = avAsset {
            logger.info("✅ IMPORT_MANAGER: PHImageManager returned valid AVAsset [\(correlationId)]")
            Task {
                do {
                    let assetDuration = try await asset.load(.duration).seconds
                    let trackCount = try await asset.load(.tracks).count

                    diagnosticLogger.logInfo("AVAsset fetch successful", metadata: [
                        "correlation_id": correlationId,
                        "request_duration_ms": "\(String(format: "%.1f", requestDuration * 1000))",
                        "asset_duration": "\(assetDuration)",
                        "asset_tracks": "\(trackCount)"
                    ])
                } catch {
                    logger.warning("⚠️ IMPORT_MANAGER: Failed to load asset metadata: \(error) [\(correlationId)]")
                }
            }
            continuation.resume(returning: asset)
        } else {
            let error = NSError(domain: "ImportManager", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "PHImageManager returned nil asset and nil error"
            ])
            logger.error("❌ IMPORT_MANAGER: PHImageManager returned nil asset [\(correlationId)]")
            continuation.resume(throwing: error)
        }
    }

    /// Determine if an error is retryable
    private func isRetryable(_ error: NSError) -> Bool {
        // Network-related errors that should be retried
        let retryableErrorCodes: [Int] = [
            NSURLErrorTimedOut,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorInternationalRoamingOff,
            NSURLErrorCallIsActive,
            NSURLErrorDataNotAllowed,
            NSURLErrorRequestBodyStreamExhausted,
            NSURLErrorBadServerResponse,
            NSURLErrorCannotFindHost,
            NSURLErrorCannotConnectToHost,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorDNSLookupFailed,
            NSURLErrorHTTPTooManyRedirects,
            NSURLErrorResourceUnavailable,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorRedirectToNonExistentLocation,
            NSURLErrorBadServerResponse,
            NSURLErrorUserCancelledAuthentication,
            NSURLErrorUserAuthenticationRequired,
            NSURLErrorZeroByteResource,
            NSURLErrorCannotDecodeRawData,
            NSURLErrorCannotDecodeContentData,
            NSURLErrorCannotParseResponse,
            NSURLErrorFileDoesNotExist,
            NSURLErrorFileIsDirectory,
            NSURLErrorNoPermissionsToReadFile,
            NSURLErrorDataLengthExceedsMaximum
        ]

        // Photos-specific errors that might be retryable
        let retryableDomains: [String] = [
            "NSCocoaErrorDomain",
            "PhotosErrorDomain"
        ]

        return retryableErrorCodes.contains(error.code) ||
               retryableDomains.contains(error.domain) ||
               error.localizedDescription.contains("network") ||
               error.localizedDescription.contains("connection") ||
               error.localizedDescription.contains("timeout") ||
               error.localizedDescription.contains("iCloud") ||
               error.localizedDescription.contains("download")
    }

    /// Calculate exponential backoff delay with jitter
    private func calculateBackoff(for attempt: Int) -> TimeInterval {
        let baseDelay = configuration.initialDelay * pow(configuration.backoffMultiplier, Double(attempt))
        let jitterRange = baseDelay * configuration.jitterFactor
        let jitter = Double.random(in: -jitterRange...jitterRange)
        let finalDelay = baseDelay + jitter

        // Cap at reasonable maximum
        return min(finalDelay, 60.0)
    }

    // MARK: - Public Utilities

    /// Get current import status
    public func getImportStatus() -> (active: Int, pending: Int, failed: Int) {
        let activeCount = activeImports.count
        let pendingCount = retryCounts.filter { $0.value < configuration.maxRetries }.count
        let failedCount = retryCounts.filter { $0.value >= configuration.maxRetries }.count

        return (activeCount, pendingCount, failedCount)
    }

    /// Cancel all active imports
    public func cancelAllImports() {
        logger.info("🚫 IMPORT_MANAGER: Cancelling all active imports")
        activeImports.removeAll()
        retryCounts.removeAll()
        lastImportAttempt.removeAll()
    }

    /// Check if an asset is currently being imported
    public func isAssetImporting(_ assetIdentifier: String) -> Bool {
        return activeImports.contains(assetIdentifier)
    }
}

// MARK: - Preview Helper
extension ImportManager {
    /// Import multiple assets with concurrent processing
    public func fetchMultipleAssets(_ assets: [PHAsset]) async throws -> [AVAsset] {
        logger.info("📦 IMPORT_MANAGER: Starting batch import of \(assets.count) assets")

        let results = try await withThrowingTaskGroup(of: (String, AVAsset).self) { group in
            for asset in assets {
                group.addTask {
                    let avAsset = try await self.fetchAVAsset(for: asset)
                    return (asset.localIdentifier, avAsset)
                }
            }

            var fetchedAssets: [String: AVAsset] = [:]
            for try await (identifier, asset) in group {
                fetchedAssets[identifier] = asset
            }

            // Return in original order
            return assets.compactMap { fetchedAssets[$0.localIdentifier] }
        }

        logger.info("✅ IMPORT_MANAGER: Batch import completed successfully")
        return results
    }
}