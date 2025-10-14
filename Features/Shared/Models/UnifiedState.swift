import Foundation
import AVFoundation
import UIKit
import SwiftUI
import PhotosUI
import Combine

// MARK: - Movie Transferable
/// Simple transferable wrapper for movie files from Photos picker
struct VideoMovie: Transferable {
   let url: URL

   static var transferRepresentation: some TransferRepresentation {
       FileRepresentation(contentType: .movie) { movie in
           SentTransferredFile(movie.url)
       }
       importing: { received in
           let copy = URL.documentsDirectory.appending(path: "video_\(UUID().uuidString).mov")
           try FileManager.default.copyItem(at: received.file, to: copy)
           return Self(url: copy)
       }
   }
}

// MARK: - Add Move Unified State
/// Centralized state management for AddMove feature
/// Essentialist approach - only includes necessary properties
/// Conforms to ObservableObject for SwiftUI reactivity
public class AddMoveUnifiedState: ObservableObject {
   // MARK: - Tab Navigation
   @Published var currentTab: TabSelection = .ready
   @Published var flowState: AddMoveFlowState = .ready

   // MARK: - Video Data
   @Published var selectedVideo: AVAsset?
   @Published var originalVideoURL: URL?
   @Published var trimmedAsset: AVAsset?
   @Published var videoThumbnail: UIImage?

   // MARK: - Move Information
   @Published var moveName: String = ""
   @Published var moveDescription: String = ""
   @Published var moveCategory: String = ""
   @Published var tags: [String] = []

   // MARK: - Trimming Information
   @Published var trimStartTime: TimeInterval = 0.0
   @Published var trimEndTime: TimeInterval = 0.0
   var trimDuration: TimeInterval {
       return max(0.0, trimEndTime - trimStartTime)
   }

   // MARK: - Progress Tracking
   @Published var loadingProgress: VideoLoadingProgress = VideoLoadingProgress(phase: .idle, correlationId: "")
   @Published var processingProgress: Double = 0.0
   @Published var isProcessing: Bool = false

   // MARK: - Error Handling
   @Published var errorMessage: String?
   var hasError: Bool {
       return errorMessage != nil
   }

   // MARK: - Validation
   var isValidForSave: Bool {
       return !moveName.isEmpty &&
              trimmedAsset != nil &&
              !hasError &&
              trimDuration > 0.0
   }

   // MARK: - Initialization
   init() {
       Logger.addMove.info("AddMoveUnifiedState initialized with flowState: \(flowState)", emoji: "🎬")
       Logger.addMove.debug("Initial loading check - isLoading: \(flowState.isLoading)", emoji: "🔍")
   }

   // MARK: - State Updates
   func updateTab(_ newTab: TabSelection) {
       Task { @MainActor in
           self.currentTab = newTab
           Logger.addMove.logStateTransition(from: newTab, to: newTab, context: "Tab navigation")
       }
   }

   func updateFlowState(_ newState: AddMoveFlowState) {
       Task { @MainActor in
           self.flowState = newState
           Logger.addMove.logStateTransition(from: newState, to: newState, context: "Flow state")
       }
   }

   func setSelectedVideo(_ asset: AVAsset, url: URL?) async {
       await MainActor.run {
           self.selectedVideo = asset
           self.originalVideoURL = url
       }
       do {
           let duration = try await asset.load(.duration)
           await MainActor.run {
               self.trimEndTime = duration.seconds
           }
           Logger.addMove.info("Video selected: duration \(duration.seconds)s", emoji: "🎥")
       } catch {
           Logger.addMove.error("Failed to load video duration: \(error.localizedDescription)", emoji: "❌")
       }
   }

   func setTrimmedAsset(_ asset: AVAsset) async {
       await MainActor.run {
           self.trimmedAsset = asset
       }
       do {
           let duration = try await asset.load(.duration)
           Logger.addMove.info("Video trimmed: duration \(duration.seconds)s", emoji: "✂️")
       } catch {
           Logger.addMove.error("Failed to load trimmed video duration: \(error.localizedDescription)", emoji: "❌")
       }
   }

