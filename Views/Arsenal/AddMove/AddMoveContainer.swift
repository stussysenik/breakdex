import SwiftUI
import CoreData
import AVKit
import Foundation
import Photos
import PhotosUI
import OSLog
import Combine

// MARK: - Tab Selection Enum


private let logger = Logger(subsystem: "com.breakingflashcards", category: "AddMoveContainer")

// MARK: - State-Driven Container

/// Refactored container using unified state to eliminate State Object Churn
struct AddMoveContainer: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding private var selectedTab: TabSelection

    // 💡 SOLUTION: Single unified state object eliminates churn
    @StateObject private var unifiedState: AddMoveUnifiedState

    // MARK: - Save Completion Handler
    /// Called when a move is successfully saved and ready for navigation
    private var onSaveSuccess: ((Move) -> Void)?

    // MARK: - Initialization
    private init(context: NSManagedObjectContext, selectedTab: Binding<TabSelection>, unifiedState: AddMoveUnifiedState, onSaveSuccess: ((Move) -> Void)?) {
        logger.info("🎬 CONTAINER: AddMoveContainer initialized with unified state")

        _selectedTab = selectedTab
        _unifiedState = StateObject(wrappedValue: unifiedState)
        self.onSaveSuccess = onSaveSuccess

        logger.info("🎬 CONTAINER: AddMoveContainer initialization completed")
    }
    
    init(selectedTab: Binding<TabSelection>, onSaveSuccess: ((Move) -> Void)? = nil) {
        logger.info("🎬 CONTAINER: Convenience initializer called")
        logger.info("🎬 CONTAINER: Using shared PersistenceController context")

        let appContainer = AppContainer.shared
        let unifiedState = AddMoveUnifiedState(
            unifiedPlayerManager: UnifiedPlayerManager(),
            appContainer: appContainer
        )

        self.init(
            context: PersistenceController.shared.container.viewContext,
            selectedTab: selectedTab,
            unifiedState: unifiedState,
            onSaveSuccess: onSaveSuccess
        )
    }
    
    init(viewContext: NSManagedObjectContext, selectedTab: Binding<TabSelection>, onSaveSuccess: ((Move) -> Void)? = nil) {
        let appContainer = AppContainer.shared
        let unifiedState = AddMoveUnifiedState(
            unifiedPlayerManager: UnifiedPlayerManager(),
            appContainer: appContainer
        )

        self.init(context: viewContext, selectedTab: selectedTab, unifiedState: unifiedState, onSaveSuccess: onSaveSuccess)
    }
    
    var body: some View {
        Group {
            if isValidContainerState() {
                mainContentWithModifiers
            } else {
                renderContainerFallbackUI()
            }
        }
    }
    
    private var mainContentWithModifiers: some View {
        mainContent
            .onAppear {
                handleViewAppear()
            }
            .onDisappear {
                handleViewDisappear()
            }
            .onChange(of: unifiedState.flowState) { oldState, newState in
                handleStateChange(from: oldState, to: newState)
            }
    }
    
    private func handleViewAppear() {
        logger.info("🎬 CONTAINER: View appeared with state: \(String(describing: unifiedState.flowState))")
        logState("container_appear", flowState: unifiedState.flowState)

        // 🎯 CRITICAL FIX: Set up the save completion handler for navigation
        unifiedState.onSaveSuccess = { savedMove in
            logger.info("🎬 CONTAINER: 🚀 Save completion handler called with saved move")

            // Call the container's completion handler if available
            self.onSaveSuccess?(savedMove)
        }
    }
    
    private func handleViewDisappear() {
        logger.info("🎬 CONTAINER: View disappeared from state: \(String(describing: unifiedState.flowState))")

        // Clean up resources when workflow is finished, but only if not navigating
        let currentState = unifiedState.flowState
        let shouldCleanUp: Bool = {
            switch currentState {
            case .success:
                // 🎯 CRITICAL FIX: Don't clean up on success - let navigation happen first
                logger.info("🎬 CONTAINER: Success state detected - postponing cleanup to allow navigation")
                return false
            case .error:
                return true
            default:
                return false
            }
        }()

        if shouldCleanUp {
            logger.info("🎬 CONTAINER: Workflow completed, cleaning up unified state")
            unifiedState.reset()
        }
    }
    
    private func handleStateChange(from oldState: AddMoveFlowState, to newState: AddMoveFlowState) {
        logger.info("🎬 CONTAINER: Flow state change observed - From: \(String(describing: oldState)) To: \(String(describing: newState))")

        // ✅ REFACTOR: The validation now happens inside AddMoveUnifiedState, where it belongs.
        // The container's job is to react to the state, not validate it.
        // If an invalid transition somehow occurs, the UnifiedState will log it and move to an error state itself.
    }
    
    private var mainContent: some View {
        // 💡 SOLUTION: Simple switch statement eliminates complex if-case chains
        // 🎯 FIX: Wrap the entire Group in AnyView. This is a "natural transformation"
        // that erases the complex, nested _ConditionalContent type generated by the
        // switch statement. It presents a simple, opaque type to the compiler,
        // resolving the "failed to produce diagnostic" error.
        AnyView(
            Group {
                switch unifiedState.flowState {
                case .ready:
                    AddMoveSelectClipViewUnified(unifiedState: unifiedState)

                case .loading(let progress, let status):
                    LoadingView(progress: progress, status: status, unifiedState: unifiedState)

                case .replacingVideo(let status):
                    LoadingView(progress: 0.48, status: status, unifiedState: unifiedState)

                case .previewing:
                    EmptyView() // Preview state is skipped in new flow

                case .trimming_setup:
                    LoadingView(progress: 1.0, status: "Finalizing setup...", unifiedState: unifiedState)

                case .trimming:
                    if let viewModel = unifiedState.trimmerViewModel {
                        FeatureRichTrimmerView(unifiedState: unifiedState, viewModel: viewModel)
                            .id(unifiedState.photosIdentifier ?? UUID().uuidString)
                    } else {
                        LoadingView(progress: 1.0, status: "Initializing Trimmer...", unifiedState: unifiedState)
                    }

                case .finalizing(let status):
                    LoadingOverlayView(progress: 0.9, status: status)

                case .naming:
                    NameMoveViewUnified(unifiedState: unifiedState)

                case .saving:
                    SavingViewWithProgress(unifiedState: unifiedState)

                case .success(let message):
                    SuccessView(message: message) {
                        Task {
                            await unifiedState.reset()
                        }
                    }
                    // 🎯 CRITICAL FIX: Don't immediately reset - allow navigation completion first
                    // The reset will happen after navigation is complete

                case .error(let message, _):
                    ErrorView(
                        message: message,
                        onRetry: {
                            Task {
                                await unifiedState.clearError()
                            }
                        },
                        onCancel: {
                            Task {
                                await unifiedState.reset()
                            }
                            selectedTab = .arsenal
                        }
                    )
                }
            }
        )
    }
    
    // MARK: - Helper Methods
    private func isValidContainerState() -> Bool {
        let stateValid = isValidFlowState(unifiedState.flowState)
        let tabValid = isTabValid()
        return stateValid && tabValid
    }
    
    private func isValidFlowState(_ state: AddMoveFlowState) -> Bool {
        return true // All flow states are valid
    }
    
    private func isTabValid() -> Bool {
        return selectedTab == .add
    }
    
    // ✅ REFACTOR: Removed duplicate isValidFlowStateTransition function.
    // Validation now happens in AddMoveUnifiedState, the single source of truth for state transitions.
    
    private func logState(_ context: String, flowState: AddMoveFlowState) {
        let memoryInfo = ProcessInfo.processInfo
        logger.info("🎬 [\(context)] State: \(String(describing: flowState)), Mem: \(memoryInfo.physicalMemory / (1024*1024*1024))GB")
    }
    
    private func renderContainerFallbackUI() -> some View {
        VStack {
            Spacer()
            Text("Unable to load video interface")
                .font(.headline)
                .foregroundColor(.white)
            Text("Please restart the app")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Restart") {
                unifiedState.reset()
                selectedTab = .add
            }
            .buttonStyle(.appPrimary(size: .medium))
            .padding(.top)
            
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - Unified State Views

/// State-driven video selection view
struct AddMoveSelectClipViewUnified: View {
    @ObservedObject var unifiedState: AddMoveUnifiedState
    @State private var showPhotosPicker = false
    @State private var tempSelection: PhotosUI.PhotosPickerItem?

    var body: some View {
        VStack {
            Spacer()

            Button("Select Video") {
                showPhotosPicker = true
            }
            .font(.custom("IBMPlexMono-Regular", size: 18))
            .buttonStyle(.appAccent(size: .large))

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $tempSelection,
            matching: .videos,
            preferredItemEncoding: .current,
            photoLibrary: .shared()
        )
        .onChange(of: tempSelection) { _, newItem in
            if let newItem = newItem {
                let customItem = PhotosPickerItem(item: newItem)
                unifiedState.didSelectVideo(customItem)
                tempSelection = nil
            }
        }
    }
}

/// Enhanced loading view with progress indicator and elapsed time tracking
/// 🎯 CRITICAL FIX: Now displays elapsed time for transparent large video processing UX
struct LoadingView: View {
    let progress: Double
    let status: String
    @ObservedObject var unifiedState: AddMoveUnifiedState

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView(status)
                .progressViewStyle(.circular)

            // Progress percentage
            Text("\(Int(progress * 100))%")
                .font(.ibmPlexMono(size: 14, weight: .regular))
                .foregroundColor(.textSecondary)

            // 🎯 CRITICAL FIX: Enhanced elapsed time display for large video loading
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.textSecondary.opacity(0.8))
                Text(formatTime(unifiedState.loadElapsedTime))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.textSecondary.opacity(0.8))
            }

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }

    // Helper to format seconds into MM:SS
    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

