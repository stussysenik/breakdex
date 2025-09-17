import SwiftUI
import CoreData
import AVKit
import Foundation
import Photos
import PhotosUI
import OSLog


private let logger = Logger(subsystem: "com.breakingflashcards", category: "AddMoveContainer")



// traffic manager - routes to the correct view based on the state
struct AddMoveContainer: View {
    @Environment(\.managedObjectContext) var viewContext
    @State private var viewModel: AddMoveViewModel
    @Binding var selectedTab: TabSelection
    
    
    // Static tracking for debugging
    private static var lastState: AddMoveState?
    private static var viewEvaluationCount = 0
    
    private init(context: NSManagedObjectContext, selectedTab: Binding<TabSelection>) { // designated initializer
        logger.info("🎬 CONTAINER: AddMoveContainer initialized")
        
        let viewModel = AddMoveViewModel.create(viewContext: context)
        _viewModel = State(initialValue: viewModel)
        _selectedTab = selectedTab
        
        // Note: Cannot access viewModel.state during initialization - will log after view appears
        logger.info("🎬 CONTAINER: AddMoveContainer initialization completed")
    }
    
    init(selectedTab: Binding<TabSelection>) { // convenience initializer
        logger.info("🎬 CONTAINER: Convenience initializer called")
        logger.info("🎬 CONTAINER: Using shared PersistenceController context")
        self.init(context: PersistenceController.shared.container.viewContext, selectedTab: selectedTab)
    }
    
    init(viewContext: NSManagedObjectContext, selectedTab: Binding<TabSelection>) { // convenience initializer
        self.init(context: viewContext, selectedTab: selectedTab)
    }
    
    
    var body: some View {
        Group {
            if isValidContainerState() {
                mainContent
                    .onAppear {
                        // Only log once when view first appears
                        if Self.viewEvaluationCount == 0 {
                            logger.info("🎬 CONTAINER: View first appeared")
                            logMemoryAndPerformance("container_appear", state: viewModel.state, viewEvaluationCount: Self.viewEvaluationCount)
                        }
                    }
                    .onDisappear {
                        // Only log when view actually disappears
                        if Self.viewEvaluationCount > 0 {
                            logger.info("🎬 CONTAINER: View disappeared")
                            logMemoryAndPerformance("container_disappear", state: viewModel.state, viewEvaluationCount: Self.viewEvaluationCount)
                            
                            // Clean up video player resources when entire workflow is finished
                            switch viewModel.state {
                            case .success, .error:
                                logger.info("🎬 CONTAINER: Workflow completed, tearing down video player")
                                // VideoPlayerManager removed - unified player handles cleanup
                            default:
                                break
                            }
                        }
                    }
                    .onChange(of: viewModel.state) { oldState, newState in
                        logger.info("🎬 CONTAINER: State change - From: \(getStateDescription(oldState)) To: \(getStateDescription(newState))")
                        
                        // Validate state transitions
                        if !isValidStateTransition(from: oldState, to: newState) {
                            logger.error("🎬 CONTAINER: ❌ INVALID STATE TRANSITION DETECTED!")
                            logger.error("🎬 CONTAINER: From: \(getStateDescription(oldState)) To: \(getStateDescription(newState))")
                            // Reset to a safe state if invalid transition detected
                            viewModel.reset()
                        }
                    }
            } else {
                renderContainerFallbackUI()
            }
        }
    }
    
    private func updateViewStateTracking() {
        let currentState = viewModel.state
        
        // Track state changes
        if Self.lastState != currentState {
            logger.info("🎬 CONTAINER: View transition From: \(Self.lastState.map { getStateDescription($0) } ?? "nil") To: \(getStateDescription(currentState))")
            Self.lastState = currentState
        }
        
        // Increment view evaluation count
        Self.viewEvaluationCount += 1
    }
    
