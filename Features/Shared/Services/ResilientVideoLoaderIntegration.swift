// import Foundation
// import Photos
// import AVFoundation
// import OSLog
// import SwiftUI
// import Combine

// /// MARK: - Resilient Video Loader Integration
// ///
// /// Integration layer that connects ResilientVideoLoader with existing AddMove architecture
// /// Provides seamless replacement for current video loading implementations
// ///
// /// Key Features:
// /// - Drop-in replacement for ImportManager.requestAVAssetWithTimeout()
// /// - Seamless integration with UnifiedProgressEngine
// /// - Maintains existing API compatibility
// /// - Enhanced error handling with detailed diagnostics
// /// - Automatic retry and network resilience
// @MainActor
// public class ResilientVideoLoaderIntegration: ObservableObject {

//     // MARK: - Properties
//     private let logger = Logger(subsystem: "breakdex", category: "🔗 RESILIENT_INTEGRATION")
//     private let resilientLoader: ResilientVideoLoader
//     private let unifiedProgressEngine: UnifiedProgressEngine

//     // MARK: - Progress Subscription
//     /// Durable subscription to ResilientVideoLoader progress publisher
//     /// Ensures progress is never lost due to nil references or closure capture issues
//     private var progressSubscription: AnyCancellable?

//     // MARK: - Published Properties
//     @Published public private(set) var isLoading = false
//     @Published public private(set) var isWaitingForNetwork = false
//     @Published public private(set) var loadingProgress: Double = 0.0
//     @Published public private(set) var loadingStatus: String = ""
//     @Published public private(set) var currentError: Error?

//     // MARK: - Initialization

//     public init(unifiedProgressEngine: UnifiedProgressEngine) {
//         self.unifiedProgressEngine = unifiedProgressEngine
//         self.resilientLoader = ResilientVideoLoader()

//         setupBindings()

//         // logger.info("🔗 RESILIENT_INTEGRATION: ✅ Initialized with GUARANTEED UnifiedProgressEngine integration")
//         // logger.info("🔗 RESILIENT_INTEGRATION: └─ Data Flow Integrity: ENFORCED by compiler")
//     }

//     // MARK: - Public API

//     /// Load video asset using ResilientVideoLoader with automatic retry and network resilience
//     /// - Parameters:
//     ///   - phAsset: The Photos library asset to load
//     ///   - options: Optional video request options
//     /// - Returns: AVAsset if successful
//     /// - Throws: ResilientVideoLoaderError with detailed diagnostics
//     // MARK: - FUNC
//     public func loadVideoAsset(
//         phAsset: PHAsset,
//         options: PHVideoRequestOptions? = nil
//     ) async throws -> AVAsset {

//         let correlationId = generateCorrelationId()

//         // logger.info("🔗 RESILIENT_INTEGRATION: 🚀 Starting integrated video loading [\(correlationId)]")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Asset ID: \(phAsset.localIdentifier)")
//         // logger.info("🔗 RESILIENT_INTEGRATION: └─ Correlation ID: \(correlationId)")

//         isLoading = true
//         currentError = nil

//         // Initialize progress engine (now guaranteed to exist)
//         unifiedProgressEngine.beginLoading()

//         do {
//             let asset = try await resilientLoader.loadVideoAsset(
//                 phAsset: phAsset,
//                 options: options
//             ) { [weak self] progress, status in
//                 Task { @MainActor in
//                     self?.updateProgress(progress, status: status)
//                 }
//             }

//             isLoading = false
//             loadingProgress = 1.0
//             loadingStatus = "Video loaded successfully"

//             unifiedProgressEngine.completeLoading()

//             // logger.info("🔗 RESILIENT_INTEGRATION: ✅ Video loading completed successfully [\(correlationId)]")
//             return asset

//         } catch {
//             isLoading = false
//             currentError = error
//             loadingStatus = "Loading failed: \(error.localizedDescription)"