/// Enhanced saving view with minimal overlay and elapsed time tracking
/// Implements robust @StateObject initialization using explicit StateObject property wrapper
/// to prevent Swift compiler frontend bug that prevents diagnostic generation
struct SavingViewWithProgress: View {
    @ObservedObject var unifiedState: AddMoveUnifiedState

    // 🎯 CRITICAL FIX: Made stateless - now uses unified state timer to fix ETA stuck issue and memory leak

    var body: some View {
        // 🎯 FIX: Wrap entire body in AnyView to resolve "failed to produce diagnostic" error
        AnyView(
            VStack {
                Spacer()

                // Minimal non-blocking overlay
                savingStatusView()
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.85))
                            .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                    )

                Spacer()
            }
            .background(Color.black.ignoresSafeArea())
            .onAppear {
                // 🎯 STRATEGIC LOGGING: Add back diagnostic logging with simplified string interpolation
                logger.info("⏱️ SAVING_VIEW: Saving view appeared")
                logger.info("🎬 SAVING_VIEW: Save operation started - timer now managed by unified state")
            }
            .onDisappear {
                logger.info("⏱️ SAVING_VIEW: Saving view disappeared")
                logger.info("🎬 SAVING_VIEW: Save operation completed - timer managed by unified state")
            }
        )
    }
    
    private func savingStatusView() -> some View {
        VStack(spacing: 20) {
            headerView()
            progressView()
        }
    }

    private func headerView() -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.9)
                    .frame(width: 24, height: 24)

                Text("Saving Move...")
                    .font(.headline)
                    .foregroundColor(.white)
                    .fontWeight(.medium)
            }

            // Elapsed time indicator - now using unified state timer
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))

                Text(formatTime(unifiedState.saveElapsedTime))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    private func progressView() -> some View {
        // 🎯 FIX: Wrap conditional content in AnyView to resolve "failed to produce diagnostic" error
        AnyView(
            Group {
                // Progress section (if available)
                if unifiedState.saveProgress > 0 {
                    VStack(spacing: 8) {
                        ProgressView(value: unifiedState.saveProgress, total: 1.0)
                            .progressViewStyle(.linear)
                            .frame(width: 240)
                            .tint(.blue)

                        HStack(spacing: 4) {
                            Text("\(Int(unifiedState.saveProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.gray)

                            Text("•")
                                .font(.caption)
                                .foregroundColor(.gray)

                            Text("Processing video...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                } else {
                    Text("Processing your video and metadata...")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 200)
                }
            }
        )
    }

    // Format seconds to MM:SS format
    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

/// Saving view
struct SavingView: View {
    var body: some View {
        VStack {
            Spacer()
            ProgressView("Saving Move...")
                .progressViewStyle(.circular)
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

/// Success view
struct SuccessView: View {
    let message: String
    let onDone: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            Text(message)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Done") {
                onDone()
            }
            .buttonStyle(.appPrimary(size: .medium))
            .padding(.top)
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

/// Error view
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            Text(message)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack {
                Button("Retry") {
                    onRetry()
                }
                .buttonStyle(.appPrimary(size: .medium))
                
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.appSecondary(size: .medium))
            }
            .padding(.top)
            
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    AddMoveContainer(selectedTab: .constant(.add))
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        .preferredColorScheme(.dark)
}