    private var mainContent: AnyView {
        // Update state tracking before building the view
        updateViewStateTracking()
        
        let content: AnyView
        if case .ready = viewModel.state {
            content = AnyView(AddMoveSelectClipView(viewModel: viewModel))
            } else if case .selectingVideo(_) = viewModel.state {
            content = AnyView(VStack {
                Spacer()
                Text("Choose from your photo library")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
            }
                .background(Color.black.ignoresSafeArea()))
        } else if case .loading(let progress, let status) = viewModel.state {
            content = AnyView(VStack {
                Spacer()
                ProgressView(status)
                    .progressViewStyle(.circular)
                Text("\(Int(progress * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
            }
                .background(Color.black.ignoresSafeArea()))
        } else if case .initializing(_, let status) = viewModel.state {
            content = AnyView(VStack {
                Spacer()
                ProgressView("Initializing...")
                    .progressViewStyle(.circular)
                Text(status)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
            }
                .background(Color.black.ignoresSafeArea()))
        } else if case .previewing(let playerViewModel, let asset, let photosIdentifier, let rotationQuarterTurns) = viewModel.state {
            // Direct routing to PreTrimView with prepared playerViewModel
            content = AnyView(PreTrimView(
                viewModel: viewModel,
                playerViewModel: playerViewModel,
                asset: asset,
                photosIdentifier: photosIdentifier,
                rotationQuarterTurns: rotationQuarterTurns,
                selectedTab: $selectedTab
            ))
        } else if case .trimming(let asset, _, let rotationQuarterTurns) = viewModel.state {
            content = AnyView(TrimmerViewWrapper(
                viewModel: viewModel,
                asset: asset,
                rotationQuarterTurns: rotationQuarterTurns,
                onError: { message, error in
                    viewModel.setErrorState(message: message, underlyingError: error?.localizedDescription)
                },
                onRotate: { newRotation in
                    viewModel.setTrimmingState(asset: asset, rotationQuarterTurns: newRotation)
                }
            ))
        } else if case .naming = viewModel.state {
            content = AnyView(NameMoveView(viewModel: viewModel))
        } else if case .saving = viewModel.state {
            content = AnyView(Text("Saving Move..."))
        } else if case .error(let message, let underlyingError) = viewModel.state {
            content = AnyView(AddMoveErrorView(viewModel: viewModel, message: message, underlyingError: underlyingError as? Error, selectedTab: $selectedTab))
        } else if case .success(let message) = viewModel.state {
            content = AnyView(VStack {
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
                    viewModel.reset()
                }
                .buttonStyle(.appPrimary(size: .medium))
                .padding(.top)
                Spacer()
            }
                .background(Color.black.ignoresSafeArea()))
        } else {
            content = AnyView(EmptyView())
        }
        
        return content
    }
    
    // MARK: - Helper Methods
    private func isValidContainerState() -> Bool {
        let viewModelValid = isViewModelValid()
        let tabValid = isTabValid()
        return viewModelValid && tabValid
    }
    
    private func isViewModelValid() -> Bool {
        return isValidAddMoveState(viewModel.state)
    }
    
    private func isTabValid() -> Bool {
        return selectedTab == .add
    }
    
    private func isValidAddMoveState(_ state: AddMoveState) -> Bool {
        return true
    }
    
    private func isValidStateTransition(from oldState: AddMoveState, to newState: AddMoveState) -> Bool {
        // Define valid state transitions
        switch oldState {
        case .ready:
            // From ready, can go to loading or selectingVideo
            switch newState {
            case .loading, .selectingVideo:
                return true
            default:
                return false
            }
        case .loading:
            // From loading, can go to previewing, initializing, error, or stay in loading (progress updates)
            switch newState {
            case .previewing, .initializing, .error:
                return true
            case .loading:
                // Allow loading -> loading transitions for progress updates
                return true
            default:
                return false
            }
        case .initializing:
            // From initializing, can go to previewing or error
            switch newState {
            case .previewing:
                // Allow direct transition from initializing to previewing
                return true
            case .error:
                return true
            default:
                return false
            }
        case .previewing:
            // From previewing, can go to trimming, naming, selectingVideo, ready, or error
            switch newState {
            case .trimming, .naming, .selectingVideo, .ready, .error:
                return true
            default:
                return false
            }
        case .selectingVideo:
            // From selectingVideo, can go to loading or previewing
            switch newState {
            case .loading, .previewing:
                return true
            default:
                return false
            }
        case .trimming:
            // From trimming, can go to previewing, naming, or error
            switch newState {
            case .previewing, .naming, .error:
                return true
            default:
                return false
            }
        case .naming:
            // From naming, can go to saving or error
            switch newState {
            case .saving, .error:
                return true
            default:
                return false
            }
        case .saving:
            // From saving, can go to success or error
            switch newState {
            case .success, .error:
                return true
            default:
                return false
            }
        case .success:
            // From success, can go to ready
            switch newState {
            case .ready:
                return true
            default:
                return false
            }
        case .error:
            // From error, can go to ready
            switch newState {
            case .ready:
                return true
            default:
                return false
            }
        case .loaded:
            // From loaded, can go to previewing or error
            switch newState {
            case .previewing, .error:
                return true
            default:
                return false
            }
        }
    }
    
