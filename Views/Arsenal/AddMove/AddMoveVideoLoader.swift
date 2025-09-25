import Foundation
import AVFoundation
import Photos
import PhotosUI
import UniformTypeIdentifiers
import SwiftUI
import OSLog
import CoreMedia

// Use the native PhotosUI PhotosPickerItem type

// MARK: - Video Loading Errors
public enum AddMoveVideoLoaderError: Error, LocalizedError {
    case itemIdentifierMissing
    case assetNotFound
    case avAssetCreationFailed
    case unsupportedFileType
    case dataUnavailable
    case temporaryFileError(Error)

    public var errorDescription: String? {
        switch self {
        case .itemIdentifierMissing:
            return "The selected item does not have a valid identifier."
        case .assetNotFound:
            return "Could not find the video in the Photos library."
        case .avAssetCreationFailed:
            return "Failed to create a playable video asset."
        case .unsupportedFileType:
            return "The selected file type is not a supported video format."
        case .dataUnavailable:
            return "Could not retrieve video data for the selected item."
        case .temporaryFileError(let underlyingError):
            return "Failed to save video data to a temporary file: \(underlyingError.localizedDescription)"
        }
    }
}

// MARK: - Video Loader Result
public struct AddMoveVideoLoaderResult {
    let asset: AVAsset
    let photosIdentifier: String
    let filename: String
    let temporaryFileURL: URL?
}

