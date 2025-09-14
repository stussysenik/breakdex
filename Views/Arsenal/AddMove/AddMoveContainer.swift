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
    @StateObject private var viewModel: AddMoveViewModel
    @Binding var selectedTab: TabSelection
    
    // VideoPlayerManager that persists across view transitions
    @StateObject private var videoPlayerManager = VideoPlayerManager()
    
    // Static tracking for debugging
    private static var lastState: AddMoveState?
    private static var viewEvaluationCount = 0
    
    private init(context: NSManagedObjectContext, selectedTab: Binding<TabSelection>) { // designated initializer
        logger.info("🎬 CONTAINER: AddMoveContainer initialized")
        
                
        logger.info("🎬 CONTAINER: Creating AddMoveViewModel with factory method")
        _viewModel = StateObject(wrappedValue: AddMoveViewModel.create(viewContext: context))
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
                    .environmentObject(videoPlayerManager)
                    .onAppear {
                        logger.info("🎬 CONTAINER: ⚠️ onAppear triggered")
                        logger.info("🎬 CONTAINER: onAppear - Initial state: \(String(describing: viewModel.state))")
                        logger.info("🎬 CONTAINER: onAppear - Selected tab: \(String(describing: selectedTab))")
                        logger.info("🎬 CONTAINER: onAppear - ViewModel validation: \(isViewModelValid())")
                        logMemoryAndPerformance("container_appear", state: viewModel.state, viewEvaluationCount: Self.viewEvaluationCount)
                        
                        // Additional validation on appear
                        if !isValidContainerState() {
                            logger.error("🎬 CONTAINER: ❌ INVALID STATE ON APPEAR!")
                        } else {
                            logger.info("🎬 CONTAINER: ✅ Container state still valid on appear")
                        }
                    }
                    .onDisappear {
                        logger.info("🎬 CONTAINER: ⚠️ onDisappear triggered")
                        logMemoryAndPerformance("container_disappear", state: viewModel.state, viewEvaluationCount: Self.viewEvaluationCount)
                        
                        // Clean up video player resources when entire workflow is finished
                        switch viewModel.state {
                        case .success, .error:
                            logger.info("🎬 CONTAINER: Workflow completed, tearing down video player")
                            videoPlayerManager.teardownPlayer()
                        default:
                            break
                        }
                    }
                    .onChange(of: viewModel.state) { oldState, newState in
                        logger.info("🎬 CONTAINER: ⚠️ onChange(of: viewModel.state) triggered")
                        logger.info("🎬 CONTAINER: State change - From: \(getStateDescription(oldState)) To: \(getStateDescription(newState))")
                        
                        // Validate state transitions
                        if !isValidStateTransition(from: oldState, to: newState) {
                            logger.error("🎬 CONTAINER: ❌ INVALID STATE TRANSITION DETECTED!")
                            logger.error("🎬 CONTAINER: From: \(getStateDescription(oldState)) To: \(getStateDescription(newState))")
                            // Reset to a safe state if invalid transition detected
                            viewModel.reset()
                        }
                        
                        if !isValidContainerState() {
                            logger.error("🎬 CONTAINER: ❌ CONTAINER STATE BECAME INVALID AFTER CHANGE!")
                        } else {
                            logger.info("🎬 CONTAINER: ✅ Container state remains valid after change")
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
    
    private var mainContent: some View {
        // Update state tracking before building the view
        updateViewStateTracking()
        
        return Group {
            switch viewModel.state {
                case .ready:
                    AddMoveSelectClipView(viewModel: viewModel)
                case .loading:
                    AddMoveSelectClipView(viewModel: viewModel)
                case .initializing(_, let status):
                    VStack {
                        Spacer()
                        ProgressView("Initializing...")
                            .progressViewStyle(.circular)
                        Text(status)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .background(Color.black.ignoresSafeArea())
                case .loaded(_, _, _):
                    VStack {
                        Spacer()
                        ProgressView("Preparing video preview...")
                            .progressViewStyle(.circular)
                        Text("Video loaded successfully")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .background(Color.black.ignoresSafeArea())
                case .previewing(let playerViewModel, let asset, let photosIdentifier, let rotationQuarterTurns):
                    PreTrimView(
                        viewModel: viewModel,
                        playerViewModel: playerViewModel,
                        asset: asset,
                        photosIdentifier: photosIdentifier,
                        rotationQuarterTurns: rotationQuarterTurns,
                        selectedTab: $selectedTab
                    )
                case .selectingVideo:
                    VideoPickerWrapper(viewModel: viewModel)
                case .trimming(let asset, _, let rotationQuarterTurns):
                    TrimmerViewWrapper(
                        viewModel: viewModel,
                        asset: asset,
                        rotationQuarterTurns: rotationQuarterTurns,
                        onError: { message, error in
                            viewModel.state = .error(message: message, underlyingError: error?.localizedDescription)
                        },
                        onRotate: { newRotation in
                            viewModel.state = .trimming(asset: asset, photosIdentifier: nil, rotationQuarterTurns: newRotation)
                        }
                    )
                case .naming:
                    NameMoveView(viewModel: viewModel)
                case .saving:
                    Text("Saving Move...")
                case .error(let message, let underlyingError):
                    AddMoveErrorView(viewModel: viewModel, message: message, underlyingError: underlyingError as? Error, selectedTab: $selectedTab)
                case .success(let message):
                    MoveAddedSuccessView(viewModel: viewModel, message: message, selectedTab: $selectedTab)
                }
            }
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
            // From loading, can go to initializing, loaded, or error
            switch newState {
            case .initializing, .loaded, .error:
                return true
            default:
                return false
            }
        case .initializing:
            // From initializing, can go to loaded, previewing, or error
            switch newState {
            case .previewing:
                // Allow direct transition from initializing to previewing
                return true
            case .loaded, .error:
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
        case .previewing:
            // From previewing, can go to trimming, naming, selectingVideo, or error
            switch newState {
            case .trimming, .naming, .selectingVideo, .error:
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
        }
    }
    
    private func isPreviewingState(_ state: AddMoveState) -> Bool {
        if case .previewing = state {
            return true
        }
        return false
    }
    
    private func isLoadedState(_ state: AddMoveState) -> Bool {
        if case .loaded = state {
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
    @ObservedObject var viewModel: AddMoveViewModel
    
    var body: some View {
        VStack {
            PhotosPicker(
                selection: $viewModel.selectedItem,
                matching: .videos,
                photoLibrary: .shared()
            ) {
                Text("Select Video")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.blue)
            }
            .photosPickerStyle(.inline)
            
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
            case .ready(let url):
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
    @ObservedObject var viewModel: AddMoveViewModel
    
    @StateObject private var trimmerViewModel: TrimmerViewModel
    
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
        
        _trimmerViewModel = StateObject(wrappedValue: TrimmerViewModel(asset: asset, photosIdentifier: nil))
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
            rotation: rotationQuarterTurns
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
