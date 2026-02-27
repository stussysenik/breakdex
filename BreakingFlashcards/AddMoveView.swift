// AddMoveView.swift — Main "add a new breakdancing move" flow
//
// This view is the primary entry point for recording a new move into the user's
// Breakdex arsenal. It implements a finite state machine with 7 distinct states:
//
//   .ready ──> .loadingVideo ──> .previewing ──> .trimming ──> .naming ──> .saving ──> .success
//                    │                │                                        │
//                    └── .error ◄─────┴────────────────────────────────────────┘
//
// STATE MACHINE FLOW:
//   1. .ready         — Initial state. "Select a Clip" button opens the photo picker.
//   2. .loadingVideo  — Video is downloading from iCloud Photos or being loaded from disk.
//                       Shows a circular progress ring with ETA calculation.
//   3. .previewing    — Video loaded. User sees a preview and can choose:
//                       "Change Video", "Edit Video", or "Use Original".
//   4. .trimming      — Full VideoEditorView for trimming, speed, rotation, crop.
//                       Returns either an edited URL (proceed) or nil (go back).
//   5. .naming        — User enters a name for the move. Optional AI suggestion button.
//                       Back/Edit buttons allow revisiting previous steps.
//   6. .saving        — Video file is being copied to Documents/Moves/ and the SwiftData
//                       Move model is being persisted. Runs on background queue.
//   7. .success       — Confirmation screen with option to add another move.
//   8. .error         — Catch-all error state shown if anything fails along the way.
//
// ARCHITECTURE NOTES:
//   - Uses MediaManager (singleton) to handle async video loading with progress tracking.
//   - VideoPickerSheet (UIViewControllerRepresentable) wraps PHPickerViewController.
//   - The picker reports download progress via bindings, which this view monitors
//     through .onChange(of:) modifiers and converts to the .loadingVideo state.
//   - Video files are saved to Documents/Moves/ with a UUID filename. The SwiftData
//     Move model stores a relative path ("Moves/UUID.mp4") as UTF-8 Data.
//   - All transitions between states are animated using AppMotion.easeState (0.3s ease).
//   - AI name suggestion (iOS 26+) uses on-device Foundation Models if available.
//
// DATA MODEL INTERACTION:
//   - Creates a new Move (SwiftData @Model) with the user's chosen name.
//   - Sets learningState to "NEW" (the beginning of the spaced repetition cycle).
//   - Stores the video reference as a relative file path encoded as UTF-8 Data.
//
// DESIGN SYSTEM USAGE:
//   - Color.backgroundPrimary: full-screen background behind all states
//   - Font.ibmPlexMono: all text uses the IBM Plex Mono typeface
//   - Spacing.md/sm: consistent spacing between UI elements (16pt/8pt)
//   - Radius.md/sm: corner radii for video player and text field (12pt/6pt)
//   - AppMotion.easeState: 0.3s ease-in-out for state transitions
//   - AppMotion.springQuick: bouncy spring for progress ring animation

import SwiftUI   // SwiftUI framework — provides all View types, property wrappers, and modifiers
import AVKit     // AVKit — provides AVPlayer, AVPlayerItem, AVAsset for video playback
import SwiftData // SwiftData — provides @Model, ModelContext for persistence

// MARK: - AddMoveView

/// The main "Add Move" screen. Presented as a tab in MainView.
/// Drives the user through a multi-step flow: pick video -> preview -> edit -> name -> save.
struct AddMoveView: View {

    // -------------------------------------------------------------------------
    // MARK: Environment & Observed Objects
    // -------------------------------------------------------------------------

    /// SwiftData model context — injected by the .modelContainer() modifier up the view hierarchy.
    /// Used in saveMove() to insert the new Move into the database.
    @Environment(\.modelContext) private var modelContext

    /// AppSettings for category definitions (names + colors).
    @Environment(AppSettings.self) private var appSettings

    /// MediaManager is a singleton (@ObservedObject, not @StateObject, because it's shared).
    /// It handles async video loading with a multi-stage pipeline (file header → duration →
    /// tracks → metadata → audio → cache). Publishes its status via @Published var status.
    @ObservedObject private var mediaManager = MediaManager.shared

    // -------------------------------------------------------------------------
    // MARK: State Machine Definition
    // -------------------------------------------------------------------------