//             // Handle specific error types (engine is now guaranteed to exist)
//             if let resilientError = error as? ResilientVideoLoader.ResilientVideoLoaderError {
//                 unifiedProgressEngine.handleError(mapResilientErrorToProgressError(resilientError))
//             } else {
//                 unifiedProgressEngine.handleError(.unknown(error.localizedDescription))
//             }

//             logger.error("🔗 RESILIENT_INTEGRATION: ❌ Video loading failed: \(error.localizedDescription) [\(correlationId)]")
//             throw error
//         }
//     }

//     /// Request AVAsset with timeout and network resilience (compatible with ImportManager API)
//     /// - Parameters:
//     ///   - asset: The Photos library asset
//     ///   - options: Video request options
//     ///   - correlationId: Optional correlation ID for tracking
//     /// - Returns: AVAsset if successful
//     /// - Throws: Error with detailed diagnostics
//     // MARK: - FUNC
//     public func requestAVAssetWithTimeout(
//         for asset: PHAsset,
//         options: PHVideoRequestOptions,
//         correlationId: String = ""
//     ) async throws -> AVAsset {

//         let operationId = correlationId.isEmpty ? generateCorrelationId() : correlationId

//         // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 Compatibility request for AVAsset [\(operationId)]")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Asset: \(asset.localIdentifier)")
//         // logger.info("🔗 RESILIENT_INTEGRATION: └─ Timeout: 45s with network resilience")

//         return try await loadVideoAsset(phAsset: asset, options: options)
//     }
//     // MARK: - FUNC
//     /// Cancel current loading operation
//     public func cancelLoading() {
//         // logger.info("🔗 RESILIENT_INTEGRATION: 🚫 Cancelling integrated loading operation")

//         resilientLoader.cancelLoading()
//         unifiedProgressEngine.cancelLoading()

//         // 🧹 SUBSCRIPTION_CLEANUP: Cancel Combine subscription on cancellation
//         progressSubscription?.cancel()
//         progressSubscription = nil

//         isLoading = false
//         isWaitingForNetwork = false
//         currentError = nil

//         // logger.info("🔗 RESILIENT_INTEGRATION: ✅ Loading operation cancelled")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ ResilientVideoLoader: ✅ Cancelled")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ UnifiedProgressEngine: ✅ Cancelled")
//         // logger.info("🔗 RESILIENT_INTEGRATION: └─ Combine Subscription: ✅ Cancelled")
//     }

//     /// Get current diagnostic information
//     public var diagnosticInfo: [String: Any] {
//         var info = resilientLoader.diagnosticInfo
//         info["integration_loading"] = isLoading
//         info["integration_waiting"] = isWaitingForNetwork
//         info["integration_progress"] = loadingProgress
//         info["integration_status"] = loadingStatus
//         info["unified_progress"] = unifiedProgressEngine.unifiedProgress
//         info["unified_phase"] = unifiedProgressEngine.currentPhase.rawValue
//         return info
//     }
//     // MARK: - FUNC
//     /// Log comprehensive diagnostic information
//     public func logDiagnostics() {
//         // logger.info("🔗 RESILIENT_INTEGRATION:  COMPREHENSIVE INTEGRATION DIAGNOSTICS")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Loading State: \(self.isLoading ? "ACTIVE" : "IDLE")")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Waiting for Network: \(self.isWaitingForNetwork ? "YES" : "NO")")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Loading Progress: \(Int(self.loadingProgress * 100))%")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Loading Status: '\(self.loadingStatus)'")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Current Error: \(self.currentError?.localizedDescription ?? "None")")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Unified Progress: \(String(format: "%.3f", self.unifiedProgressEngine.unifiedProgress))")
//         // logger.info("🔗 RESILIENT_INTEGRATION: └─ Unified Phase: \(self.unifiedProgressEngine.currentPhase.displayName)")

//         resilientLoader.logDiagnostics()
//     }

