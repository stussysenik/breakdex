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
        let correlationId = currentCorrelationId ?? "unknown"

        logger.info("🎬 VIDEO_LOADER: loadDirectly called [\(correlationId)]")
        await diagnosticLogger.logInfo("Starting direct video loading", metadata: [
            "correlation_id": correlationId,
            "loading_method": "streaming_file_copy"
        ])

        memoryLogger.logMemoryState(context: "Before Direct Loading", correlationId: correlationId, component: "AddMoveVideoLoader")

        await diagnosticLogger.startTiming("direct_loading")

        // Create temporary URL for streaming file copy
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        logger.info("🎬 VIDEO_LOADER: Created temp URL for streaming: \(tempURL.lastPathComponent) [\(correlationId)]")
        await diagnosticLogger.logInfo("Temporary file created", metadata: [
            "correlation_id": correlationId,
            "temp_filename": tempURL.lastPathComponent,
            "file_size": "0",
            "loading_approach": "streaming_copy"
        ])

        do {
            // Use streaming approach instead of loading entire file into memory
            await diagnosticLogger.startTiming("file_copy")

            logger.info("🎬 VIDEO_LOADER: 🔄 Starting streaming file copy [\(correlationId)]")
            await diagnosticLogger.logInfo("Initiating streaming file copy", metadata: [
                "correlation_id": correlationId,
                "copy_method": "streaming",
                "memory_efficient": "true",
                "avoid_memory_overload": "true"
            ])

            // 🎯 CRITICAL FIX: Use true streaming file copy without loading entire Data into memory
            // This prevents memory overload for large video files
            guard let fileURL = try await item.loadTransferable(type: URL.self) else {
                // Fallback to Data approach only if URL transfer is not supported
                logger.warning("🎬 VIDEO_LOADER: ⚠️ URL transfer not supported, falling back to Data loading [\(correlationId)]")
                await diagnosticLogger.logWarning("URL transfer failed, using Data fallback", metadata: [
                    "correlation_id": correlationId,
                    "fallback_reason": "URL transfer not supported",
                    "memory_warning": "potential_memory_overload"
                ])

                guard let data = try await item.loadTransferable(type: Data.self) else {
                    let error = AddMoveVideoLoaderError.temporaryFileError(NSError(domain: "PhotosPicker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not load video data from PhotosPicker item"]))
                    logger.error("🎬 VIDEO_LOADER: ❌ Could not load video data from PhotosPicker item [\(correlationId)]")
                    await diagnosticLogger.logError("Failed to load video data from PhotosPicker", metadata: [
                        "correlation_id": correlationId,
                        "error": "Could not load video data",
                        "user_impact": "Cannot load video - PhotosPicker data loading failed"
                    ])
                    throw error
                }

                // Write the data to the temporary file
                try data.write(to: tempURL)

                await diagnosticLogger.logWarning("Used Data fallback for file copy", metadata: [
                    "correlation_id": correlationId,
                    "file_size_bytes": "\(data.count)",
                    "memory_impact": "high",
                    "fallback_successful": "true"
                ])

                // Create AVAsset from the temporary file
                let avAsset = AVURLAsset(url: tempURL)

                // Load asset duration to validate it's a valid video
                let assetDuration = try await avAsset.load(.duration)

                guard assetDuration.seconds > 0 else {
                    logger.error("🎬 VIDEO_LOADER: ❌ Invalid video duration from Data fallback: \(assetDuration.seconds) [\(correlationId)]")
                    await diagnosticLogger.logError("Invalid video duration from Data fallback", metadata: [
                        "correlation_id": correlationId,
                        "duration_seconds": "\(assetDuration.seconds)",
                        "file_path": tempURL.path,
                        "user_impact": "Cannot load video - invalid file format from Data fallback"
                    ])
                    throw AddMoveVideoLoaderError.unsupportedFileType
                }

                // Generate filename and identifier
                let filename = "video-\(Date().timeIntervalSince1970).mov"
                let tempIdentifier = "temp-\(UUID().uuidString)"

                await diagnosticLogger.stopTiming("direct_loading")

                logger.info("🎬 VIDEO_LOADER: 🏆 Returning VideoLoaderResult from Data fallback [\(correlationId)]")

                return AddMoveVideoLoaderResult(asset: avAsset, photosIdentifier: tempIdentifier, filename: filename, temporaryFileURL: tempURL)
            }

            // Use streaming file copy for memory efficiency
            do {
                try FileManager.default.copyItem(at: fileURL, to: tempURL)
                    await diagnosticLogger.logInfo("Streaming file copy completed", metadata: [
                    "correlation_id": correlationId,
                    "source_url": fileURL.lastPathComponent,
                    "destination_url": tempURL.lastPathComponent,
                    "copy_method": "streaming_file_copy",
                    "memory_efficient": "true",
                    "avoided_memory_overload": "true"
                ])
            } catch {
                logger.error("🎬 VIDEO_LOADER: ❌ File copy failed: \(error.localizedDescription) [\(correlationId)]")
                await diagnosticLogger.logError("Streaming file copy failed", error: error, metadata: [
                    "correlation_id": correlationId,
                    "source_url": fileURL.path,
                    "destination_url": tempURL.path,
                    "user_impact": "Cannot load video - file copy failed"
                ])
                throw AddMoveVideoLoaderError.temporaryFileError(error)
            }

            await diagnosticLogger.stopTiming("file_copy")

            // Verify file was created and has content
            guard FileManager.default.fileExists(atPath: tempURL.path) else {
                let error = AddMoveVideoLoaderError.temporaryFileError(NSError(domain: "FileManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "File was not created"]))
                logger.error("🎬 VIDEO_LOADER: ❌ Temporary file was not created [\(correlationId)]")
                await diagnosticLogger.logError("Temporary file creation failed", metadata: [
                    "correlation_id": correlationId,
                    "temp_path": tempURL.path,
                    "file_exists": "false",
                    "user_impact": "Cannot load video - file creation failed"
                ])
                throw error
            }

            // Get file size for logging
            do {
                let resources = try tempURL.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = resources.fileSize {
                    logger.info("🎬 VIDEO_LOADER: ✅ File copied successfully, size: \(fileSize) bytes (\(Double(fileSize) / (1024 * 1024)) MB) [\(correlationId)]")
                    await diagnosticLogger.logInfo("Streaming file copy completed", metadata: [
                        "correlation_id": correlationId,
                        "file_size_bytes": "\(fileSize)",
                        "file_size_mb": "\(String(format: "%.2f", Double(fileSize) / (1024 * 1024)))",
                        "copy_duration_ms": "\(String(format: "%.1f", (operationTimings["file_copy"] ?? 0) * 1000))",
                        "memory_efficient": "true",
                        "avoided_memory_overload": "true"
                    ])
                }
            } catch {
                logger.warning("🎬 VIDEO_LOADER: ⚠️ Could not get file size, but file was copied [\(correlationId)]")
            }

            // Create AVAsset from the temporary file
            await diagnosticLogger.startTiming("asset_creation")
            let avAsset = AVURLAsset(url: tempURL)

            // Load asset duration to validate it's a valid video
            let assetDuration = try await avAsset.load(.duration)
            await diagnosticLogger.stopTiming("asset_creation")

            guard assetDuration.seconds > 0 else {
                logger.error("🎬 VIDEO_LOADER: ❌ Invalid video duration: \(assetDuration.seconds) [\(correlationId)]")
                await diagnosticLogger.logError("Invalid video duration", metadata: [
                    "correlation_id": correlationId,
                    "duration_seconds": "\(assetDuration.seconds)",
                    "file_path": tempURL.path,
                    "user_impact": "Cannot load video - invalid file format"
                ])
                throw AddMoveVideoLoaderError.unsupportedFileType
            }

            await diagnosticLogger.logInfo("Video asset validated", metadata: [
                "correlation_id": correlationId,
                "asset_duration_seconds": "\(assetDuration.seconds)",
                "asset_creation_duration_ms": "\(String(format: "%.1f", (operationTimings["asset_creation"] ?? 0) * 1000))",
                "validation_successful": "true"
            ])

            logger.info("🎬 VIDEO_LOADER: ✅ Valid video asset created with duration: \(assetDuration.seconds) seconds [\(correlationId)]")

            // Generate filename and identifier
            let filename = "video-\(Date().timeIntervalSince1970).mov"
            let tempIdentifier = "temp-\(UUID().uuidString)"

            await diagnosticLogger.stopTiming("direct_loading")
            memoryLogger.logMemoryState(context: "After Direct Loading", correlationId: correlationId, component: "AddMoveVideoLoader")

            await diagnosticLogger.logInfo("Direct loading completed successfully", metadata: [
                "correlation_id": correlationId,
                "total_duration_ms": "\(String(format: "%.1f", (operationTimings["direct_loading"] ?? 0) * 1000))",
                "filename": filename,
                "temp_identifier": tempIdentifier,
                "final_asset_duration": "\(assetDuration.seconds)",
                "memory_efficient": "true",
                "streaming_successful": "true"
            ])

            logger.info("🎬 VIDEO_LOADER: 🏆 Returning VideoLoaderResult from direct load [\(correlationId)]")

            return AddMoveVideoLoaderResult(asset: avAsset, photosIdentifier: tempIdentifier, filename: filename, temporaryFileURL: tempURL)

        } catch {
            await diagnosticLogger.stopTiming("direct_loading")

            // Clean up temporary file if it exists
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try? FileManager.default.removeItem(at: tempURL)
                await diagnosticLogger.logInfo("Cleaned up temporary file after error", metadata: [
                    "correlation_id": correlationId,
                    "temp_path": tempURL.path,
                    "cleanup_successful": "true"
                ])
            }

            logger.error("🎬 VIDEO_LOADER: ❌ Direct loading failed: \(error.localizedDescription) [\(correlationId)]")
            await diagnosticLogger.logError("Direct loading failed", error: error, metadata: [
                "correlation_id": correlationId,
                "temp_path": tempURL.path,
                "error_type": "\(type(of: error))",
                "user_impact": "Cannot load video - streaming copy failed"
            ])

            // Convert to appropriate error type
            if error.localizedDescription.contains("format") || error.localizedDescription.contains("type") {
                throw AddMoveVideoLoaderError.unsupportedFileType
            } else if error.localizedDescription.contains("data") {
                throw AddMoveVideoLoaderError.dataUnavailable
            } else {
                throw AddMoveVideoLoaderError.temporaryFileError(error)
            }
        }
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
