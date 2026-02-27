// VideoPickerSheet.swift — Photo library video picker (UIKit bridge)
//
// This file wraps Apple's PHPickerViewController (UIKit) as a SwiftUI view using
// the UIViewControllerRepresentable protocol. It lets the user select a single
// video from their Photos library and returns the video as a local file URL.
//
// WHY UIViewControllerRepresentable?
//   SwiftUI's built-in PhotosPicker doesn't provide download progress callbacks
//   for iCloud-stored videos. PHPickerViewController + PHAssetResourceManager
//   gives us byte-level progress tracking, which is essential for large videos
//   that may take minutes to download from iCloud.
//
// TWO DOWNLOAD PATHS:
//   1. PHAsset path (preferred): If the picked result has an assetIdentifier,
//      we can fetch the actual PHAsset and use PHAssetResourceManager.writeData()
//      which provides a progressHandler callback. This is the path used for
//      iCloud-hosted videos where download progress matters.
//
//   2. ItemProvider fallback: If no PHAsset is available (e.g. limited Photos
//      access, or the item was provided through a different mechanism), we fall
//      back to NSItemProvider.loadFileRepresentation() which doesn't report
//      progress but still copies the video to a local file.
//
// DATA FLOW:
//   The picker communicates back to its parent (AddMoveView) via four @Binding properties:
//   - selectedURL: The final local file URL of the video (set when download completes)
//   - downloadProgress: 0.0 to 1.0 progress fraction (for the loading state UI)
//   - downloadStatus: Human-readable text ("Downloading from Photos...", "Finalizing...")
//   - downloadStart: Timestamp of when the download began (used for ETA calculation)
//
//   AddMoveView monitors these bindings via .onChange modifiers and translates them
//   into its state machine (.loadingVideo → .previewing).
//
// FILE HANDLING:
//   Downloaded/copied videos are saved to the app's Documents directory with UUID filenames.
//   The original file extension is preserved (.mov, .mp4, etc.) for proper playback.
//   These are temporary copies — AddMoveView's saveMove() will copy them to the
//   permanent Documents/Moves/ directory and clean up the temporaries.
//
// IMPORTANT iOS PERMISSIONS:
//   This picker uses PHPickerViewController which does NOT require explicit photo library
//   permission (NSPhotoLibraryUsageDescription). The system-managed picker handles
//   privacy automatically. However, when we access PHAsset directly for progress tracking,
//   we need limited or full Photos access. If access is denied, the fallback path is used.

import SwiftUI              // SwiftUI framework — for @Binding and the UIViewControllerRepresentable protocol
import PhotosUI             // PhotosUI — provides PHPickerViewController, PHPickerConfiguration, PHPickerResult
import UniformTypeIdentifiers // UniformTypeIdentifiers — provides UTType.movie for video type filtering
import Photos               // Photos framework — provides PHAsset, PHAssetResource, PHAssetResourceManager
                             // for accessing the underlying photo library asset with download progress

// MARK: - VideoPickerSheet

/// A UIViewControllerRepresentable that wraps PHPickerViewController to present
/// the system photo/video picker. Configured to only show videos and allow
/// single selection. Communicates results back via bindings.
struct VideoPickerSheet: UIViewControllerRepresentable {

    // -------------------------------------------------------------------------
    // MARK: Bindings (communication channel to parent)
    // -------------------------------------------------------------------------

    /// The local file URL of the selected and downloaded video.
    /// Set to a Documents-directory URL once the video has been fully downloaded/copied.
    /// The parent view (AddMoveView) monitors this via .onChange to trigger video loading.
    @Binding var selectedURL: URL?

    /// Download progress from 0.0 to 1.0.
    /// Updated by PHAssetResourceManager's progressHandler during iCloud downloads.
    /// The parent view converts this into a visual progress ring.
    @Binding var downloadProgress: Double

    /// Human-readable status text describing the current download phase.
    /// Values: nil (not started), "Downloading from Photos...", "Finalizing...", "Processing..."
    @Binding var downloadStatus: String?

    /// Timestamp of when the download started.
    /// Used by the parent view to calculate ETA: remaining = (elapsed / progress) - elapsed.
    @Binding var downloadStart: Date?

    // -------------------------------------------------------------------------
    // MARK: UIViewControllerRepresentable Protocol
    // -------------------------------------------------------------------------