//     // MARK: - Private Implementation
//     // MARK: - FUNC
//     private func setupBindings() {
//         // 🔗 DURABLE_SUBSCRIPTION: Create subscription to ResilientVideoLoader progress publisher
//         // This ensures iCloud progress is never lost due to nil references in closure captures
//         // logger.info("🔗 RESILIENT_INTEGRATION: 🔗 ESTABLISHING_DURABLE_SUBSCRIPTION: Creating Combine subscription")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Source: ResilientVideoLoader.progressPublisher")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Destination: UnifiedProgressEngine")
//         // logger.info("🔗 RESILIENT_INTEGRATION: └─ Purpose: Prevent progress loss due to nil references")

//         progressSubscription = resilientLoader.progressPublisher
//             .sink { [weak self] progress in
//                 Task { @MainActor in
//                     await self?.handleProgressFromPublisher(progress)
//                 }
//             }

//         // logger.info("🔗 RESILIENT_INTEGRATION: ✅ DURABLE_SUBSCRIPTION_ESTABLISHED: Combine subscription active")

//         // Bind resilient loader state to integration state
//         Task { @MainActor in
//             for await isLoading in resilientLoader.$isLoading.values {
//                 self.isLoading = isLoading
//                 logger.debug("🔗 RESILIENT_INTEGRATION: Loading state updated: \(isLoading)")
//             }
//         }

//         Task { @MainActor in
//             for await isWaiting in resilientLoader.$isWaitingForNetwork.values {
//                 self.isWaitingForNetwork = isWaiting
//                 logger.debug("🔗 RESILIENT_INTEGRATION: Waiting for network state updated: \(isWaiting)")
//             }
//         }

//         // Bind unified progress engine state (engine is now guaranteed to exist)
//         Task { @MainActor in
//             for await progress in unifiedProgressEngine.$unifiedProgress.values {
//                 self.loadingProgress = progress
//             }
//         }

//         Task { @MainActor in
//             for await status in unifiedProgressEngine.$unifiedStatus.values {
//                 self.loadingStatus = status
//             }
//         }

//         Task { @MainActor in
//             for await error in unifiedProgressEngine.$currentError.values {
//                 self.currentError = error
//             }
//         }
//     }

//     /// 🔗 PROGRESS_FORWARDING: Handle progress from ResilientVideoLoader publisher
//     /// This is the core of the decoupled progress reporting system
//     // MARK: - FUNC
//     private func handleProgressFromPublisher(_ progress: ResilientVideoLoader.VideoLoadingProgress) async {
//         // logger.info("🔗 RESILIENT_INTEGRATION: 📥 PROGRESS_RECEIVED: Progress from ResilientVideoLoader publisher [\(progress.correlationId)]")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Phase: \(String(describing: progress.phase))")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Progress: \(String(format: "%.3f", progress.progress)) (\(Int(progress.progress * 100))%)")
//         // logger.info("🔗 RESILIENT_INTEGRATION: └─ Timestamp: \(progress.timestamp)")

//         // 🔄 PHASE_HANDLING: Process different loading phases
//         switch progress.phase {
//         case .initializing:
//             // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 PHASE_INITIALIZING: Setting up initial loading state")
//             await handleInitializingPhase(progress)

//         case .requestingDownload:
//             // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 PHASE_REQUESTING_DOWNLOAD: Preparing iCloud download")
//             await handleRequestingDownloadPhase(progress)

//         case .downloadingFromCloud(let downloadProgress):
//             // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 PHASE_DOWNLOADING: Processing iCloud download progress")
//             await handleDownloadingPhase(progress, downloadProgress: downloadProgress)

//         case .transferring:
//             // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 PHASE_TRANSFERRING: Handling video transfer")
//             await handleTransferringPhase(progress)

//         case .validating:
//             // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 PHASE_VALIDATING: Validating video asset")
//             await handleValidatingPhase(progress)

//         case .creatingAsset:
//             // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 PHASE_CREATING_ASSET: Creating final video asset")
//             await handleCreatingAssetPhase(progress)

//         case .generatingThumbnail:
//             // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 PHASE_GENERATING_THUMBNAIL: Generating video thumbnail")
//             await handleGeneratingThumbnailPhase(progress)

