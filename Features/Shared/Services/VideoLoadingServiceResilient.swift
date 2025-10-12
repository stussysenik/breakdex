import AVFoundation
import Combine
import Foundation
import OSLog
import Photos
import PhotosUI
import SwiftUI

// VideoLoadingServiceResilient.swift

// MARK: - CLASS
@MainActor
@preconcurrency
public class VideoLoadingServiceResilient: @preconcurrency
    ModernVideoLoadingServiceProtocol
{
    // MARK: - VAR
    private let logger = Logger(
        subsystem: "breakdex",
        category: "🚀 RESILIENT_VIDEO_SERVICE"
    )
    private let resilientIntegration: ResilientVideoLoaderIntegration

    @Published public private(set) var estimatedFileSize: Int64 = 0
    @Published public private(set) var formattedFileSize: String = ""

    private let unifiedProgressEngine: UnifiedProgressEngine

    private let progressSubject = PassthroughSubject<
        VideoLoadingProgress, Never
    >()

    public var progressPublisher: AnyPublisher<VideoLoadingProgress, Never> {
        progressSubject.eraseToAnyPublisher()
    }

    private var temporaryFiles: Set<URL> = []

    private var operationTimings: [String: TimeInterval] = [:]

    // MARK: - INIT
    public init(unifiedProgressEngine: UnifiedProgressEngine) {
        self.unifiedProgressEngine = unifiedProgressEngine
        self.resilientIntegration = ResilientVideoLoaderIntegration(
            unifiedProgressEngine: unifiedProgressEngine
        )

        //         logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ✅ FAULT_TOLERANT_REFACTOR: Initialized with simplified state management"
        //        )
        // logger.info("🚀 RESILIENT_VIDEO_SERVICE: ├─ Timeout: 45s")
        // logger.info("🚀 RESILIENT_VIDEO_SERVICE: ├─ Max retries: 3")
        // logger.info("🚀 RESILIENT_VIDEO_SERVICE: ├─ Network monitoring: ENABLED")
        // logger.info("🚀 RESILIENT_VIDEO_SERVICE: ├─ Progress Engine: GUARANTEED")
        // logger.info(
        //     "🚀 RESILIENT_VIDEO_SERVICE: └─ Binding Chain: ELIMINATED (direct UI binding)"
        // )
    }

    // MARK: - FUNC
    public func loadVideoAsset(
        phAsset: PHAsset,
        options: PHVideoRequestOptions? = nil
    ) async throws -> AVAsset {

        let correlationId = generateCorrelationId()

        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: 🎬 Starting resilient video loading [\(correlationId)]"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ Asset ID: \(phAsset.localIdentifier)"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ Media type: \(phAsset.mediaType.rawValue)"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: └─ Duration: \(phAsset.duration)s"
        //        )

        do {
            let asset = try await resilientIntegration.loadVideoAsset(
                phAsset: phAsset,
                options: options
            )

            //            logger.info(
            //                "🚀 RESILIENT_VIDEO_SERVICE: ✅ Video loading completed successfully [\(correlationId)]"
            //            )
            //            logger.info(
            //                "🚀 RESILIENT_VIDEO_SERVICE:  STATE_MANAGEMENT: Delegated to UnifiedProgressEngine"
            //            )
            return asset

        } catch {
            logger.error(
                "🚀 RESILIENT_VIDEO_SERVICE: ❌ Video loading failed: \(error.localizedDescription) [\(correlationId)]"
            )
            logger.error(
                "🚀 RESILIENT_VIDEO_SERVICE:  STATE_MANAGEMENT: Error propagated to UnifiedProgressEngine"
            )
            throw error
        }
    }

    // MARK: - FUNC
    public func loadVideoAsset(
        phAsset: PHAsset,
        options: PHVideoRequestOptions,
        progress: @escaping (Double) -> Void
    ) async throws -> AVAsset {

        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: 🔄 Legacy compatibility method with progress callback"
        //        )

        return try await loadVideoAsset(phAsset: phAsset, options: options)
    }

    // MARK: - FUNC
    public func requestAVAssetWithTimeout(
        for asset: PHAsset,
        options: PHVideoRequestOptions,
        correlationId: String = ""
    ) async throws -> AVAsset {

        let operationId =
            correlationId.isEmpty ? generateCorrelationId() : correlationId

        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: 🔄 ImportManager compatibility request [\(operationId)]"
        //        )

        return try await resilientIntegration.requestAVAssetWithTimeout(
            for: asset,
            options: options,
            correlationId: operationId
        )
    }

    // MARK: - FUNC
    public func cancelLoading() {
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: 🚫 Cancelling video loading operation"
        //        )

        resilientIntegration.cancelLoading()

        // logger.info("🚀 RESILIENT_VIDEO_SERVICE: ✅ Loading operation cancelled")
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE:  STATE_MANAGEMENT: Cancellation delegated to UnifiedProgressEngine"
        //        )
    }

    public var diagnosticInfo: [String: Any] {
        var info = resilientIntegration.diagnosticInfo

        info["service_loading"] =
            unifiedProgressEngine.currentPhase != .initializing
            && unifiedProgressEngine.currentPhase != .complete
            && unifiedProgressEngine.currentPhase != .completed
        info["service_progress"] = unifiedProgressEngine.unifiedProgress
        info["service_status"] = unifiedProgressEngine.unifiedStatus
        info["service_waiting"] =
            unifiedProgressEngine.currentPhase == .waitingForNetwork
        info["service_error"] =
            unifiedProgressEngine.currentError?.localizedDescription ?? "None"

        info["file_size_bytes"] = estimatedFileSize
        info["file_size_formatted"] = formattedFileSize
        info["binding_chain_eliminated"] = true

        return info
    }

    // MARK: - FUNC
    public func logDiagnostics() {
        // logger.info("🚀 RESILIENT_VIDEO_SERVICE:  FAULT_TOLERANT_DIAGNOSTICS")
        // logger.info("🚀 RESILIENT_VIDEO_SERVICE: ├─ Binding Chain: ELIMINATED")
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ State Management: DELEGATED to UnifiedProgressEngine"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ File Size: \(self.formattedFileSize)"
        //        )
        // logger.info("🚀 RESILIENT_VIDEO_SERVICE: └─ Fault Tolerance: ENABLED")

        // logger.info("🚀 RESILIENT_VIDEO_SERVICE:  SIMPLIFIED_PROGRESS_FLOW")
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ Unified Progress: \(String(format: "%.3f", self.unifiedProgressEngine.unifiedProgress)) (\(Int(self.unifiedProgressEngine.unifiedProgress * 100))%)"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ Unified Phase: \(self.unifiedProgressEngine.currentPhase.displayName)"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ Unified Status: '\(self.unifiedProgressEngine.unifiedStatus)'"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: └─ Flow Status: ✅ SINGLE_SOURCE_OF_TRUTH"
        //        )

        resilientIntegration.logDiagnostics()
    }

    // MARK: - FUNC
    private func generateCorrelationId() -> String {
        return "VLS-\(UUID().uuidString.prefix(8).uppercased())"
    }

    // MARK: - FUNC
    public func loadVideo(from item: PhotosPickerItem) async throws
        -> VideoLoadingResult
    {
        let correlationId = generateCorrelationId()

        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: 📱 Loading from PhotosPicker [\(correlationId)]"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ Item ID: \(item.itemIdentifier ?? "MISSING")"
        //        )
        // logger.info("🚀 RESILIENT_VIDEO_SERVICE: └─ Fallback Available: ✅")

        if let itemIdentifier = item.itemIdentifier {
            //            logger.info(
            //                "🚀 RESILIENT_VIDEO_SERVICE: 🔄 Attempting primary identifier-based loading [\(correlationId)]"
            //            )

            let fetchResult = PHAsset.fetchAssets(
                withLocalIdentifiers: [itemIdentifier],
                options: nil
            )
            if let phAsset = fetchResult.firstObject {
                logger.info(
                    "🚀 RESILIENT_VIDEO_SERVICE: ✅ PHAsset found, proceeding with identifier-based loading [\(correlationId)]"
                )

                do {
                    return try await loadVideo(from: phAsset)
                } catch {
                    logger.warning(
                        "🚀 RESILIENT_VIDEO_SERVICE: ⚠️ Identifier-based loading failed, will fallback to data transfer [\(correlationId)]: \(error.localizedDescription)"
                    )

                }
            } else {
                logger.warning(
                    "🚀 RESILIENT_VIDEO_SERVICE: ⚠️ No PHAsset found for identifier, will fallback to data transfer [\(correlationId)]"
                )

            }
        } else {
            logger.warning(
                "🚀 RESILIENT_VIDEO_SERVICE: ⚠️ No item identifier available, proceeding directly to data transfer fallback [\(correlationId)]"
            )
        }

        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: 🔄 Initiating fallback data transfer loading [\(correlationId)]"
        //        )
        return try await loadVideoViaDataTransfer(
            from: item,
            correlationId: correlationId
        )
    }

    // MARK: - FUNC
    public func loadVideo(from url: URL) async throws -> VideoLoadingResult {
        let correlationId = generateCorrelationId()

        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: 🌐 Loading from URL [\(correlationId)]: \(url.lastPathComponent)"
        //        )

        let asset = AVURLAsset(url: url)

        try await validateAsset(asset, correlationId: correlationId)

        let fileSize = try await getFileSize(url)
        let duration = try await asset.load(.duration)

        let result = VideoLoadingResult(
            asset: asset,
            photosIdentifier: nil,
            cloudIdentifier: nil,
            filename: url.lastPathComponent,
            temporaryFileURL: url,
            sourceType: .fileURL,
            fileSize: fileSize,
            duration: duration,
            correlationId: correlationId
        )

        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ✅ URL loading completed [\(correlationId)]"
        //        )
        return result
    }

    // MARK: - FUNC
    public func loadVideo(from phAsset: PHAsset) async throws
        -> VideoLoadingResult
    {
        let correlationId = generateCorrelationId()
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: 📚 Loading from PHAsset [\(correlationId)]: \(phAsset.localIdentifier)"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: 🎯 RACE_CONDITION_FIX: SRP enforcement - ResilientVideoLoaderIntegration is SINGLE source of truth"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ Manual progress reporting: DISABLED"
        //        )
        // logger.info("🚀 RESILIENT_VIDEO_SERVICE: ├─ Artificial delays: REMOVED")
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: └─ Progress flow: DIRECT → UnifiedProgressEngine"
        //        )

        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE:  Retrieving file size for UI [\(correlationId)]"
        //        )
        let fileSize = await getPHAssetFileSize(phAsset)
        await MainActor.run {
            self.estimatedFileSize = fileSize
            self.formattedFileSize = self.formatFileSize(fileSize)
        }
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ File size: \(self.formatFileSize(fileSize))"
        //        )
        // logger.info("🚀 RESILIENT_VIDEO_SERVICE: └─ Size retrieval: completed")

        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: 🔄 Delegating to ResilientVideoLoaderIntegration [\(correlationId)]"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ Progress reporting: MANAGED by UnifiedProgressEngine"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: └─ Race condition prevention: ACTIVE"
        //        )

        let asset = try await resilientIntegration.loadVideoAsset(
            phAsset: phAsset
        )

        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ✅ ResilientVideoLoaderIntegration completed [\(correlationId)]"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE:  UnifiedProgressEngine state: .completed (100%)"
        //        )

        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: 🔍 Gathering metadata and finalizing result [\(correlationId)]"
        //        )

        try await validateAsset(asset, correlationId: correlationId)

        let duration = try await asset.load(.duration)
        _ = try await asset.loadTracks(withMediaType: .video)

        // logger.info("🚀 RESILIENT_VIDEO_SERVICE: ├─ Asset validation: ✅")
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ Duration: \(String(format: "%.2f", duration.seconds))s"
        //        )
        // logger.info("🚀 RESILIENT_VIDEO_SERVICE: └─ Video tracks: ✅")

        let sourceType: VideoSourceType =
            phAsset.sourceType == .typeCloudShared
            ? .cloudAsset : .photosLibrary
        let result = VideoLoadingResult(
            asset: asset,
            photosIdentifier: phAsset.localIdentifier,
            cloudIdentifier: sourceType == .cloudAsset
                ? phAsset.localIdentifier : nil,
            filename: "video_\(correlationId.suffix(8)).mov",
            temporaryFileURL: nil,
            sourceType: sourceType,
            fileSize: fileSize,
            duration: duration,
            correlationId: correlationId
        )

        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: 🏆 PHAsset loading completed successfully [\(correlationId)]"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ Source type: \(sourceType.description)"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ File size: \(self.formatFileSize(fileSize))"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ Duration: \(String(format: "%.2f", duration.seconds))s"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: └─ Race condition fix: ELIMINATED rogue functor path"
        //        )

        return result
    }

    // MARK: - FUNC
    private func loadVideoViaDataTransfer(
        from item: PhotosPickerItem,
        correlationId: String
    ) async throws -> VideoLoadingResult {
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: 🔄 Starting data transfer fallback loading [\(correlationId)]"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ Method: loadTransferable(type: Data.self)"
        //        )
        // logger.info("🚀 RESILIENT_VIDEO_SERVICE: └─ iCloud Handling: Built-in")

        let dataTransferStart = Date()

        do {

            reportProgress(.initializing, correlationId: correlationId)

            //            logger.info(
            //                "🚀 RESILIENT_VIDEO_SERVICE: 📥 Loading video data from PhotosPickerItem [\(correlationId)]"
            //            )

            let videoData = try await item.loadTransferable(type: Data.self)

            guard let data = videoData else {
                throw VideoLoadingError.dataTransferFailed(
                    "No data received from PhotosPicker"
                )
            }

            await MainActor.run {
                self.estimatedFileSize = Int64(data.count)
                self.formattedFileSize = self.formatFileSize(Int64(data.count))
            }

            //            logger.info(
            //                "🚀 RESILIENT_VIDEO_SERVICE: ✅ Video data loaded successfully [\(correlationId)]"
            //            )
            //            logger.info(
            //                "🚀 RESILIENT_VIDEO_SERVICE: ├─ Data Size: \(self.formatFileSize(Int64(data.count)))"
            //            )
            //            logger.info(
            //                "🚀 RESILIENT_VIDEO_SERVICE: └─ Loading Time: \(String(format: "%.2f", Date().timeIntervalSince(dataTransferStart)))s"
            //            )
            //
            //            logger.info(
            //                "🚀 RESILIENT_VIDEO_SERVICE: 💾 Creating temporary file for video data [\(correlationId)]"
            //            )

            let tempURL = createTemporaryFileURL()
            temporaryFiles.insert(tempURL)

            reportProgress(.transferring, correlationId: correlationId)

            try await writeVideoDataToTemporaryFile(
                data,
                to: tempURL,
                correlationId: correlationId
            )

            logger.info(
                "🚀 RESILIENT_VIDEO_SERVICE: ✅ Video data written to temporary file [\(correlationId)]"
            )
            logger.info(
                "🚀 RESILIENT_VIDEO_SERVICE: └─ Temp File: \(tempURL.lastPathComponent)"
            )

            reportProgress(.creatingAsset, correlationId: correlationId)

            let asset = AVURLAsset(url: tempURL)

            try await validateAsset(asset, correlationId: correlationId)

            let duration = try await asset.load(.duration)

            reportProgress(.validating, correlationId: correlationId)

            let tempIdentifier = generateTemporaryIdentifier()
            logger.info(
                "🚀 RESILIENT_VIDEO_SERVICE: 🆔 Generated temporary identifier [\(correlationId)]: \(tempIdentifier)"
            )

            reportProgress(.validatingTrimmer, correlationId: correlationId)

            let result = VideoLoadingResult(
                asset: asset,
                photosIdentifier: tempIdentifier,
                cloudIdentifier: nil,
                filename: "temp_video_\(tempIdentifier.suffix(8)).mov",
                temporaryFileURL: tempURL,
                sourceType: .directPicker,
                fileSize: Int64(data.count),
                duration: duration,
                correlationId: correlationId
            )

            reportProgress(.completed, correlationId: correlationId)

            operationTimings["data_transfer_fallback"] = Date()
                .timeIntervalSince(dataTransferStart)

            logger.info(
                "🚀 RESILIENT_VIDEO_SERVICE: 🏆 Data transfer fallback completed successfully [\(correlationId)]"
            )
            logger.info(
                "🚀 RESILIENT_VIDEO_SERVICE: ├─ Total Duration: \(String(format: "%.2f", Date().timeIntervalSince(dataTransferStart)))s"
            )
            logger.info(
                "🚀 RESILIENT_VIDEO_SERVICE: ├─ File Size: \(self.formatFileSize(Int64(data.count)))"
            )
            logger.info(
                "🚀 RESILIENT_VIDEO_SERVICE: ├─ Duration: \(String(format: "%.2f", duration.seconds))s"
            )
            logger.info(
                "🚀 RESILIENT_VIDEO_SERVICE: └─ Temp Identifier: \(tempIdentifier)"
            )

            return result

        } catch {
            logger.error(
                "🚀 RESILIENT_VIDEO_SERVICE: ❌ Data transfer fallback failed [\(correlationId)]: \(error.localizedDescription)"
            )

            await cleanupTemporaryFiles()

            throw VideoLoadingError.dataUnavailable
        }
    }

    // MARK: - FUNC
    public func cleanupTemporaryFiles() async {
        // logger.info("🚀 RESILIENT_VIDEO_SERVICE: 🧹 Cleaning up temporary files")

        for tempFile in temporaryFiles {
            do {
                try FileManager.default.removeItem(at: tempFile)
                //                logger.info(
                //                    "🚀 RESILIENT_VIDEO_SERVICE: ✅ Removed temporary file: \(tempFile.lastPathComponent)"
                //                )
            } catch {
                logger.warning(
                    "🚀 RESILIENT_VIDEO_SERVICE: ⚠️ Failed to remove temporary file: \(tempFile.lastPathComponent) - \(error.localizedDescription)"
                )
            }
        }

        temporaryFiles.removeAll()
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ✅ Temporary files cleanup completed"
        //        )
    }

    // MARK: - FUNC
    public func cancelCurrentOperation() {
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: 🚫 Cancelling current loading operation"
        //        )

        resilientIntegration.cancelLoading()

        // logger.info("🚀 RESILIENT_VIDEO_SERVICE: ✅ Current operation cancelled")
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE:  STATE_MANAGEMENT: Cancellation delegated to UnifiedProgressEngine"
        //        )
    }

    // MARK: - FUNC
    private func reportProgress(
        _ phase: VideoLoadingProgress.LoadingPhase,
        correlationId: String
    ) {
        let progress = VideoLoadingProgress(
            phase: phase,
            correlationId: correlationId
        )
        progressSubject.send(progress)

        logger.debug(
            "🚀 RESILIENT_VIDEO_SERVICE:  Progress [\(correlationId)]: \(phase.description)"
        )
    }

    // MARK: - FUNC
    private func validateAsset(_ asset: AVAsset, correlationId: String)
        async throws
    {
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: 🔍 Validating asset [\(correlationId)]"
        //        )

        let isReadable = try await asset.load(.isReadable)
        guard isReadable else {
            throw VideoLoadingError.avAssetCreationFailed
        }

        let duration = try await asset.load(.duration)
        guard duration.seconds > 0 else {
            throw VideoLoadingError.dataUnavailable
        }

        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ✅ Asset validation passed [\(correlationId)] - Duration: \(duration.seconds)s"
        //        )
    }

    // MARK: - FUNC
    private func getFileSize(_ url: URL) async throws -> Int64 {
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(resourceValues.fileSize ?? 0)
    }

    // MARK: - FUNC
    private func getPHAssetFileSize(_ phAsset: PHAsset) async -> Int64 {
        let correlationId = generateCorrelationId()

        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE:  FILE_SIZE_QUERY: Starting PHAsset file size retrieval [\(correlationId)]"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ Asset ID: \(phAsset.localIdentifier)"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ Media Type: \(phAsset.mediaType.rawValue)"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: └─ Duration: \(phAsset.duration)s"
        //        )

        let resources = PHAssetResource.assetResources(for: phAsset)
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE:  RESOURCE_ANALYSIS: Found \(resources.count) asset resources"
        //        )

        for (index, resource) in resources.enumerated() {
            logger.info(
                "🚀 RESILIENT_VIDEO_SERVICE: ├─ Resource \(index): \(resource.type.rawValue) - \(resource.originalFilename)"
            )
        }

        let videoResource = resources.first { $0.type == .video }
        var fileSize: Int64 = 0

        if let videoResource = videoResource {

            if let directSize = videoResource.value(forKey: "fileSize")
                as? Int64
            {
                fileSize = directSize
                logger.info(
                    "🚀 RESILIENT_VIDEO_SERVICE: ✅ FILE_SIZE_DIRECT: Successfully retrieved file size via direct property"
                )
                logger.info(
                    "🚀 RESILIENT_VIDEO_SERVICE: ├─ Method: PHAssetResource.fileSize"
                )
                logger.info(
                    "🚀 RESILIENT_VIDEO_SERVICE: ├─ File Size: \(self.formatFileSize(fileSize))"
                )
                logger.info(
                    "🚀 RESILIENT_VIDEO_SERVICE: └─ Raw Bytes: \(fileSize)"
                )
            } else {
                logger.warning(
                    "🚀 RESILIENT_VIDEO_SERVICE: ⚠️ FILE_SIZE_DIRECT: Direct fileSize property unavailable"
                )

                let resourceOptions = PHAssetResourceRequestOptions()
                resourceOptions.isNetworkAccessAllowed = true

                logger.info(
                    "🚀 RESILIENT_VIDEO_SERVICE: 🔄 FILE_SIZE_FALLBACK: Attempting resource request for file size"
                )

                if let duration = phAsset.value(forKey: "duration")
                    as? TimeInterval,
                    let estimatedSize = estimateFileSizeFromDuration(duration)
                {
                    fileSize = estimatedSize
                    logger.info(
                        "🚀 RESILIENT_VIDEO_SERVICE:  FILE_SIZE_ESTIMATED: Calculated from duration"
                    )
                    logger.info(
                        "🚀 RESILIENT_VIDEO_SERVICE: ├─ Duration: \(String(format: "%.2f", duration))s"
                    )
                    logger.info(
                        "🚀 RESILIENT_VIDEO_SERVICE: ├─ Estimated Size: \(self.formatFileSize(fileSize))"
                    )
                    logger.info(
                        "🚀 RESILIENT_VIDEO_SERVICE: └─ Method: Duration-based estimation"
                    )
                }
            }
        } else {
            logger.error(
                "🚀 RESILIENT_VIDEO_SERVICE: ❌ FILE_SIZE_ERROR: No video resource found for asset"
            )
        }

        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE:  FILE_SIZE_COMPLETE: File size retrieval completed [\(correlationId)]"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ Final File Size: \(self.formatFileSize(fileSize))"
        //        )
        // logger.info("🚀 RESILIENT_VIDEO_SERVICE: ├─ Raw Bytes: \(fileSize)")
        // logger.info("🚀 RESILIENT_VIDEO_SERVICE: └─ Success: \(fileSize > 0)")

        return fileSize
    }

    // MARK: - FUNC
    private func estimateFileSizeFromDuration(_ duration: TimeInterval)
        -> Int64?
    {

        let conservativeBitrate: Double = 5_000_000
        let fileSizeBits = duration * conservativeBitrate
        let fileSizeBytes = fileSizeBits / 8

        let estimatedSize = Int64(fileSizeBytes)

        // logger.info("🚀 RESILIENT_VIDEO_SERVICE:  SIZE_ESTIMATION_CALCULATION:")
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ Duration: \(String(format: "%.2f", duration))s"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ Conservative Bitrate: \(conservativeBitrate / 1_000_000) Mbps"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ Total Bits: \(String(format: "%.0f", fileSizeBits))"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ Total Bytes: \(String(format: "%.0f", fileSizeBytes))"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: └─ Estimated Size: \(self.formatFileSize(estimatedSize))"
        //        )

        return estimatedSize
    }

    // MARK: - FUNC
    private func formatFileSize(_ bytes: Int64) -> String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useMB, .useKB, .useBytes]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: bytes)
    }

    // MARK: - FUNC
    private func createTemporaryFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "fallback_video_\(UUID().uuidString).mov"
        let tempURL = tempDir.appendingPathComponent(filename)

        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: 📁 Created temporary file URL: \(tempURL.lastPathComponent)"
        //        )
        return tempURL
    }

    // MARK: - FUNC
    private func writeVideoDataToTemporaryFile(
        _ videoData: Data,
        to url: URL,
        correlationId: String
    ) async throws {
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: 💾 Writing video data to temporary file [\(correlationId)]"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: ├─ Data Size: \(self.formatFileSize(Int64(videoData.count)))"
        //        )
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: └─ Destination: \(url.lastPathComponent)"
        //        )

        let writeStart = Date()

        do {

            try videoData.write(to: url)

            let writeDuration = Date().timeIntervalSince(writeStart)
            logger.info(
                "🚀 RESILIENT_VIDEO_SERVICE: ✅ Video data written successfully [\(correlationId)]"
            )
            logger.info(
                "🚀 RESILIENT_VIDEO_SERVICE: ├─ Write Duration: \(String(format: "%.3f", writeDuration))s"
            )
            logger.info(
                "🚀 RESILIENT_VIDEO_SERVICE: └─ Throughput: \(self.formatFileSize(Int64(Double(videoData.count) / writeDuration)))/s"
            )

        } catch {
            logger.error(
                "🚀 RESILIENT_VIDEO_SERVICE: ❌ Failed to write video data [\(correlationId)]: \(error.localizedDescription)"
            )
            throw VideoLoadingError.temporaryFileError(error)
        }
    }

    // MARK: - FUNC
    private func generateTemporaryIdentifier() -> String {
        let tempId = "temp-\(UUID().uuidString.lowercased())"
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: 🆔 Generated temporary identifier: \(tempId)"
        //        )
        return tempId
    }
}