    /// Creates and configures the PHPickerViewController.
    ///
    /// Configuration:
    /// - filter: .videos — only show videos, not photos or Live Photos
    /// - preferredAssetRepresentationMode: .current — don't transcode, use the original format.
    ///   This is important for preserving video quality and avoiding unnecessary processing.
    /// - selectionLimit: 1 — only allow picking a single video at a time
    ///
    /// The picker's delegate is set to our Coordinator, which handles the selected result.
    ///
    /// - Parameter context: The UIViewControllerRepresentable context (provides the coordinator).
    /// - Returns: A configured PHPickerViewController ready to present.
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos                            // Only show videos in the picker
        config.preferredAssetRepresentationMode = .current // Use original format (no transcoding)
        config.selectionLimit = 1                          // Single selection only
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator              // Delegate to our Coordinator for result handling
        return picker
    }

    /// Called when SwiftUI needs to update the UIViewController.
    /// No updates needed — the picker is fully configured at creation time.
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    /// Creates the Coordinator that serves as the PHPickerViewControllerDelegate.
    /// The Coordinator handles the delegate callback when the user picks a video or cancels.
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // =========================================================================
    // MARK: - Coordinator (Delegate)
    // =========================================================================

    /// The Coordinator class acts as the PHPickerViewControllerDelegate.
    /// It receives the picker's result (the user's video selection) and orchestrates
    /// the download/copy pipeline. Inherits from NSObject as required by UIKit delegates.
    class Coordinator: NSObject, PHPickerViewControllerDelegate {

        /// Reference to the parent VideoPickerSheet for accessing the @Binding properties.
        /// This is how the Coordinator communicates progress and results back to SwiftUI.
        let parent: VideoPickerSheet

        /// Initializes the coordinator with a reference to its parent VideoPickerSheet.
        /// - Parameter parent: The VideoPickerSheet instance that owns this coordinator.
        init(_ parent: VideoPickerSheet) {
            self.parent = parent
        }

        /// Called by the system when the user finishes picking (selects a video or cancels).
        ///
        /// This is the main entry point for handling the picked video. It implements
        /// two download strategies:
        ///
        /// **Strategy 1: PHAsset path (preferred)**
        /// If the result has an assetIdentifier, we fetch the PHAsset directly and use
        /// PHAssetResourceManager.writeData() to download the full video to disk.
        /// This path provides progress callbacks for iCloud-hosted videos.
        ///
        /// **Strategy 2: ItemProvider fallback**
        /// If no PHAsset is available (limited access or non-standard source), we use
        /// NSItemProvider.loadFileRepresentation() which copies the file without progress.
        ///
        /// - Parameters:
        ///   - picker: The PHPickerViewController that was presented.
        ///   - results: Array of PHPickerResult objects (0 if cancelled, 1 if video selected).
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Dismiss the picker immediately — the download continues in the background.
            // The parent view will show a progress indicator while downloading.
            picker.dismiss(animated: true)

            // If the user cancelled (tapped outside or pressed cancel), results is empty.
            // Early return — no action needed.
            guard let result = results.first else { return }

            // ===================================================================
            // Strategy 1: PHAsset path — accurate download progress for iCloud videos
            // ===================================================================

            // Check if the picked result has an assetIdentifier (available when the app
            // has at least limited photo library access). If so, we can fetch the PHAsset
            // and use PHAssetResourceManager for a progress-tracked download.
            if let assetId = result.assetIdentifier,
               let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil).firstObject {

                // Get the list of resources (files) associated with this PHAsset.
                // A video asset typically has a .video or .fullSizeVideo resource.
                let resources = PHAssetResource.assetResources(for: asset)

                // Find the best video resource: prefer .fullSizeVideo (edited/highest quality),
                // fall back to .video (original), then take whatever is first as a last resort.
                guard let videoResource = resources.first(where: { $0.type == .fullSizeVideo || $0.type == .video }) ?? resources.first else {
                    return   // No usable resource found — silently fail
                }

                // Prepare the destination path in the Documents directory.
                // Uses a UUID filename to prevent collisions, preserving the original extension.
                let fileManager = FileManager.default
                let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let ext = (videoResource.originalFilename as NSString).pathExtension  // Extract original extension
                let destinationURL = documentsDirectory.appendingPathComponent(UUID().uuidString + (ext.isEmpty ? ".mov" : "." + ext))

                // Configure the download request options
                let options = PHAssetResourceRequestOptions()
                options.isNetworkAccessAllowed = true   // Allow downloading from iCloud (essential!)

                // Progress handler — called repeatedly during iCloud downloads.
                // Reports a Double from 0.0 to 1.0. We forward this to the parent's binding
                // so AddMoveView can show the progress ring with ETA.
                options.progressHandler = { [weak self] progress in
                    DispatchQueue.main.async {
                        // Set the download start time on the first progress callback
                        if self?.parent.downloadStart == nil { self?.parent.downloadStart = Date() }
                        // Update progress and status bindings
                        self?.parent.downloadProgress = progress
                        self?.parent.downloadStatus = progress < 1.0 ? "Downloading from Photos..." : "Finalizing..."
                    }
                }

                // Initialize progress tracking state before starting the download.
                // Setting downloadProgress to 0.01 (not 0) signals to the parent that
                // a download has begun, even before the first progress callback fires.
                parent.downloadStart = Date()
                parent.downloadStatus = "Downloading from Photos..."
                parent.downloadProgress = 0.01

                // Start the download. PHAssetResourceManager.writeData() streams the video
                // data directly to the destination file, calling the progress handler as it goes.
                // This is an asynchronous operation — the completion handler fires when done.
                PHAssetResourceManager.default().writeData(for: videoResource, toFile: destinationURL, options: options) { [weak self] error in
                    if let error = error {
                        // Download failed — log and silently fail.
                        // TODO: Could surface this error to the parent via a binding.
                        print("DEBUG: Failed to write asset data: \(error)")
                        return
                    }
                    // Download complete — update bindings on the main thread.
                    // Setting selectedURL triggers .onChange(of: selectedVideoURL) in AddMoveView,
                    // which dismisses the picker and tells MediaManager to load the video.
                    DispatchQueue.main.async {
                        self?.parent.downloadProgress = 1.0         // Mark as fully downloaded
                        self?.parent.downloadStatus = "Processing..." // Status during MediaManager load
                        self?.parent.selectedURL = destinationURL    // Signal completion to parent
                    }
                }
                // Early return — we've handled this via the PHAsset path
                return
            }

            // ===================================================================
            // Strategy 2: ItemProvider fallback — no progress tracking
            // ===================================================================

            // If we can't get a PHAsset (limited access, or system didn't provide one),
            // fall back to NSItemProvider. This works for all cases but doesn't give us
            // download progress for iCloud videos.
            let provider = result.itemProvider

            // Verify the item provider can provide a movie file
            guard provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else { return }

            // loadFileRepresentation writes the video to a temporary file and gives us its URL.
            // The temporary file is only valid during this callback — we must copy it to
            // a persistent location before the callback returns.
            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
                if let error = error { print("DEBUG: Error loading file representation: \(error)"); return }
                guard let url = url else { return }

                // Copy the temporary file to the Documents directory with a UUID filename.
                // The temporary file will be deleted by the system after this callback,
                // so we must copy (not move) it to a persistent location.
                let fileManager = FileManager.default
                let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let destinationURL = documentsDirectory.appendingPathComponent(UUID().uuidString + "." + url.pathExtension)

                do {
                    // Remove any existing file at the destination (unlikely with UUID names)
                    if fileManager.fileExists(atPath: destinationURL.path) { try fileManager.removeItem(at: destinationURL) }
                    // Copy the temporary file to its permanent location
                    try fileManager.copyItem(at: url, to: destinationURL)
                    // Signal completion to the parent view
                    DispatchQueue.main.async {
                        self?.parent.selectedURL = destinationURL
                    }
                } catch {
                    print("DEBUG: File copy failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Preview
// Note: PHPickerViewController requires a live Photos library, so previews show the
// system picker UI with no selectable content. Useful for verifying the sheet presents.

#Preview("VideoPicker - Light") {
    VideoPickerSheet(
        selectedURL: .constant(nil),
        downloadProgress: .constant(0),
        downloadStatus: .constant(""),
        downloadStart: .constant(nil)
    )
}

#Preview("VideoPicker - Dark") {
    VideoPickerSheet(
        selectedURL: .constant(nil),
        downloadProgress: .constant(0),
        downloadStatus: .constant(""),
        downloadStart: .constant(nil)
    )
    .preferredColorScheme(.dark)
}