//         case .loadingTrimmerDuration:
//             // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 PHASE_LOADING_TRIMMER_DURATION: Loading trimmer duration")
//             await handleLoadingTrimmerDurationPhase(progress)

//         case .loadingTrimmerTracks:
//             // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 PHASE_LOADING_TRIMMER_TRACKS: Loading trimmer tracks")
//             await handleLoadingTrimmerTracksPhase(progress)

//         case .validatingTrimmer:
//             // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 PHASE_VALIDATING_TRIMMER: Validating trimmer setup")
//             await handleValidatingTrimmerPhase(progress)

//         case .completed:
//             // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 PHASE_COMPLETED: Video loading completed successfully")
//             await handleCompletedPhase(progress)

//         case .error(let error):
//             logger.error("🔗 RESILIENT_INTEGRATION: ❌ PHASE_ERROR: Error occurred during loading")
//             await handleErrorPhase(progress, error: error)
//         }

//         //  COMPREHENSIVE_DIAGNOSTIC: Log complete flow verification (engine now guaranteed)
//         // logger.info("🔗 RESILIENT_INTEGRATION:  PROGRESS_FLOW_VERIFICATION:")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Source: ResilientVideoLoader.progressPublisher")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Integration: ResilientVideoLoaderIntegration")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Engine Progress: \(String(format: "%.3f", self.unifiedProgressEngine.unifiedProgress)) (\(Int(self.unifiedProgressEngine.unifiedProgress * 100))%)")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Engine Phase: \(self.unifiedProgressEngine.currentPhase.displayName)")
//         // logger.info("🔗 RESILIENT_INTEGRATION: └─ Complete Flow: iCloud → ResilientVideoLoader → Integration → UI (GUARANTEED)")
//     }

//     // MARK: - Phase Handlers
//     // MARK: - FUNC
//     private func handleInitializingPhase(_ progress: ResilientVideoLoader.VideoLoadingProgress) async {
//         // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 INITIALIZING_PHASE: Forwarding to UnifiedProgressEngine")

//         //  DIAGNOSTIC_ENHANCEMENT: Track data flow integrity during initialization
//         // logger.info("🔗 RESILIENT_INTEGRATION:  DATA_FLOW_DIAGNOSTIC: Initializing phase started")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Source Progress: \(String(format: "%.3f", progress.progress))")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Before UnifiedProgress: \(String(format: "%.3f", self.unifiedProgressEngine.unifiedProgress))")
//         // logger.info("🔗 RESILIENT_INTEGRATION: └─ Phase: \(self.unifiedProgressEngine.currentPhase.displayName)")

//         self.unifiedProgressEngine.transitionToPhase(.initializing)
//         self.unifiedProgressEngine.beginLoading()

//         //  DIAGNOSTIC_ENHANCEMENT: Verify unified progress after initialization
//         // logger.info("🔗 RESILIENT_INTEGRATION:  DATA_FLOW_DIAGNOSTIC: After UnifiedProgressEngine.beginLoading()")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ UnifiedProgress: \(String(format: "%.3f", self.unifiedProgressEngine.unifiedProgress)) (\(Int(self.unifiedProgressEngine.unifiedProgress * 100))%)")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Phase: \(self.unifiedProgressEngine.currentPhase.displayName)")
//         // logger.info("🔗 RESILIENT_INTEGRATION: └─ Expected: Should be > 0% (initializing weight: 3%)")

//         updateProgress(progress.progress, status: "Initializing video loading...")
//     }
//     // MARK: - FUNC
//     private func handleRequestingDownloadPhase(_ progress: ResilientVideoLoader.VideoLoadingProgress) async {
//         // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 REQUESTING_DOWNLOAD_PHASE: Forwarding to UnifiedProgressEngine")

//         unifiedProgressEngine.transitionToPhase(.requestingDownload)