    private func isPreviewingState(_ state: AddMoveState) -> Bool {
        if case .previewing = state {
            return true
        }
        return false
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
                viewModel.reset()
                selectedTab = .add
            }
            .buttonStyle(.appPrimary(size: .medium))
            .padding(.top)
            
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    private func logMemoryAndPerformance(_ context: String, state: AddMoveState, viewEvaluationCount: Int) {
        let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
        let processInfo = ProcessInfo.processInfo
        let thread = Thread.current.isMainThread ? "Main" : "Background"
        
        logger.info("🎬 [\(context)] Mem: \(String(format: "%.1f", memoryGB))GB, Procs: \(processInfo.activeProcessorCount), Uptime: \(String(format: "%.1f", processInfo.systemUptime))s, Thread: \(thread), State: \(getStateDescription(state)), Evals: \(viewEvaluationCount)")
    }
}

// MARK: - Video Picker Wrapper (Single Source of Truth)
struct VideoPickerWrapper: View {
    @Bindable var viewModel: AddMoveViewModel
    
    var body: some View {
        VStack {
            PhotosPicker(
                selection: $viewModel.selectedItem,
                matching: .videos,
                preferredItemEncoding: .current,
                photoLibrary: .shared()
            ) {
                Text("Select Video")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            // Show import status
            switch viewModel.importState {
            case .idle:
                EmptyView()
            case .importing:
                VStack {
                    ProgressView("Importing video...")
                        .padding()
                    Text("Please wait while we process your video")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            case .ready(_):
                Text("Video imported successfully")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.top, 8)
            case .error(let error):
                VStack {
                    Text("Import failed")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Trimmer View Wrapper (Safe State Management)
struct TrimmerViewWrapper: View {
    @Bindable var viewModel: AddMoveViewModel
    
    @State private var trimmerViewModel: TrimmerViewModel
    @State private var playerViewModel: UnifiedVideoPlayerViewModel
    
    let asset: AVAsset
    let rotationQuarterTurns: Int
    
    let onError: (String, Error?) -> Void
    let onRotate: (Int) -> Void
    
    private let wrapperId = UUID()
    private let constructionTime = Date().timeIntervalSince1970
    
    init(viewModel: AddMoveViewModel, asset: AVAsset, rotationQuarterTurns: Int, onError: @escaping (String, Error?) -> Void, onRotate: @escaping (Int) -> Void) {
        self.viewModel = viewModel
        self.asset = asset
        self.rotationQuarterTurns = rotationQuarterTurns
        self.onError = onError
        self.onRotate = onRotate
        
        let playerVM = UnifiedVideoPlayerViewModel(player: AVPlayer(playerItem: AVPlayerItem(asset: asset)), mode: .preview, appContainer: AppContainer.shared)
        self._playerViewModel = State(initialValue: playerVM)
        self._trimmerViewModel = State(initialValue: TrimmerViewModel(asset: asset, photosIdentifier: nil, rotationQuarterTurns: rotationQuarterTurns, playerViewModel: playerVM))
    }
    
    var body: some View {
        let bodyTimestamp = Date().timeIntervalSince1970
        let threadInfo = Thread.isMainThread ? "MAIN" : "BG"
        
        logger.info("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: Body evaluated on \(threadInfo) thread")
        logger.info("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: Time since construction: \(String(format: "%.3f", bodyTimestamp - constructionTime))s")
        logger.info("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: Memory pressure: normal")
        
        return FeatureRichTrimmerView(
            viewModel: viewModel,
            asset: asset,
            rotation: rotationQuarterTurns,
            playerViewModel: playerViewModel
        )
        .onAppear {
            let appearTimestamp = Date().timeIntervalSince1970
            logger.info("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: View appeared - starting safe async setup")
            logger.info("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: Construction to appear: \(String(format: "%.3f", appearTimestamp - constructionTime))s")
            
            // Perform async setup after view is fully constructed to prevent state mutations during construction
            Task {
                let taskStartTime = Date().timeIntervalSince1970
                logger.info("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: Starting safe async operations")
                
                do {
                    logger.info("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: Starting setupAsync()")
                    try await trimmerViewModel.setupAsync()
                    logger.info("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: setupAsync() completed successfully")
                    
                    logger.info("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: Starting updatePreview()")
                    await trimmerViewModel.updatePreview()
                    logger.info("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: updatePreview() completed successfully")
                    
                    let taskEndTime = Date().timeIntervalSince1970
                    logger.info("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: All async operations completed successfully")
                    logger.info("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: Total time: \(String(format: "%.3f", taskEndTime - taskStartTime)) seconds")
                    logger.info("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: Final state: duration=\(String(format: "%.2f", trimmerViewModel.videoDuration.seconds))s, trim=\(String(format: "%.2f", trimmerViewModel.startTime.seconds))-\(String(format: "%.2f", trimmerViewModel.endTime.seconds))s")
                    
                } catch {
                    let errorTime = Date().timeIntervalSince1970
                    logger.error("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: Async operation failed")
                    logger.error("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: Error: \(error.localizedDescription)")
                    logger.error("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: Error type: \(type(of: error))")
                    logger.error("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: Error context: setup phase after \(String(format: "%.3f", errorTime - taskStartTime))s")
                    
                    // Log additional error context
                    if let nsError = error as NSError? {
                        logger.error("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: Error domain: \(nsError.domain)")
                        logger.error("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: Error code: \(nsError.code)")
                    }
                    
                    logger.info("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: Emitting error event via callback")
                    // Event-driven error handling: emit error event instead of mutating parent state
                    onError("Failed to load video for trimming.", error)
                    logger.info("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: Error event emitted")
                }
            }
        }
        .onDisappear {
            let disappearTime = Date().timeIntervalSince1970
            logger.info("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: View disappeared")
            logger.info("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: Total lifetime: \(String(format: "%.3f", disappearTime - constructionTime))s")
            logger.info("🎬 TRIMMER_WRAPPER [\(wrapperId.uuidString.prefix(8))]: Final trim state: \(String(format: "%.2f", trimmerViewModel.startTime.seconds)) - \(String(format: "%.2f", trimmerViewModel.endTime.seconds))s")
        }
    }
}

// MARK: - Helper Functions
private func getStateDescription(_ state: AddMoveState) -> String {
    switch state {
    case .ready:
        return "ready"
    case .initializing(let progress, let status):
        return "initializing(\(progress), \(status))"
    case .loading(let progress, let status):
        return "loading(\(progress), \(status))"
    case .loaded(_, let id, let rotation):
        return "loaded(id: \(id ?? "nil"), rotation: \(rotation)°)"
    case .previewing(_, _, let id, let rotation):
        return "previewing(id: \(id ?? "nil"), rotation: \(rotation)°)"
    case .selectingVideo(let asset):
        return "selectingVideo(asset: \(asset != nil ? "exists" : "nil"))"
    case .trimming(_, let id, let rotation):
        return "trimming(id: \(id ?? "nil"), rotation: \(rotation)°)"
    case .naming(let id, _, _, let start, let end, let rotation):
        return "naming(id: \(id), start: \(start ?? -1), end: \(end ?? -1), rotation: \(rotation)°)"
    case .saving:
        return "saving"
    case .success(let message):
        return "success(\(message))"
    case .error(let message, let underlying):
        return "error(\(message), underlying: \(underlying ?? "nil"))"
    }
}

#Preview {
    AddMoveContainer(selectedTab: .constant(.add))
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        .preferredColorScheme(.dark)
}