   func updateProgress(_ progress: VideoLoadingProgress) {
       Task { @MainActor in
           self.loadingProgress = progress

           // CRITICAL FIX: Ensure state synchronization happens reliably on MainActor
           let newFlowState = progress.state.toAddMoveFlowState
           if self.flowState != newFlowState {
               let previousState = self.flowState
               self.flowState = newFlowState
               Logger.addMove.info("ENHANCED STATE SYNC: Auto-updating flowState from \(previousState) to \(newFlowState) based on loading progress", emoji: "🔄")

               // CRITICAL: Log state transition completion for debugging
               Logger.addMove.info("✅ FLOW STATE TRANSITION COMPLETE: \(previousState) → \(newFlowState), isLoading: \(newFlowState.isLoading)", emoji: "🎯")
           }

           // ENHANCED: Additional logging for completion state
           if progress.phase == .completed || progress.phase == .complete {
               Logger.addMove.info("🎯 COMPLETION DETECTED: Video loading completed - ensuring all components are synchronized", emoji: "✅")

               // Schedule verification check to ensure state consistency
               DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                   Logger.addMove.info("🔍 POST-COMPLETION VERIFICATION: flowState=\(self.flowState), isLoading=\(self.flowState.isLoading), hasVideo=\(self.selectedVideo != nil)", emoji: "🔍")
               }
           }
       }
   }

   func updateProcessingProgress(_ progress: Double) {
       Task { @MainActor in
           self.processingProgress = progress
       }
   }

   func setError(_ message: String) {
       Task { @MainActor in
           self.errorMessage = message
       }
       Logger.addMove.error("Error set: \(message)", emoji: "❌")
   }

   func clearError() {
       Task { @MainActor in
           self.errorMessage = nil
       }
       Logger.addMove.debug("Error cleared", emoji: "🧹")
   }

   /// Process video trim from start time to end time
   func processTrim(from startTime: CMTime, to endTime: CMTime) async throws -> AVAsset {
       Logger.addMove.info("Processing trim: \(startTime.seconds)s - \(endTime.seconds)s", emoji: "✂️")

       // For now, just return the original asset
       // In a real implementation, this would perform actual trimming
       guard let originalAsset = selectedVideo else {
           throw NSError(domain: "VideoTrimming", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video asset available for trimming"])
       }

       // Update the trimmed asset
       await setTrimmedAsset(originalAsset)

       // Update trim times
       await MainActor.run {
           self.trimStartTime = startTime.seconds
           self.trimEndTime = endTime.seconds
       }

       Logger.addMove.info("Trim processed successfully", emoji: "✅")
       return originalAsset
   }

   func loadVideo(from item: PhotosUI.PhotosPickerItem) async {
       // Generate unified correlation ID for this entire loading operation
       let unifiedCorrelationId = "LOAD-\(UUID().uuidString.prefix(8))"
       Logger.addMove.info("Loading video from PhotosPicker [\(unifiedCorrelationId)]")

       await MainActor.run {
           self.updateFlowState(.loadingVideo)
           self.clearError()
       }

       let maxRetries = 3
       var retryCount = 0
       var lastError: Error?

       // CRITICAL FIX: Create operation manager once and coordinate with VideoLoadingService
       let operationManager = await VideoLoadingOperationManager()
       await operationManager.setupCoordination(unifiedState: self)

       let videoLoadingService = await VideoLoadingService()

       // Set up coordination - this connects VideoLoadingService to UnifiedState and OperationManager
       await videoLoadingService.setupCoordination(unifiedState: self, operationManager: operationManager)

       while retryCount < maxRetries {

           // Pass unified correlation ID to VideoLoadingService for consistent tracking
           await videoLoadingService.setUnifiedCorrelationId(unifiedCorrelationId)

           // Initialize progress with unified correlation ID
           let initialProgress = VideoLoadingProgress(phase: .initializing, correlationId: unifiedCorrelationId)
           updateProgress(initialProgress)

           do {
               let result = try await videoLoadingService.loadVideo(from: item)

               // CRITICAL FIX: Set video asset first, then update completion state
               await setSelectedVideo(result.asset, url: result.temporaryFileURL)

               // Explicit completion progress update to ensure TrimmerView updates
               let completionProgress = VideoLoadingProgress(phase: .completed, correlationId: unifiedCorrelationId)
               updateProgress(completionProgress)

               updateFlowState(.trimming)
               updateTab(.trimming)

               Logger.addMove.info("Video loaded successfully: \(result.filename)")
               await videoLoadingService.cleanupTemporaryFiles()
               return

           } catch {
               lastError = error
               retryCount += 1
               await videoLoadingService.cleanupTemporaryFiles()

               if retryCount < maxRetries {
                   let retryDelay = calculateRetryDelay(retryCount)
                   Logger.addMove.warning("Video loading failed, retrying in \(retryDelay)s (attempt \(retryCount)/\(maxRetries))")

                   try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
               }
           }
       }

       // All retries failed - provide graceful degradation
       setError("Failed to load video after \(maxRetries) attempts: \(lastError?.localizedDescription ?? "Unknown error")")
       updateFlowState(.error("Loading failed", lastError?.localizedDescription ?? "Unknown error"))
       Logger.addMove.error("Video loading failed after \(maxRetries) attempts: \(lastError?.localizedDescription ?? "Unknown error")")
   }

   /// Calculates retry delay with exponential backoff
   private func calculateRetryDelay(_ attempt: Int) -> TimeInterval {
       let baseDelay: TimeInterval = 1.0
       let maxDelay: TimeInterval = 8.0
       let delay = baseDelay * pow(2.0, Double(attempt - 1))
       return min(delay, maxDelay)
   }

   func reset() {
       Task { @MainActor in
           self.currentTab = .ready
           self.flowState = .loading
           self.selectedVideo = nil
           self.originalVideoURL = nil
           self.trimmedAsset = nil
           self.videoThumbnail = nil
           self.moveName = ""
           self.moveDescription = ""
           self.moveCategory = ""
           self.tags = []
           self.trimStartTime = 0.0
           self.trimEndTime = 0.0
           self.loadingProgress = VideoLoadingProgress(phase: .idle, correlationId: "")
           self.processingProgress = 0.0
           self.isProcessing = false
           self.errorMessage = nil
       }
       Logger.addMove.info("State reset to initial values", emoji: "🔄")
   }
}