//         updateProgress(progress.progress, status: "Requesting video download from iCloud...")
//     }
//     // MARK: - FUNC
//     private func handleDownloadingPhase(_ progress: ResilientVideoLoader.VideoLoadingProgress, downloadProgress: Double) async {
//         // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 DOWNLOADING_PHASE: Forwarding iCloud download progress")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Download Progress: \(String(format: "%.3f", downloadProgress)) (\(Int(downloadProgress * 100))%)")
//         // logger.info("🔗 RESILIENT_INTEGRATION: └─ Overall Progress: \(String(format: "%.3f", progress.progress)) (\(Int(progress.progress * 100))%)")

//         //  DIAGNOSTIC_ENHANCEMENT: Track critical download phase progress flow
//         // logger.info("🔗 RESILIENT_INTEGRATION:  DATA_FLOW_DIAGNOSTIC: Download phase - CRITICAL for progress bar movement")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Raw iCloud Download: \(Int(downloadProgress * 100))% (will be weighted)")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Before UnifiedProgress: \(String(format: "%.3f", self.unifiedProgressEngine.unifiedProgress)) (\(Int(self.unifiedProgressEngine.unifiedProgress * 100))%)")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Phase Weight: 45% (largest contribution)")
//         // logger.info("🔗 RESILIENT_INTEGRATION: └─ Expected Range: 3% - 48% based on download progress")

//         self.unifiedProgressEngine.transitionToPhase(.downloadingFromCloud)
//         self.unifiedProgressEngine.updateDownloadProgress(downloadProgress)

//         //  DIAGNOSTIC_ENHANCEMENT: Verify unified progress calculation
//         let afterUnifiedProgress = self.unifiedProgressEngine.unifiedProgress
//         // logger.info("🔗 RESILIENT_INTEGRATION:  DATA_FLOW_DIAGNOSTIC: After updateDownloadProgress()")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ UnifiedProgress: \(String(format: "%.3f", afterUnifiedProgress)) (\(Int(afterUnifiedProgress * 100))%)")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Phase: \(self.unifiedProgressEngine.currentPhase.displayName)")
//         // logger.info("🔗 RESILIENT_INTEGRATION: └─ Progress Movement: \(afterUnifiedProgress > 0.05 ? "✅ MOVED PAST 5% - GOOD!" : "⚠️ Still at 0-5% - investigating")")

//         updateProgress(progress.progress, status: "Downloading from iCloud... (\(Int(downloadProgress * 100))%)")
//     }
//     // MARK: - FUNC
//     private func handleTransferringPhase(_ progress: ResilientVideoLoader.VideoLoadingProgress) async {
//         // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 TRANSFERRING_PHASE: Forwarding to UnifiedProgressEngine")

//         unifiedProgressEngine.transitionToPhase(.transferring)

//         updateProgress(progress.progress, status: "Transferring video data...")
//     }
//     // MARK: - FUNC
//     private func handleValidatingPhase(_ progress: ResilientVideoLoader.VideoLoadingProgress) async {
//         // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 VALIDATING_PHASE: Forwarding to UnifiedProgressEngine")

//         unifiedProgressEngine.transitionToPhase(.validating)

//         updateProgress(progress.progress, status: "Validating video integrity...")
//     }
//     // MARK: - FUNC
//     private func handleCreatingAssetPhase(_ progress: ResilientVideoLoader.VideoLoadingProgress) async {
//         // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 CREATING_ASSET_PHASE: Forwarding to UnifiedProgressEngine")

//         unifiedProgressEngine.transitionToPhase(.creatingAsset)

//         updateProgress(progress.progress, status: "Creating video asset...")
//     }
//     // MARK: - FUNC
//     private func handleGeneratingThumbnailPhase(_ progress: ResilientVideoLoader.VideoLoadingProgress) async {
//         // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 GENERATING_THUMBNAIL_PHASE: Forwarding to UnifiedProgressEngine")

//         unifiedProgressEngine.transitionToPhase(.generatingThumbnail)