    /// All possible states the AddMoveView can be in. This enum is Equatable so that
    /// SwiftUI's .animation(_:value:) modifier can detect state changes and animate them.
    ///
    /// Associated values carry the data each state needs to render:
    /// - .loadingVideo: progress (0.0–1.0), human-readable status text, optional ETA string
    /// - .previewing: the loaded AVAsset and its file URL for playback
    /// - .trimming: same asset/URL passed to VideoEditorView for editing
    /// - .naming: the final video URL (after edit), the entered name, and optionally the
    ///   original asset/URL so the user can navigate back to preview or re-edit
    /// - .success/.error: a message string to display
    enum AddMoveState: Equatable {
        case ready                                                                  // Initial state — "Select a Clip" button
        case loadingVideo(progress: Double, status: String, eta: String?)           // Downloading/loading video with progress
        case previewing(asset: AVAsset, url: URL)                                   // Video loaded, showing preview player
        case trimming(asset: AVAsset, url: URL)                                     // Full video editor (trim, speed, rotation, crop)
        case naming(finalURL: URL, name: String, originalAsset: AVAsset?, originalURL: URL?)  // Name entry step
        case saving                                                                 // Background save in progress
        case success(message: String)                                               // Save succeeded — confirmation
        case error(message: String)                                                 // Something went wrong — error display
    }

    // -------------------------------------------------------------------------
    // MARK: State Properties
    // -------------------------------------------------------------------------

    /// The current state of the state machine. Changes to this value trigger
    /// animated transitions via .animation(AppMotion.easeState, value: currentState).
    @State private var currentState: AddMoveState = .ready

    /// Controls whether the VideoPickerSheet (PHPickerViewController wrapper) is presented.
    /// Set to true when user taps "Select a Clip" or "Change Video".
    @State private var isPickerPresented = false

    /// The user-entered name for the move. Bound to the TextField in the naming state.
    /// Reset to "" when the user starts over or saves successfully.
    @State private var moveName: String = ""

    /// The URL selected by the VideoPickerSheet. When this changes (via .onChange),
    /// the view dismisses the picker and tells MediaManager to load the video.
    @State private var selectedVideoURL: URL?

    /// Download progress reported by VideoPickerSheet when downloading iCloud videos.
    /// Range: 0.0 to 1.0. Monitored via .onChange to update the .loadingVideo state.
    @State private var pickerDownloadProgress: Double = 0

    /// Human-readable download status text from VideoPickerSheet (e.g. "Downloading from Photos...")
    @State private var pickerDownloadStatus: String? = nil

    /// Timestamp when the download started. Used together with progress to compute ETA.
    @State private var pickerDownloadStart: Date? = nil

    /// Focus state for the move name TextField. Automatically focused 0.4s after
    /// the naming state appears, so the keyboard slides up without jarring the transition.
    @FocusState private var isNameFieldFocused: Bool

    /// Tracks whether the AI name suggestion is currently generating.
    /// While true, the sparkles button shows a ProgressView spinner and is disabled.
    @State private var isAISuggesting = false

    /// The selected category for the new move. Defaults to "MOVE".
    @State private var selectedCategory: String = "MOVE"

    /// Controls whether the new category creation alert is shown.
    @State private var isCreatingCategory = false

    /// Text field for the new category name.
    @State private var newCategoryName = ""

    /// Cycles through CategoryPalette colors for new category creation.
    @State private var newCategoryColorIndex = 0

    // -------------------------------------------------------------------------
    // MARK: ETA Helpers
    // -------------------------------------------------------------------------

    /// Computes an estimated time of arrival string based on elapsed time and progress.
    ///
    /// Uses a simple linear extrapolation: if we're X% done after Y seconds,
    /// total time = Y / X, so remaining = (Y / X) - Y.
    ///
    /// - Parameters:
    ///   - elapsed: Seconds since the download started (Date().timeIntervalSince(start)).
    ///   - progress: Current progress fraction (0.0 to 1.0).
    /// - Returns: A formatted string like "ETA: 1m 23s" or "ETA: ~2m" if too early to estimate.
    private func etaText(elapsed: TimeInterval, progress: Double) -> String {
        // If progress is below 5%, the estimate would be wildly inaccurate — show a placeholder
        guard progress > 0.05 else { return "ETA: ~2m" }
        // Linear extrapolation: total_time = elapsed / progress, remaining = total - elapsed
        let remaining = max(0, (elapsed / progress) - elapsed)
        return "ETA: \(formatDuration(remaining))"
    }