// MARK: - EXTENSION 1
extension VideoLoadingProgress.LoadingPhase {
    var description: String {
        switch self {
        case .idle:
            return "Ready"
        case .initializing:
            return "Initializing..."
        case .requestingDownload:
            return "Requesting download..."
        case .downloadingFromCloud(let progress):
            return "Downloading from iCloud... (\(Int(progress * 100))%)"
        case .transferring:
            return "Transferring video..."
        case .creatingAsset:
            return "Creating video asset..."
        case .generatingThumbnail:
            return "Generating thumbnail..."
        case .loadingTrimmerDuration:
            return "Loading trimmer duration..."
        case .loadingTrimmerTracks:
            return "Loading trimmer tracks..."
        case .validating:
            return "Validating video..."
        case .validatingTrimmer:
            return "Validating trimmer setup..."
        case .waitingForNetwork:
            return "Waiting for network..."
        case .loading:
            return "Loading..."
        case .processing:
            return "Processing..."
        case .saving:
            return "Saving..."
        case .completed:
            return "Completed"
        case .complete:
            return "Complete"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

// MARK: - EXTENSION 2
extension VideoLoadingServiceResilient {
    // MARK: - FUNC
    public static func createWithProgressEngine(
        _ unifiedProgressEngine: UnifiedProgressEngine
    ) -> VideoLoadingServiceResilient {
        return VideoLoadingServiceResilient(
            unifiedProgressEngine: unifiedProgressEngine
        )
    }
    // MARK: - FUNC
    public static func createStandalone() -> VideoLoadingServiceResilient {

        let standaloneEngine = UnifiedProgressEngine()
        return VideoLoadingServiceResilient(
            unifiedProgressEngine: standaloneEngine
        )
    }
}

// MARK: - EXTENSION 3
extension VideoLoadingServiceResilient {
    // MARK: - FUNC
    public func fetchAsset(with identifier: String) async -> AVAsset? {
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: 🔄 PhotosAssetLoader compatibility method"
        //        )

        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier],
            options: nil
        )
        guard let asset = fetchResult.firstObject else {
            logger.error(
                "🚀 RESILIENT_VIDEO_SERVICE: ❌ No PHAsset found for identifier: \(identifier)"
            )
            return nil
        }

        do {
            return try await loadVideoAsset(phAsset: asset)
        } catch {
            logger.error(
                "🚀 RESILIENT_VIDEO_SERVICE: ❌ Failed to fetch asset: \(error.localizedDescription)"
            )
            return nil
        }
    }
    // MARK: - FUNC
    public func loadAVAsset(
        phAsset: PHAsset,
        options: PHVideoRequestOptions,
        correlationId: String = ""
    ) async throws -> AVAsset {
        // logger.info(
        //            "🚀 RESILIENT_VIDEO_SERVICE: 🔄 AddMoveVideoLoader compatibility method"
        //        )
        return try await requestAVAssetWithTimeout(
            for: phAsset,
            options: options,
            correlationId: correlationId
        )
    }
}