//         updateProgress(progress.progress, status: "Generating thumbnail...")
//     }
//     // MARK: - FUNC
//     private func handleLoadingTrimmerDurationPhase(_ progress: ResilientVideoLoader.VideoLoadingProgress) async {
//         // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 LOADING_TRIMMER_DURATION_PHASE: Forwarding to UnifiedProgressEngine")

//         unifiedProgressEngine.transitionToPhase(.loadingTrimmerDuration)

//         updateProgress(progress.progress, status: "Loading trimmer duration...")
//     }

//     private func handleLoadingTrimmerTracksPhase(_ progress: ResilientVideoLoader.VideoLoadingProgress) async {
//         // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 LOADING_TRIMMER_TRACKS_PHASE: Forwarding to UnifiedProgressEngine")

//         unifiedProgressEngine.transitionToPhase(.loadingTrimmerTracks)

//         updateProgress(progress.progress, status: "Loading trimmer tracks...")
//     }
//     // MARK: - FUNC
//     private func handleValidatingTrimmerPhase(_ progress: ResilientVideoLoader.VideoLoadingProgress) async {
//         // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 VALIDATING_TRIMMER_PHASE: Forwarding to UnifiedProgressEngine")

//         unifiedProgressEngine.transitionToPhase(.validatingTrimmer)

//         updateProgress(progress.progress, status: "Validating trimmer setup...")
//     }
//     // MARK: - FUNC
//     private func handleCompletedPhase(_ progress: ResilientVideoLoader.VideoLoadingProgress) async {
//         // logger.info("🔗 RESILIENT_INTEGRATION: ✅ COMPLETED_PHASE: Video loading completed successfully")

//         unifiedProgressEngine.transitionToPhase(.validatingTrimmer)
//         unifiedProgressEngine.completeLoading()

//         updateProgress(1.0, status: "Video loaded successfully")

//         // logger.info("🔗 RESILIENT_INTEGRATION: 🏆 SUCCESS: Complete progress flow executed successfully")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ iCloud → ResilientVideoLoader: ✅")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ ResilientVideoLoader → Integration: ✅")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Integration → UnifiedProgressEngine: ✅")
//         // logger.info("🔗 RESILIENT_INTEGRATION: └─ UnifiedProgressEngine → UI: ✅")
//     }
//     // MARK: - FUNC
//     private func handleErrorPhase(_ progress: ResilientVideoLoader.VideoLoadingProgress, error: Error) async {
//         logger.error("🔗 RESILIENT_INTEGRATION: ❌ ERROR_PHASE: Handling loading error")
//         logger.error("🔗 RESILIENT_INTEGRATION: ├─ Error: \(error.localizedDescription)")
//         logger.error("🔗 RESILIENT_INTEGRATION: └─ Correlation ID: \(progress.correlationId)")

//         let progressError = mapResilientErrorToProgressError(
//             error as? ResilientVideoLoader.ResilientVideoLoaderError ??
//             ResilientVideoLoader.ResilientVideoLoaderError.unknown(operationId: progress.correlationId, reason: error.localizedDescription)
//         )

//         unifiedProgressEngine.handleError(progressError)

//         updateProgress(progress.progress, status: "Loading failed: \(error.localizedDescription)")
//         currentError = error
//     }
//     // MARK: - FUNC
//     private func updateProgress(_ progress: Double, status: String) {
//         // 🚨 DATA_FLOW_INTEGRITY_FIX: REMOVED the line that overwrites unified progress
//         // REMOVED: loadingProgress = progress
//         // This prevents raw iCloud progress values from overriding the calculated unified progress
//         // The unified progress is now exclusively managed by UnifiedProgressEngine via Combine bindings

//         loadingStatus = status