// MARK: - Computed Properties
extension AddMoveUnifiedState {
   /// Check if video is loaded and ready for trimming
   var isVideoReady: Bool {
       return selectedVideo != nil && !flowState.isLoading
   }

   /// Check if trimming is complete
   var isTrimmingComplete: Bool {
       return trimmedAsset != nil && trimDuration > 0.0
   }

   /// Check if move information is complete
   var isMoveInfoComplete: Bool {
       return !moveName.isEmpty
   }

   /// Current video duration
   var currentVideoDuration: TimeInterval {
       get async {
           guard let asset = selectedVideo else { return 0.0 }
           do {
               let duration = try await asset.load(.duration)
               return duration.seconds
           } catch {
               Logger.addMove.error("Failed to load video duration: \(error.localizedDescription)", emoji: "❌")
               return 0.0
           }
       }
   }

   /// Current video duration in seconds (compatibility)
   var currentVideoDurationSeconds: Double {
       get async {
           return await currentVideoDuration
       }
   }

   /// Current video asset (compatibility)
   var currentVideoAsset: AVAsset? {
       return selectedVideo
   }

   /// Progress for current operation
   var currentProgress: Double {
       if isProcessing {
           return processingProgress
       } else {
           return loadingProgress.progress
       }
   }
}

// MARK: - Video Player View Model Compatibility
/// Compatibility shim for UnifiedVideoPlayerViewModel
/// Simple wrapper that provides basic video player functionality
typealias UnifiedVideoPlayerViewModel = SimpleVideoPlayerViewModel

class SimpleVideoPlayerViewModel: ObservableObject {
   let asset: AVAsset?
   @Published var isPlaying: Bool = false
   @Published var currentTime: TimeInterval = 0.0
   @Published var duration: TimeInterval = 0.0

   init(asset: AVAsset? = nil) {
       self.asset = asset
       self.duration = 0.0 // Will be loaded asynchronously when needed
   }

   /// Load duration asynchronously
   func loadDuration() async {
       guard let asset = asset else { return }
       do {
           let loadedDuration = try await asset.load(.duration)
           await MainActor.run {
               self.duration = loadedDuration.seconds
           }
       } catch {
           Logger.addMove.error("Failed to load video duration: \(error.localizedDescription)", emoji: "❌")
       }
   }
}