    /// Formats a duration in seconds into a human-readable string.
    ///
    /// - Less than 60s: "42s"
    /// - Less than 1h: "2m 15s"
    /// - 1h or more: "1h 23m"
    ///
    /// - Parameter seconds: The duration to format, in seconds.
    /// - Returns: A compact human-readable duration string.
    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return "\(Int(seconds))s" }
        let m = Int(seconds) / 60, s = Int(seconds) % 60
        return seconds < 3600 ? "\(m)m \(s)s" : "\(Int(seconds) / 3600)h \(m % 60)m"
    }

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    /// The main view body. Structured as a ZStack with a full-screen background color
    /// and a VStack that switches between different sub-views based on currentState.
    var body: some View {
        ZStack {
            // Full-screen background using the design system's primary background color.
            // .ignoresSafeArea() ensures it extends under the status bar and home indicator.
            Color.backgroundPrimary.ignoresSafeArea()

            // Main content container. The switch statement renders exactly one sub-view
            // at a time, determined by the current state of the state machine.
            VStack {
                switch currentState {

                // STATE: Ready — show the "Select a Clip" button and file format hint
                case .ready:
                    readyState

                // STATE: Loading — show circular progress ring, status text, and ETA
                case .loadingVideo(let progress, let status, let eta):
                    loadingState(progress: progress, status: status, eta: eta)

                // STATE: Previewing — show video player with Change/Edit/Use Original buttons
                case .previewing(let asset, let url):
                    previewState(asset: asset, url: url)

                // STATE: Trimming — delegate to the full VideoEditorView.
                // When the editor finishes, it calls onComplete with either:
                //   - a URL (user saved edits) → transition to .naming with the edited URL
                //   - nil (user cancelled) → transition back to .previewing
                case .trimming(let asset, let url):
                    VideoEditorView(asset: asset) { editedURL in
                        if let finalURL = editedURL {
                            // User saved edits — move to naming step with the exported video URL.
                            // Preserve the original asset/URL so Back button can return to preview.
                            currentState = .naming(finalURL: finalURL, name: "", originalAsset: asset, originalURL: url)
                        } else {
                            // User cancelled editing — return to the preview state
                            currentState = .previewing(asset: asset, url: url)
                        }
                    }

                // STATE: Naming — show video preview, name text field, and save button.
                // The underscore ignores the `name` associated value because we use @State moveName instead.
                case .naming(let finalURL, _, let originalAsset, let originalURL):
                    namingState(finalURL: finalURL, originalAsset: originalAsset, originalURL: originalURL)

                // STATE: Saving — show spinner and "Adding to your arsenal..." text
                case .saving:
                    savingState

                // STATE: Success — show checkmark and "Add Another Move" button
                case .success(let message):
                    successState(message: message)

                // STATE: Error — show warning icon, error message, and retry buttons
                case .error(let message):
                    errorState(message: message)
                }
            }
        }
        // Animate all state transitions with a smooth 0.3s ease-in-out curve.
        // The `value: currentState` tells SwiftUI to re-evaluate the animation
        // whenever currentState changes (which it can, because AddMoveState is Equatable).
        .animation(AppMotion.easeState, value: currentState)

        // Subscribe to MediaManager's published status. When MediaManager finishes
        // loading a video (or fails), this callback maps its status to our state machine.
        // This is the bridge between the async media pipeline and our UI state.
        .onReceive(mediaManager.$status) { status in
            switch status {
            case .idle:
                // MediaManager is idle — no action needed (e.g. app just launched)
                break
            case .loading(let progress, let statusText, let eta):
                // MediaManager is actively loading — mirror its progress in our state
                currentState = .loadingVideo(progress: progress, status: statusText, eta: eta)
            case .loaded(let asset, let url):
                // MediaManager finished loading — transition to preview
                currentState = .previewing(asset: asset, url: url)
            case .failed(let error):
                // MediaManager encountered an error — show error state
                currentState = .error(message: error.localizedDescription)
            }
        }

        // Present the VideoPickerSheet as a modal sheet.
        // VideoPickerSheet wraps PHPickerViewController (UIKit) via UIViewControllerRepresentable.
        // It writes back to selectedVideoURL, downloadProgress, downloadStatus, and downloadStart.
        .sheet(isPresented: $isPickerPresented) {
            VideoPickerSheet(selectedURL: $selectedVideoURL, downloadProgress: $pickerDownloadProgress, downloadStatus: $pickerDownloadStatus, downloadStart: $pickerDownloadStart)
        }

        // Monitor the download progress reported by VideoPickerSheet.
        // When an iCloud video is being downloaded, PHAssetResourceManager reports progress
        // through the binding. We convert this into our .loadingVideo state with ETA.
        .onChange(of: pickerDownloadProgress) { progress in
            // Ignore zero progress (initial state or reset)
            guard progress > 0 else { return }
            // Use the status text from the picker, or fall back to a default message
            let status = pickerDownloadStatus ?? "Downloading from Photos..."
            if let start = pickerDownloadStart, progress > 0, progress < 0.999 {
                // We have a start time and download is in progress — compute ETA
                let elapsed = Date().timeIntervalSince(start)
                // Cap progress at 95% to avoid showing 100% before MediaManager finishes
                currentState = .loadingVideo(progress: min(progress, 0.95), status: status, eta: etaText(elapsed: elapsed, progress: progress))
            } else {
                // Either no start time or download just started — show "Calculating..."
                currentState = .loadingVideo(progress: min(progress, 0.95), status: status, eta: "Calculating...")
            }
        }

        // Monitor when the VideoPickerSheet sets a selected URL.
        // This fires after the video has been downloaded/copied to a local file.
        .onChange(of: selectedVideoURL) { newURL in
            guard let url = newURL else { return }
            // Dismiss the picker sheet
            isPickerPresented = false
            // Hand the local file URL to MediaManager for full asset loading
            // (validates playability, loads tracks, caches the asset)
            mediaManager.loadVideo(from: url)
        }
    }

    // =========================================================================
    // MARK: - State Views
    // =========================================================================
    // Each state in the state machine has its own sub-view, extracted as computed
    // properties or methods for readability. Each uses design system tokens for
    // consistent styling (Font.ibmPlexMono, Spacing.md, Color.textPrimary, etc.).

    // -------------------------------------------------------------------------
    // MARK: Ready State
    // -------------------------------------------------------------------------

    /// The initial state view. Shows a prominent "Select a Clip" button and a hint
    /// about supported file formats. This is what the user sees when they first
    /// navigate to the Add Move tab.
    private var readyState: some View {
        VStack(spacing: Spacing.md) {
            // Primary call-to-action button
            Button("Select a Clip") {
                isPickerPresented = true
            }
            .primaryAction()
            .padding(.horizontal, Spacing.screenEdge)
            .accessibilityIdentifier("SelectClipButton")

            Text("Supports .mp4, .mov files")
                .font(.bodySmall)
                .foregroundColor(.textSecondary)
                .accessibilityIdentifier("SupportText")
        }
        // Transition animation: fade in with a slight scale-up from 95% when appearing,
        // fade out with a slight scale-down when disappearing.
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .accessibilityIdentifier("ReadyState")   // UI test identifier for the entire ready state
    }

    // -------------------------------------------------------------------------
    // MARK: Loading State
    // -------------------------------------------------------------------------

    /// Displayed while a video is being downloaded from iCloud or loaded from disk.
    /// Shows a custom circular progress indicator with a percentage label,
    /// a status message (e.g. "Downloading from Photos..."), and an ETA estimate.
    ///
    /// - Parameters:
    ///   - progress: Download/load progress from 0.0 to 1.0.
    ///   - status: Human-readable status text (e.g. "Reading file header...").
    ///   - eta: Optional estimated time remaining (e.g. "ETA: 1m 23s").
    @ViewBuilder
    private func loadingState(progress: Double, status: String, eta: String?) -> some View {
        VStack(spacing: 20) {
            // Custom circular progress ring — see circularProgress() below
            circularProgress(progress, size: 64, lineWidth: 6)

            VStack(spacing: 6) {
                // Status text — describes the current loading stage
                Text(status)
                    .font(.ibmPlexMono(size: 18))        // IBM Plex Mono, regular, 18pt
                    .foregroundColor(.secondary)           // Muted gray color
                    .accessibilityIdentifier("LoadingStatus")

                // ETA text — only shown if an estimate is available
                if let eta {
                    Text(eta)
                        .font(.ibmPlexMono(size: 15))    // Slightly smaller, 15pt
                        .foregroundColor(.accent)          // Accent blue (#2362a2) to draw attention
                        .accessibilityIdentifier("LoadingETA")
                }
            }
        }
        .padding()
        // Fill the entire available space so the progress ring is centered
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Same fade+scale transition as the ready state for consistency
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .accessibilityIdentifier("LoadingState")
    }

    // -------------------------------------------------------------------------
    // MARK: Preview State
    // -------------------------------------------------------------------------

    /// Displayed after a video has been successfully loaded. Shows:
    /// 1. The filename as a title
    /// 2. A video player preview (CustomVideoPlayerView)
    /// 3. Three action buttons: Change Video, Edit Video, Use Original
    ///
    /// This is the decision point where the user chooses their next step.
    ///
    /// - Parameters:
    ///   - asset: The loaded AVAsset from MediaManager's cache.
    ///   - url: The local file URL of the video.
    @ViewBuilder
    private func previewState(asset: AVAsset, url: URL) -> some View {
        VStack(spacing: Spacing.md) {
            // Title showing the selected file's name (e.g. "Selected File: windmill.mp4")
            Text("Selected File: \(url.lastPathComponent)")
                .font(.ibmPlexMono(size: 23, weight: .bold))  // Bold 23pt title
                .foregroundColor(.textPrimary)                  // Dynamic text color (dark/light mode aware)

            // Video preview player. Creates a fresh AVPlayer from the asset.
            // CustomVideoPlayerView is a reusable component that accepts Move, URL, or AVPlayer.
            CustomVideoPlayerView(player: AVPlayer(playerItem: AVPlayerItem(asset: asset)))
                .aspectRatio(4/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))

            // Action buttons row — three options for the user
            HStack(spacing: Spacing.md) {
                Button("Change") {
                    isPickerPresented = true
                }
                .secondaryAction()

                Button("Edit") {
                    currentState = .trimming(asset: asset, url: url)
                }
                .secondaryAction()

                Button("Use Original") {
                    currentState = .naming(finalURL: url, name: "", originalAsset: asset, originalURL: url)
                }
                .primaryAction()
            }
        }
        // Subtle scale transition (97% → 100%) for a gentle entrance animation
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    // -------------------------------------------------------------------------
    // MARK: Naming State
    // -------------------------------------------------------------------------

    /// The name entry step. Displayed after the user either edits the video or
    /// chooses "Use Original". Shows:
    /// 1. A navigation bar with Back and Edit buttons
    /// 2. A video preview of the final (possibly edited) clip
    /// 3. A text field for entering the move name
    /// 4. An optional AI suggestion button (iOS 26+ with Foundation Models)
    /// 5. A "Save Move" button that triggers the save pipeline
    ///
    /// - Parameters:
    ///   - finalURL: The URL of the video to save (either original or edited).
    ///   - originalAsset: The pre-edit AVAsset (nil if user picked "Use Original" without preview).
    ///     Used by the Back button to return to .previewing state.
    ///   - originalURL: The pre-edit URL. Used alongside originalAsset for navigation.
    @ViewBuilder
    private func namingState(finalURL: URL, originalAsset: AVAsset?, originalURL: URL?) -> some View {
        VStack(spacing: Spacing.lg) {
            // Top navigation bar: Back (left) | Title (center) | Edit (right)
            HStack {
                // Back button — returns to the preview state if we have the original asset,
                // otherwise re-opens the picker (fallback for edge case where preview data was lost)
                Button {
                    if let asset = originalAsset, let url = originalURL {
                        currentState = .previewing(asset: asset, url: url)
                    } else {
                        isPickerPresented = true
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                }
                .secondaryAction()
                .frame(width: 50)

                Spacer()

                // Edit button — returns to the trimming/editing state
                Button("Edit") {
                    if let asset = originalAsset, let url = originalURL {
                        currentState = .trimming(asset: asset, url: url)
                    }
                }
                .secondaryAction()
                .frame(width: 80)
                .disabled(originalAsset == nil)
            }
            .padding(.horizontal)   // Horizontal padding for the navigation bar

            // Video preview showing the final clip (after edits, or the original)
            CustomVideoPlayerView(url: finalURL)
                .aspectRatio(4/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))

            // Name input area
            VStack(spacing: Spacing.md) {
                // Row: text field + optional AI suggest button
                HStack(spacing: Spacing.sm) {
                    // Move name text field — two-way bound to @State moveName
                    TextField("Enter move name...", text: $moveName)
                        .padding(Radius.md)
                        .background(Color.neutralFill)
                        .cornerRadius(Radius.sm)
                        .font(.ibmPlexMono(size: 20))            // IBM Plex Mono, 20pt
                        .focused($isNameFieldFocused)             // Controlled by @FocusState for auto-focus
                        .submitLabel(.done)                       // Keyboard shows "Done" instead of "Return"
                        .onSubmit {
                            // When user taps "Done" on the keyboard, save if name is not empty
                            let trimmed = moveName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                saveMove(videoURL: finalURL, name: moveName)
                            }
                        }
                        .accessibilityIdentifier("MoveNameField")

                    // AI name suggestion button — only available on iOS 26+ with Foundation Models.
                    if #available(iOS 26.0, *), AIMoveSuggester.isAvailable {
                        Button {
                            Task {
                                isAISuggesting = true
                                if let name = try? await AIMoveSuggester.suggest() {
                                    moveName = name
                                }
                                isAISuggesting = false
                            }
                        } label: {
                            Group {
                                if isAISuggesting {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                            }
                            .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isAISuggesting)
                        .accessibilityLabel("AI Suggest Name")
                        .accessibilityIdentifier("AISuggestButton")
                    }
                }

                // Category picker — horizontal scrolling pills for category selection.
                // 18% larger text as requested. "+" button creates a new custom category.
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Category")
                        .font(.ibmPlexMono(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach(appSettings.categories) { cat in
                                Button {
                                    selectedCategory = cat.name
                                    HapticEngine.shared.speedChange()
                                } label: {
                                    Text(cat.name)
                                        // 18% bigger: base 16pt * 1.18 ≈ 19pt
                                        .font(.ibmPlexMono(size: 19, weight: selectedCategory == cat.name ? .bold : .regular))
                                        .foregroundColor(selectedCategory == cat.name ? .white : .textPrimary)
                                        .padding(.horizontal, Spacing.md)
                                        .padding(.vertical, Spacing.sm)
                                        .background(
                                            RoundedRectangle(cornerRadius: Radius.sm)
                                                .fill(selectedCategory == cat.name ? cat.color : Color.neutralFill)
                                        )
                                }
                                .animation(AppMotion.pillSelect, value: selectedCategory)
                            }

                            // "+" button to create a new custom category
                            Button {
                                isCreatingCategory = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.accent)
                                    .frame(width: 40, height: 40)
                                    .background(Color.neutralFill)
                                    .clipShape(Circle())
                                    .liquidGlass(in: .circle)
                            }
                        }
                    }
                }

                // "Save Move" button — triggers the file copy + SwiftData save pipeline.
                Button("Save Move") {
                    saveMove(videoURL: finalURL, name: moveName)
                }
                .primaryAction()
                .disabled(moveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("SaveMoveButton")
            }
            // New category creation alert
            .alert("New Category", isPresented: $isCreatingCategory) {
                TextField("Category Name", text: $newCategoryName)
                Button("Cancel", role: .cancel) { newCategoryName = "" }
                Button("Create") {
                    let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    if !name.isEmpty {
                        let colorHex = CategoryPalette.hexColors[newCategoryColorIndex % CategoryPalette.hexColors.count]
                        appSettings.addCategory(name: name, hexColor: colorHex)
                        selectedCategory = name
                    }
                    newCategoryName = ""
                    newCategoryColorIndex += 1
                }
            } message: {
                Text("Enter a name for your new category.")
            }
        }
        .padding()   // Overall padding for the naming state content
        .onAppear {
            // Auto-focus the name text field after a short delay (0.4s).
            // The delay prevents the keyboard from interfering with the state transition animation.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isNameFieldFocused = true
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Saving State
    // -------------------------------------------------------------------------

    /// Displayed while the video file is being copied and the SwiftData model is being saved.
    /// Shows a centered spinner with "Saving Move..." and a flavor text subtitle.
    private var savingState: some View {
        VStack(spacing: 20) {
            // System circular progress spinner, scaled up 1.5x for visibility.
            // Tinted with the app's accent color (#2362a2).
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .accent))

            VStack(spacing: Spacing.sm) {
                // Primary message
                Text("Saving Move...")
                    .font(.ibmPlexMono(size: 23, weight: .bold))
                    .foregroundColor(.textPrimary)

                // Flavor text / subtitle — adds personality to the loading state
                Text("Adding to your arsenal...")
                    .font(.ibmPlexMono(size: 18))
                    .foregroundColor(.secondary)
            }
        }
        // Fill available space to center the content vertically
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // -------------------------------------------------------------------------
    // MARK: Success State
    // -------------------------------------------------------------------------

    /// Displayed after the move has been successfully saved to SwiftData.
    /// Shows a green checkmark, the success message (including the move name),
    /// and a button to add another move.
    ///
    /// - Parameter message: The success message to display (e.g. "Move 'Windmill' saved!").
    @ViewBuilder
    private func successState(message: String) -> some View {
        VStack(spacing: 20) {
            // Large green checkmark icon — universally recognized success indicator
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))     // 64pt system font — large and prominent
                .foregroundColor(.green)       // Green for success

            // Success message (e.g. "Move 'Windmill' saved!")
            Text(message)
                .font(.ibmPlexMono(size: 23, weight: .bold))

            // "Add Another Move" button — resets the state machine to .ready
            Button("Add Another Move") {
                currentState = .ready
                moveName = ""
                selectedCategory = "MOVE"
            }
            .font(.ibmPlexMono(size: 20, weight: .semibold))
            .textCase(.uppercase)
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // Center vertically
    }

    // -------------------------------------------------------------------------
    // MARK: Error State
    // -------------------------------------------------------------------------

    /// Displayed when any step in the flow fails (file not found, export error,
    /// SwiftData save failure, etc.). Shows a warning icon, error details,
    /// and two recovery options: "Try Again" and "Change Video".
    ///
    /// - Parameter message: The error description to display.
    @ViewBuilder
    private func errorState(message: String) -> some View {
        VStack(spacing: 20) {
            // Large red warning icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)

            VStack(spacing: Spacing.sm) {
                // Generic error title
                Text("Something went wrong")
                    .font(.ibmPlexMono(size: 23, weight: .bold))
                    .foregroundColor(.textPrimary)

                // Specific error message from the caught error
                Text(message)
                    .font(.ibmPlexMono(size: 18))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)   // Center long error messages
                    .padding(.horizontal)               // Prevent text from touching screen edges
            }

            // Recovery action buttons
            HStack(spacing: Spacing.md) {
                // "Try Again" — resets to the ready state to start fresh
                Button("Try Again") {
                    moveName = ""
                    currentState = .ready
                }
                .font(.ibmPlexMono(size: 20, weight: .semibold))
                .textCase(.uppercase)
                .buttonStyle(.borderedProminent)

                // "Change Video" — resets to ready AND immediately opens the picker
                Button("Change Video") {
                    moveName = ""
                    currentState = .ready
                    isPickerPresented = true   // Immediately open the video picker
                }
                .font(.ibmPlexMono(size: 18))
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // Center vertically
    }

    // =========================================================================
    // MARK: - Reusable Components
    // =========================================================================

    /// A custom circular progress indicator used in the loading state.
    ///
    /// Renders as two overlapping circles:
    /// 1. A background circle (gray track) showing the full ring
    /// 2. A foreground arc (accent color) trimmed to represent the current progress
    /// Plus a centered percentage label.
    ///
    /// - Parameters:
    ///   - progress: The current progress value from 0.0 to 1.0.
    ///   - size: The diameter of the circle in points.
    ///   - lineWidth: The stroke width of the ring.
    /// - Returns: A ZStack containing the progress ring and percentage text.
    private func circularProgress(_ progress: Double, size: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            // Background track — full circle in light gray
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Foreground progress arc — accent-colored, trimmed to current progress.
            // .trim(from: 0, to: progress) draws only the portion of the circle
            // corresponding to the progress fraction. StrokeStyle with .round lineCap
            // gives it rounded endpoints. The -90 degree rotation starts the arc at 12 o'clock.
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))                    // Start at top (12 o'clock position)
                .animation(AppMotion.springQuick, value: progress) // Bouncy spring animation on progress changes

            // Centered percentage label (e.g. "42%")
            // Font size adjusts based on circle size — slightly smaller for larger circles
            // to maintain visual balance.
            Text("\(Int(progress * 100))%")
                .font(.ibmPlexMono(size: size > 70 ? 20 : 23, weight: .bold))
                .foregroundColor(.textPrimary)
                .accessibilityIdentifier("ProgressPercentage")
        }
    }

    // =========================================================================
    // MARK: - Save Pipeline
    // =========================================================================

    /// Saves the move to SwiftData with its associated video file.
    ///
    /// This is the core persistence operation. It runs on a background queue to avoid
    /// blocking the main thread during file I/O, then hops back to main for SwiftData writes.
    ///
    /// PIPELINE:
    /// 1. Transition to .saving state (shows spinner)
    /// 2. [Background] Verify the source video file exists
    /// 3. [Background] Create Documents/Moves/ directory if needed
    /// 4. [Background] Copy the video file to Documents/Moves/{UUID}.mp4
    /// 5. [Main thread] Create a new Move model with the user's name
    /// 6. [Main thread] Set the videoReference to the relative path as UTF-8 Data
    /// 7. [Main thread] Insert into modelContext and save
    /// 8. [Main thread] Transition to .success or .error depending on outcome
    /// 9. [Main thread] Clean up the temporary source file if it differs from the final location
    ///
    /// - Parameters:
    ///   - videoURL: The source video file URL (either original or edited export).
    ///   - name: The user-entered name for the move.
    private func saveMove(videoURL: URL, name: String) {
        // Immediately show the saving UI
        currentState = .saving

        // Run file I/O on a background queue to keep the UI responsive.
        // .userInitiated QoS because this is a direct response to user action.
        DispatchQueue.global(qos: .userInitiated).async {
            // Step 1: Verify the source video file exists on disk
            guard FileManager.default.fileExists(atPath: videoURL.path) else {
                DispatchQueue.main.async {
                    self.currentState = .error(message: "Video file not found. Please try again.")
                }
                return
            }

            // Step 2: Resolve the Documents directory and create the Moves subdirectory.
            // All move videos live in Documents/Moves/ with UUID filenames for uniqueness.
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let movesDirectory = documentsDirectory.appendingPathComponent("Moves", isDirectory: true)
            // Create the directory if it doesn't exist yet (first move ever saved)
            try? FileManager.default.createDirectory(at: movesDirectory, withIntermediateDirectories: true)

            // Step 3: Generate a unique filename and compute the final destination path
            let fileName = "\(UUID().uuidString).mp4"
            let finalVideoURL = movesDirectory.appendingPathComponent(fileName)

            do {
                // Step 4: Remove any existing file at the destination (unlikely with UUID names, but safe)
                if FileManager.default.fileExists(atPath: finalVideoURL.path) {
                    try FileManager.default.removeItem(at: finalVideoURL)
                }
                // Step 5: Copy the source video to its permanent location
                try FileManager.default.copyItem(at: videoURL, to: finalVideoURL)

                // Step 6: Build the relative path string for storage.
                // We store relative paths (not absolute) so the app works after backup/restore,
                // device migration, or if the Documents directory path changes.
                let relativePath = "Moves/\(fileName)"

                // Step 7: Switch to the main thread for SwiftData operations.
                // SwiftData's ModelContext is NOT thread-safe — all reads/writes MUST happen on main.
                DispatchQueue.main.async {
                    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

                    // Step 8: Create the new Move SwiftData model.
                    // - If the name is empty after trimming, default to "Untitled Move"
                    // - Learning state starts at "NEW" (beginning of spaced repetition cycle)
                    let newMove = Move(
                        name: trimmedName.isEmpty ? "Untitled Move" : trimmedName,
                        learningState: LearningState.newState.rawValue,
                        category: self.selectedCategory
                    )
                    // Step 9: Store the relative video path as UTF-8 encoded Data.
                    // This is how the Move model references its video file without storing
                    // the full absolute path (which would break on device changes).
                    newMove.videoReference = relativePath.data(using: .utf8)

                    // Step 10: Insert the new Move into the SwiftData model context
                    self.modelContext.insert(newMove)

                    do {
                        // Step 11: Persist to disk
                        try self.modelContext.save()
                        // Step 12: Show success UI with the move's name
                        self.currentState = .success(message: "Move '\(newMove.name ?? "Untitled")' saved!")

                        // Step 13: Clean up the temporary source file if it's different from the final location.
                        // This happens when the source was a temporary export from VideoEditorView.
                        if videoURL != finalVideoURL {
                            do {
                                try FileManager.default.removeItem(at: videoURL)
                            } catch {
                                print("[SavePipeline] Failed to clean up temp file: \(error.localizedDescription)")
                            }
                        }
                    } catch {
                        // SwiftData save failed — show error and clean up the copied file
                        self.currentState = .error(message: "Failed to save move to database: \(error.localizedDescription)")
                        try? FileManager.default.removeItem(at: finalVideoURL)
                    }
                }
            } catch {
                // File copy failed — show error on main thread
                DispatchQueue.main.async {
                    self.currentState = .error(message: "Failed to save video file: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("AddMove - Light") {
    AddMoveView()
        .modelContainer(.preview)
        .environment(AppSettings())
}

#Preview("AddMove - Dark") {
    AddMoveView()
        .modelContainer(.preview)
        .environment(AppSettings())
        .preferredColorScheme(.dark)
}