//         //  COMPREHENSIVE_DIAGNOSTIC: Enhanced progress tracking with complete flow verification
//         // logger.info("🔗 RESILIENT_INTEGRATION:  PROGRESS_UPDATE: \(Int(progress * 100))% - '\(status)'")
//         // logger.info("🔗 RESILIENT_INTEGRATION: 🚨 DATA_FLOW_INTEGRITY: Raw iCloud progress received but NOT applied to loadingProgress")
//         // logger.info("🔗 RESILIENT_INTEGRATION:  PROGRESS_FLOW_VERIFICATION:")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Raw iCloud Progress: \(Int(progress * 100))% (IGNORED - prevents override)")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Unified Progress: \(String(format: "%.3f", self.unifiedProgressEngine.unifiedProgress)) (\(Int(self.unifiedProgressEngine.unifiedProgress * 100))%) [SSOT]")
//         // logger.info("🔗 RESILIENT_INTEGRATION: ├─ Unified Phase: \(self.unifiedProgressEngine.currentPhase.displayName)")
//         // logger.info("🔗 RESILIENT_INTEGRATION: └─ Complete Flow: iCloud → ResilientVideoLoader → UnifiedProgressEngine → UI (SSOT ENFORCED)")
//     }
//     // MARK: - FUNC
//     private func mapResilientErrorToProgressError(_ error: ResilientVideoLoader.ResilientVideoLoaderError) -> ProgressError {
//         switch error {
//         case .timeout(_, let duration):
//             return .timeout(duration: duration)
//         case .networkLost(_):
//             return .networkLost
//         case .maxRetriesExceeded(_, let attempts):
//             return .unknown("Max retries (\(attempts)) exceeded")
//         case .assetUnavailable(_, _):
//             return .assetUnavailable
//         case .permissionDenied(_):
//             return .permissionDenied
//         case .corruptedAsset(_, _):
//             return .corruptedFile
//         case .cancelled(_):
//             return .userCancelled
//         case .invalidAsset(_, let reason):
//             return .unknown("Invalid asset: \(reason)")
//         case .unknown(_, let reason):
//             return .unknown(reason)
//         }
//     }
//     // MARK: - FUNC
//     private func generateCorrelationId() -> String {
//         return "RVI-\(UUID().uuidString.prefix(8).uppercased())"
//     }
// }

// // MARK: - Static Factory Methods

// extension ResilientVideoLoaderIntegration {

//     /// Create integration instance with UnifiedProgressEngine
//     /// - Parameter unifiedProgressEngine: The progress engine to integrate with (required)
//     /// - Returns: Configured integration instance
//     // MARK: - FUNC
//     public static func createWithProgressEngine(_ unifiedProgressEngine: UnifiedProgressEngine) -> ResilientVideoLoaderIntegration {
//         return ResilientVideoLoaderIntegration(unifiedProgressEngine: unifiedProgressEngine)
//     }
// }

// // MARK: - Legacy Compatibility Extensions

// extension ResilientVideoLoaderIntegration {

//     /// Legacy compatibility method for ImportManager integration
//     /// - Parameters:
//     ///   - asset: PHAsset to load
//     ///   - options: PHVideoRequestOptions
//     ///   - correlationId: Optional correlation ID
//     /// - Returns: AVAsset if successful
//     // MARK: - FUNC
//     public func loadPHAssetWithProgress(
//         asset: PHAsset,
//         options: PHVideoRequestOptions,
//         correlationId: String = ""
//     ) async throws -> AVAsset {
//         // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 Legacy compatibility method called")
//         return try await requestAVAssetWithTimeout(for: asset, options: options, correlationId: correlationId)
//     }

//     /// Legacy compatibility method for AddMoveVideoLoader integration
//     /// - Parameters:
//     ///   - phAsset: PHAsset to load
//     ///   - options: PHVideoRequestOptions
//     ///   - correlationId: Optional correlation ID
//     /// - Returns: AVAsset if successful
//     // MARK: - FUNC
//     public func loadAVAsset(
//         phAsset: PHAsset,
//         options: PHVideoRequestOptions,
//         correlationId: String = ""
//     ) async throws -> AVAsset {
//         // logger.info("🔗 RESILIENT_INTEGRATION: 🔄 AddMoveVideoLoader compatibility method called")
//         return try await requestAVAssetWithTimeout(for: phAsset, options: options, correlationId: correlationId)
//     }
// }