// MARK: - VideoLoader Actor
public actor AddMoveVideoLoader {
    private let imageManager = PHImageManager.default()
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "VideoLoader")
    private var diagnosticLogger: DiagnosticLoggingHelper!
    // private let enhancedVideoLogger: EnhancedVideoLogger - will be added back when file is properly included in build
    private let memoryLogger = CentralizedMemoryLogger.shared

    // MARK: - Performance Tracking
    private var operationTimings: [String: TimeInterval] = [:]
    private var currentCorrelationId: String?

    // MARK: - Initialization
    public init() {
        // Initialize diagnostic logger with async initialization
        self.diagnosticLogger = nil
        logger.info("🎬 VIDEO_LOADER: 🚀 Initialized - diagnostic logger will be initialized on first operation")
    }

    // MARK: - Lazy Initialization
    private func ensureDiagnosticLogger() async {
        if diagnosticLogger == nil {
            do {
                diagnosticLogger = DiagnosticLoggingHelper(
                    category: "AddMoveVideoLoader",
                    enablePerformanceTracking: false,  // Disable to avoid main actor issues
                    enableResourceMonitoring: false,    // Disable to avoid main actor issues
                    enableDetailedContext: false         // Disable to avoid main actor issues
                )
                logger.info("🎬 VIDEO_LOADER: 🛠️ Diagnostic logger initialized on demand")
            } catch {
                logger.error("🎬 VIDEO_LOADER: ❌ Failed to initialize diagnostic logger: \(error)")
                // Create a minimal fallback logger
                diagnosticLogger = DiagnosticLoggingHelper(
                    category: "AddMoveVideoLoader-Fallback",
                    enablePerformanceTracking: false,
                    enableResourceMonitoring: false,
                    enableDetailedContext: false
                )
            }
        }
    }

    public func loadVideo(from item: PhotosPickerItem) async throws -> AddMoveVideoLoaderResult {
        // Ensure diagnostic logger is initialized
        await ensureDiagnosticLogger()

        // Generate correlation ID for this operation
        currentCorrelationId = memoryLogger.generateCorrelationId(for: "loadVideo")
        let correlationId = currentCorrelationId!

        logger.info("🎬 VIDEO_LOADER: 🚀 loadVideo called [\(correlationId)]")
        await diagnosticLogger.startTiming("total_video_loading")

        // Extract information from the custom PhotosPickerItem wrapper
        let identifier = extractItemIdentifier(from: item)
        let supportedContentTypes = extractSupportedContentTypes(from: item)

        await diagnosticLogger.logInfo("Starting video loading operation", metadata: [
            "correlation_id": correlationId,
            "item_identifier": identifier ?? "nil",
            "supported_content_types": supportedContentTypes,
            "thread": "Main"
        ])

        // Log initial memory state
        memoryLogger.logMemoryState(context: "Before Video Loading", correlationId: correlationId, component: "AddMoveVideoLoader")

        let result: AddMoveVideoLoaderResult

        if let identifier = identifier {
            logger.info("🎬 VIDEO_LOADER: Loading from Photos library [\(correlationId)]")
            await diagnosticLogger.logInfo("Using Photos library loading path", metadata: [
                "correlation_id": correlationId,
                "identifier": identifier,
                "loading_path": "photos_library"
            ])
            result = try await loadFromPhotos(identifier: identifier)
        } else {
            logger.info("🎬 VIDEO_LOADER: Loading directly from PhotosPicker [\(correlationId)]")
            await diagnosticLogger.logInfo("Using direct loading path", metadata: [
                "correlation_id": correlationId,
                "loading_path": "direct_transfer"
            ])
            result = try await loadDirectly(from: item)
        }

        await diagnosticLogger.stopTiming("total_video_loading")
        memoryLogger.logMemoryState(context: "After Video Loading", correlationId: correlationId, component: "AddMoveVideoLoader")

        await diagnosticLogger.logInfo("Video loading completed successfully", metadata: [
            "correlation_id": correlationId,
            "total_duration_ms": "\(String(format: "%.1f", (operationTimings["total_video_loading"] ?? 0) * 1000))",
            "result_filename": result.filename,
            "result_photos_id": result.photosIdentifier,
            "asset_duration": "\(result.asset.duration.seconds)"
        ])

        // Clean up correlation ID
        memoryLogger.clearCorrelationId(for: "loadVideo")
        currentCorrelationId = nil

        return result
    }

    // MARK: - Private Loading Methods

    /// Extract item identifier from PhotosPickerItem
    private func extractItemIdentifier(from item: PhotosPickerItem) -> String? {
        // For iOS 18 PhotosPickerItem, we need to load the asset to get the identifier
        // This will be handled in the loading process
        return nil
    }

    /// Extract supported content types from PhotosPickerItem
    private func extractSupportedContentTypes(from item: PhotosPickerItem) -> String {
        // For native PhotosPickerItem, we can't access supportedContentTypes directly
        // We'll check this during the loading process instead
        return "video"
    }

    private func loadFromPhotos(identifier: String) async throws -> AddMoveVideoLoaderResult {
        let correlationId = currentCorrelationId ?? "unknown"

        logger.info("🎬 VIDEO_LOADER: 🚀 loadFromPhotos called with identifier: \(identifier) [\(correlationId)]")
        await diagnosticLogger.startTiming("photos_loading")

        await diagnosticLogger.logInfo("Starting Photos library loading", metadata: [
            "correlation_id": correlationId,
            "identifier": identifier,
            "loading_method": "photos_library"
        ])

        memoryLogger.logMemoryState(context: "Before Photos Loading", correlationId: correlationId, component: "AddMoveVideoLoader")

        logger.info("🎬 VIDEO_LOADER: Fetching PHAsset from Photos library [\(correlationId)]")
        await diagnosticLogger.startTiming("asset_fetch")

        let fetchStartTime = Date()
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        let fetchDuration = Date().timeIntervalSince(fetchStartTime)
        operationTimings["asset_fetch"] = fetchDuration

        logger.info("🎬 VIDEO_LOADER: Fetch result count: \(fetchResult.count) [\(correlationId)]")
        await diagnosticLogger.logInfo("PHAsset fetch completed", metadata: [
            "correlation_id": correlationId,
            "fetch_duration_ms": "\(String(format: "%.1f", fetchDuration * 1000))",
            "result_count": "\(fetchResult.count)"
        ])

        guard let phAsset = fetchResult.firstObject else {
            let error = AddMoveVideoLoaderError.assetNotFound
            logger.error("🎬 VIDEO_LOADER: ❌ PHAsset not found for identifier: \(identifier) [\(correlationId)]")
            // enhancedVideoLogger.log - temporarily disabled until file is properly included in buildAssetLoadingFailure(correlationID: correlationId, error: error, context: "Asset not found in Photos library")

            await diagnosticLogger.logError("PHAsset not found", metadata: [
                "correlation_id": correlationId,
                "identifier": identifier,
                "user_impact": "Cannot load video - asset not accessible"
            ])

            throw error
        }

        logger.info("🎬 VIDEO_LOADER: ✅ PHAsset found [\(correlationId)]")
        await diagnosticLogger.logInfo("PHAsset found and validated", metadata: [
            "correlation_id": correlationId,
            "asset_media_type": "\(phAsset.mediaType.rawValue)",
            "asset_duration": "\(phAsset.duration)",
            "asset_creation_date": "\(phAsset.creationDate ?? Date())"
        ])

        // Log detailed asset information
        await diagnosticLogger.startTiming("asset_metadata")
        let assetInfo: [String: Any] = [
            "mediaType": phAsset.mediaType.rawValue,
            "duration": phAsset.duration,
            "pixelWidth": phAsset.pixelWidth,
            "pixelHeight": phAsset.pixelHeight,
            "creationDate": phAsset.creationDate ?? Date(),
            "modificationDate": phAsset.modificationDate ?? Date(),
            "isFavorite": phAsset.isFavorite,
            "isHidden": phAsset.isHidden
        ]
        await diagnosticLogger.stopTiming("asset_metadata")

        // enhancedVideoLogger.log - temporarily disabled until file is properly included in buildAssetLoadingStart(correlationID: correlationId, assetInfo: assetInfo)

        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        logger.info("🎬 VIDEO_LOADER: Requesting AVAsset with high quality options [\(correlationId)]")
        await diagnosticLogger.logInfo("Configuring PHVideoRequestOptions", metadata: [
            "correlation_id": correlationId,
            "network_access": "\(options.isNetworkAccessAllowed)",
            "delivery_mode": "\(options.deliveryMode.rawValue)",
            "version": "\(options.version.rawValue)"
        ])

        memoryLogger.logMemoryState(context: "Before AVAsset Request", correlationId: correlationId, component: "AddMoveVideoLoader")

        await diagnosticLogger.startTiming("avasset_request")
        let avAsset = try await requestAVAsset(for: phAsset, options: options)
        await diagnosticLogger.stopTiming("avasset_request")

        logger.info("🎬 VIDEO_LOADER: ✅ AVAsset received successfully [\(correlationId)]")
        // AssetLoadingSuccess(correlationID: correlationId, asset: avAsset, loadTime: operationTimings["avasset_request"] ?? 0)

        await diagnosticLogger.startTiming("filename_fetch")
        let filename = await fetchFilename(for: phAsset)
        await diagnosticLogger.stopTiming("filename_fetch")

        logger.info("🎬 VIDEO_LOADER: ✅ Filename fetched: \(filename) [\(correlationId)]")

        memoryLogger.logMemoryState(context: "After AVAsset Loaded", correlationId: correlationId, component: "AddMoveVideoLoader")

        await diagnosticLogger.stopTiming("photos_loading")

        logger.info("🎬 VIDEO_LOADER: 🏆 Returning VideoLoaderResult from Photos [\(correlationId)]")
        await diagnosticLogger.logInfo("Photos library loading completed", metadata: [
            "correlation_id": correlationId,
            "total_duration_ms": "\(String(format: "%.1f", (operationTimings["photos_loading"] ?? 0) * 1000))",
            "fetch_duration_ms": "\(String(format: "%.1f", fetchDuration * 1000))",
            "asset_request_ms": "\(String(format: "%.1f", (operationTimings["avasset_request"] ?? 0) * 1000))",
            "filename_fetch_ms": "\(String(format: "%.1f", (operationTimings["filename_fetch"] ?? 0) * 1000))",
            "result_filename": filename,
            "asset_duration": "\(avAsset.duration.seconds)",
            "asset_tracks": "\(avAsset.tracks.count)"
        ])

        return AddMoveVideoLoaderResult(asset: avAsset, photosIdentifier: identifier, filename: filename, temporaryFileURL: nil)
    }

    private func loadDirectly(from item: PhotosPickerItem) async throws -> AddMoveVideoLoaderResult {
        logger.info("🎬 VIDEO_LOADER: loadDirectly called")
        logger.info("🎬 VIDEO_LOADER: Checking content types for movie support")

        // For iOS 18 PhotosPickerItem, we need to check if it can load movie data
        // We'll try to load the data and see if it succeeds

        logger.info("🎬 VIDEO_LOADER: Loading transferable data from PhotosPickerItem")
        guard let data = try await item.loadTransferable(type: Data.self) else {
            logger.error("🎬 VIDEO_LOADER: Failed to load transferable data")
            throw AddMoveVideoLoaderError.dataUnavailable
        }

        logger.info("🎬 VIDEO_LOADER: Data loaded successfully, size: \(data.count) bytes")

        // Validate that the data is actually a video by creating an AVAsset
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        logger.info("🎬 VIDEO_LOADER: Created temp URL: \(tempURL.absoluteString)")

        do {
            logger.info("🎬 VIDEO_LOADER: Writing data to temp file")
            try data.write(to: tempURL)
            logger.info("🎬 VIDEO_LOADER: Data written to temp file successfully")
        } catch {
            logger.error("🎬 VIDEO_LOADER: Failed to write data to temp file: \(error.localizedDescription)")
            throw AddMoveVideoLoaderError.temporaryFileError(error)
        }

        // Validate that this is actually a video file
        let avAsset = AVURLAsset(url: tempURL)
        let assetDuration = try await avAsset.load(.duration)

        guard assetDuration.seconds > 0 else {
            logger.error("🎬 VIDEO_LOADER: Invalid video duration: \(assetDuration.seconds)")
            throw AddMoveVideoLoaderError.unsupportedFileType
        }

        logger.info("🎬 VIDEO_LOADER: Valid video asset created with duration: \(assetDuration.seconds) seconds")

        let filename = "video-\(Date().timeIntervalSince1970).mov"
        let tempIdentifier = "temp-\(UUID().uuidString)"

        logger.info("🎬 VIDEO_LOADER: Generated filename: \(filename)")
        logger.info("🎬 VIDEO_LOADER: Generated temp identifier: \(tempIdentifier)")
        logger.info("🎬 VIDEO_LOADER: Returning VideoLoaderResult from direct load")

        return AddMoveVideoLoaderResult(asset: avAsset, photosIdentifier: tempIdentifier, filename: filename, temporaryFileURL: tempURL)
    }

    // MARK: - Helper Methods

    private func requestAVAsset(for phAsset: PHAsset, options: PHVideoRequestOptions) async throws -> AVAsset {
        let correlationId = currentCorrelationId ?? "unknown"

        logger.info("🎬 VIDEO_LOADER: 🚀 requestAVAsset called [\(correlationId)]")
        await diagnosticLogger.startTiming("ph_image_manager_request")

        await diagnosticLogger.logInfo("Starting PHImageManager AVAsset request", metadata: [
            "correlation_id": correlationId,
            "asset_local_identifier": phAsset.localIdentifier,
            "network_access": "\(options.isNetworkAccessAllowed)",
            "delivery_mode": "\(options.deliveryMode.rawValue)",
            "version": "\(options.version.rawValue)",
            "network_access_allowed": "\(options.isNetworkAccessAllowed)"
        ])

        memoryLogger.logMemoryState(context: "Before PHImageManager Request", correlationId: correlationId, component: "AddMoveVideoLoader")

        let requestStartTime = Date()

        return try await withCheckedThrowingContinuation { continuation in
            self.logger.info("🎬 VIDEO_LOADER: 🔄 Starting PHImageManager.requestAVAsset [\(correlationId)]")
            Task {
                await self.diagnosticLogger.logInfo("PHImageManager request initiated", metadata: [
                    "correlation_id": correlationId,
                    "ph_asset": phAsset.localIdentifier
                ])
            }

            self.imageManager.requestAVAsset(forVideo: phAsset, options: options) { avAsset, audioMix, info in
                let requestDuration = Date().timeIntervalSince(requestStartTime)
                Task {
                    await self.diagnosticLogger.stopTiming("ph_image_manager_request")
                }

                self.logger.info("🎬 VIDEO_LOADER: 📡 PHImageManager request completed [\(correlationId)]")

                // Log detailed response information
                let responseInfo: [String: Any] = [
                    "request_duration": requestDuration,
                    "has_avAsset": avAsset != nil,
                    "has_audioMix": audioMix != nil,
                    "has_info": info != nil,
                    "info_keys": info?.keys ?? [],
                    "request_timestamp": Date().timeIntervalSince1970
                ]

                if let error = info?[PHImageErrorKey] as? Error {
                    self.logger.error("🎬 VIDEO_LOADER: ❌ PHImageManager error: \(error.localizedDescription) [\(correlationId)]")
                    // enhancedVideoLogger.log - temporarily disabled until file is properly included in buildAssetLoadingFailure(correlationID: correlationId, error: error, context: "PHImageManager request failed")

                    Task {
                        await self.diagnosticLogger.logError("PHImageManager request failed", error: error, metadata: [
                            "correlation_id": correlationId,
                            "request_duration_ms": "\(String(format: "%.1f", requestDuration * 1000))",
                            "error_domain": (error as NSError).domain,
                            "error_code": "\((error as NSError).code)",
                            "user_impact": "Cannot load video from Photos library",
                            "info_dictionary": "\(info ?? [:])"
                        ])
                    }

                    continuation.resume(throwing: error)
                } else if let asset = avAsset {
                    self.logger.info("🎬 VIDEO_LOADER: ✅ AVAsset received successfully [\(correlationId)]")
                    Task {
                        await self.diagnosticLogger.logInfo("AVAsset received successfully", metadata: [
                            "correlation_id": correlationId,
                            "request_duration_ms": "\(String(format: "%.1f", requestDuration * 1000))",
                            "asset_type": "\(type(of: asset))",
                            "asset_duration": "\(asset.duration.seconds)",
                            "asset_tracks": "\(asset.tracks.count)"
                        ])
                    }

                    // Log detailed asset information
                    if let urlAsset = asset as? AVURLAsset {
                        self.logger.info("🎬 VIDEO_LOADER: 📍 Asset URL: \(urlAsset.url.absoluteString) [\(correlationId)]")
                        Task {
                            await self.diagnosticLogger.logInfo("AVURLAsset details", metadata: [
                                "correlation_id": correlationId,
                                "asset_url": urlAsset.url.absoluteString,
                                "file_size": "0",
                                "url_scheme": urlAsset.url.scheme ?? "unknown"
                            ])
                        }
                    }

                    // Log track information
                    let tracks = asset.tracks
                    var trackInfo: [[String: Any]] = []
                    for (index, track) in tracks.enumerated() {
                        var info: [String: Any] = [
                            "index": index,
                            "mediaType": track.mediaType.rawValue,
                            "enabled": track.isEnabled,
                            "timeRange": "\(track.timeRange.start.seconds)-\(track.timeRange.duration.seconds)"
                        ]

                        if track.mediaType == .video {
                            info["naturalSize"] = "\(Int(track.naturalSize.width))x\(Int(track.naturalSize.height))"
                            info["nominalFrameRate"] = track.nominalFrameRate ?? 0
                            info["preferredVolume"] = track.preferredVolume
                        }

                        if track.mediaType == .audio {
                            info["preferredVolume"] = track.preferredVolume
                            if let formatDescs = track.formatDescriptions as? [Any],
                               let firstDesc = formatDescs.first {
                                let audioFormat = CMAudioFormatDescriptionGetStreamBasicDescription(firstDesc as! CMAudioFormatDescription)
                                if let basicDescription = audioFormat?.pointee {
                                    info["sampleRate"] = basicDescription.mSampleRate
                                    info["channels"] = basicDescription.mChannelsPerFrame
                                }
                            }
                        }

                        trackInfo.append(info)
                    }

                    Task {
                        await self.diagnosticLogger.logInfo("Asset track analysis", metadata: [
                            "correlation_id": correlationId,
                            "total_tracks": "\(tracks.count)",
                            "track_info": "\(trackInfo)"
                        ])
                    }

                    continuation.resume(returning: asset)
                } else {
                    let error = AddMoveVideoLoaderError.avAssetCreationFailed
                    self.logger.error("🎬 VIDEO_LOADER: ❌ No AVAsset or error received from PHImageManager [\(correlationId)]")
                    // enhancedVideoLogger.log - temporarily disabled until file is properly included in buildAssetLoadingFailure(correlationID: correlationId, error: error, context: "PHImageManager returned nil asset")

                    Task {
                        await self.diagnosticLogger.logError("PHImageManager returned nil asset", metadata: [
                            "correlation_id": correlationId,
                            "request_duration_ms": "\(String(format: "%.1f", requestDuration * 1000))",
                            "has_info": "\(info != nil)",
                            "info_keys": "\(info?.keys.map { "\($0)" }.joined(separator: ", ") ?? "[]")",
                            "user_impact": "Cannot load video - asset creation failed"
                        ])
                    }

                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func fetchFilename(for phAsset: PHAsset) async -> String {
        let correlationId = currentCorrelationId ?? "unknown"

        logger.info("🎬 VIDEO_LOADER: 🚀 fetchFilename called [\(correlationId)]")
        await diagnosticLogger.startTiming("filename_fetch")

        await diagnosticLogger.logInfo("Starting filename fetch", metadata: [
            "correlation_id": correlationId,
            "ph_asset": phAsset.localIdentifier
        ])

        let resources = PHAssetResource.assetResources(for: phAsset)
        await diagnosticLogger.logInfo("PHAssetResource fetch completed", metadata: [
            "correlation_id": correlationId,
            "resources_count": "\(resources.count)",
            "resource_types": "\(resources.map { $0.type.rawValue })"
        ])

        logger.info("🎬 VIDEO_LOADER: 📋 Found \(resources.count) asset resources [\(correlationId)]")

        if let resource = resources.first(where: { $0.type == .video }) {
            logger.info("🎬 VIDEO_LOADER: ✅ Video resource found: \(resource.originalFilename) [\(correlationId)]")
            await diagnosticLogger.logInfo("Video resource found", metadata: [
                "correlation_id": correlationId,
                "filename": resource.originalFilename,
                "resource_type": "\(resource.type.rawValue)",
                "file_size": "0",
                "uniform_type_identifier": resource.uniformTypeIdentifier,
                "is_cloud_asset": "false"
            ])

            await diagnosticLogger.stopTiming("filename_fetch")
            return resource.originalFilename
        }

        // Fallback: look for any resource that might contain video data
        for resource in resources {
            if resource.uniformTypeIdentifier.contains("video") || resource.uniformTypeIdentifier.contains("quicktime") {
                logger.info("🎬 VIDEO_LOADER: 🔄 Found video-compatible resource: \(resource.originalFilename) [\(correlationId)]")
                await diagnosticLogger.logInfo("Video-compatible resource found as fallback", metadata: [
                    "correlation_id": correlationId,
                    "filename": resource.originalFilename,
                    "resource_type": "\(resource.type.rawValue)",
                    "uniform_type_identifier": resource.uniformTypeIdentifier
                ])

                await diagnosticLogger.stopTiming("filename_fetch")
                return resource.originalFilename
            }
        }

        logger.warning("🎬 VIDEO_LOADER: ⚠️ No video resource found, using default filename [\(correlationId)]")
        await diagnosticLogger.logWarning("No video resource found", metadata: [
            "correlation_id": correlationId,
            "available_resource_types": "\(resources.map { $0.type.rawValue })",
            "fallback_used": "true",
            "default_filename": "Video"
        ])

        await diagnosticLogger.stopTiming("filename_fetch")
        return "Video"
    }
}
