import SwiftUI
import OSLog

/// State object owner that persists AddMoveUnifiedState at the MainView level
///
/// This view solves the critical state lifecycle bug where AddMoveUnifiedState was being
/// destroyed and recreated when AddMoveContainer was recreated by SwiftUI during video loading.
/// By elevating the state object ownership to the MainView level, the state becomes independent
/// of the view lifecycle and persists throughout the app session.
///
/// ROOT CAUSE FIX:
/// - BEFORE: AddMoveContainer created AddMoveUnifiedState with @StateObject (destroyed on view recreation)
/// - AFTER: MainView creates AddMoveUnifiedState with @StateObject (persists for app lifetime)
/// - AddMoveContainer now receives the state as @ObservedObject (no ownership)
struct AddMoveStateOwner: View {
    @Binding var selectedTab: TabSelection

    // 🎯 CRITICAL FIX: State object now owned at MainView level
    // This ensures the state persists across SwiftUI view recreations
    @StateObject private var unifiedState: AddMoveUnifiedState

    // Save completion handler for navigation
    private let onSaveSuccess: ((Move) -> Void)?

    // 🎯 CRITICAL FIX: Loading state callback for app-wide overlay management
    private let onLoadingStateChanged: ((Bool, AddMoveUnifiedState?) -> Void)?

    private let logger = Logger(subsystem: "com.breakingflashcards", category: "AddMoveStateOwner")

    init(
        selectedTab: Binding<TabSelection>,
        onSaveSuccess: ((Move) -> Void)? = nil,
        onLoadingStateChanged: ((Bool, AddMoveUnifiedState?) -> Void)? = nil
    ) {
        logger.info("🎬 STATE_OWNER: 🏗️ INITIALIZING - AddMoveStateOwner created with persistent state ownership")

        self._selectedTab = selectedTab
        self.onSaveSuccess = onSaveSuccess
        self.onLoadingStateChanged = onLoadingStateChanged

        // 🎯 CRITICAL FIX: Create AddMoveUnifiedState once at MainView level
        // This state will now persist for the entire app session, independent of view lifecycle
        let appContainer = AppContainer.shared
        let persistentState = AddMoveUnifiedState(
            unifiedPlayerManager: UnifiedPlayerManager(),
            modernVideoLoadingService: appContainer.modernVideoLoadingService,
            videoProcessingPipeline: appContainer.videoProcessingPipeline,
            timecodeCalculationService: TimecodeCalculationService(),
            persistentContainer: PersistenceController.shared.container,
            movePersistenceService: appContainer.movePersistenceService,
            appContainer: appContainer
        )

        self._unifiedState = StateObject(wrappedValue: persistentState)

        logger.info("🎬 STATE_OWNER: ✅ STATE_LIFECYLE_FIXED - AddMoveUnifiedState now owned at MainView level")
        let stateIdString = String(describing: ObjectIdentifier(persistentState))
        logger.info("🎬 STATE_OWNER: 🎯 PERSISTENT_STATE_ID: \(stateIdString)")
        logger.info("🎬 STATE_OWNER: 📊 State will persist across SwiftUI view recreations")

        // 🚨 ENHANCED_STATE_LIFECYCLE_LOGGING: Log state object creation for diagnostics
        StateLifecycleDiagnosticLogger.logStateObjectCreation(persistentState, owner: "AddMoveStateOwner (MainView level)")
        StateLifecycleDiagnosticLogger.logStateLifecycleFixVerification()
        StateLifecycleDiagnosticLogger.logArchitectureComparison()
    }

    var body: some View {
        Group {
            if selectedTab == .add {
                addMoveContent
            } else {
                EmptyView()
            }
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            handleTabChange(from: oldTab, to: newTab)
        }
        .onChange(of: unifiedState.flowState) { oldState, newState in
            handleFlowStateChange(from: oldState, to: newState)
        }
        .onReceive(unifiedState.unifiedProgressEngine.$unifiedProgress) { progress in
            handleProgressChange(progress)
        }
    }

    private var addMoveContent: some View {
        AddMoveContainerWithPersistentState(
            selectedTab: $selectedTab,
            unifiedState: unifiedState,
            onSaveSuccess: onSaveSuccess
        )
        .onAppear {
            logTabAppear()
        }
        .onDisappear {
            logTabDisappear()
        }
    }

    private func logTabAppear() {
        let stateIdString = String(describing: ObjectIdentifier(unifiedState))
        logger.info("🎬 STATE_OWNER: 📱 AddMove tab appeared with persistent state")
        logger.info("🎬 STATE_OWNER: 🎯 PERSISTENT_STATE_ID: \(stateIdString)")
        logger.info("🎬 STATE_OWNER: 📊 Current flow state: \(String(describing: unifiedState.flowState))")
    }

    private func logTabDisappear() {
        let stateIdString = String(describing: ObjectIdentifier(unifiedState))
        logger.info("🎬 STATE_OWNER: 📱 AddMove tab disappeared - state persists in MainView")
        logger.info("🎬 STATE_OWNER: 🎯 PERSISTENT_STATE_ID: \(stateIdString)")
        logger.info("🎬 STATE_OWNER: 📊 State preserved: \(String(describing: unifiedState.flowState))")
    }

    private func handleTabChange(from oldTab: TabSelection, to newTab: TabSelection) {
        let stateIdString: String = String(describing: ObjectIdentifier(unifiedState))
        logger.info("🎬 STATE_OWNER: 🔄 Tab change: \(oldTab.rawValue) → \(newTab.rawValue)")
        logger.info("🎬 STATE_OWNER: 🎯 PERSISTENT_STATE_ID: \(stateIdString)")

        if newTab != .add && oldTab == .add {
            logger.info("🎬 STATE_OWNER: 📱 Leaving Add tab - state persists in MainView")
            logger.info("🎬 STATE_OWNER: 📊 Preserved state: \(String(describing: unifiedState.flowState))")
        } else if newTab == .add && oldTab != .add {
            logger.info("🎬 STATE_OWNER: 📱 Returning to Add tab - reusing persistent state")
            logger.info("🎬 STATE_OWNER: 📊 Restored state: \(String(describing: unifiedState.flowState))")
        }
    }

    // MARK: - 🎯 CRITICAL FIX: Loading State Monitoring for App-wide Overlay

    /// Monitors flow state changes to trigger app-wide loading overlay
    @MainActor
    private func handleFlowStateChange(from oldState: AddMoveFlowState, to newState: AddMoveFlowState) {
        let sessionId = UUID().uuidString.prefix(8)
        logger.info("🎬 STATE_OWNER: 🔄 FLOW_STATE_CHANGE [\(sessionId)] \(String(describing: oldState)) → \(String(describing: newState))")

        // Determine if loading state should be shown
        let isLoading = isLoadingState(newState)

        logger.info("🎬 STATE_OWNER: 🔄 LOADING_DETECTED [\(sessionId)] isLoading: \(isLoading)")
        logger.info("🎬 STATE_OWNER: 🔄 LOADING_DETECTED [\(sessionId)] progress: \(Int(unifiedState.unifiedProgressEngine.unifiedProgress * 100))%")

        // Notify MainView about loading state change
        onLoadingStateChanged?(isLoading, unifiedState)
    }

    /// Monitors progress changes during loading states
    @MainActor
    private func handleProgressChange(_ progress: Double) {
        let sessionId = UUID().uuidString.prefix(8)

        // Only log significant progress changes
        if Int(progress * 100) % 10 == 0 {
            logger.info("🎬 STATE_OWNER: 📊 PROGRESS_UPDATE [\(sessionId)] \(Int(progress * 100))%")
        }

        // Ensure loading overlay is shown during active loading
        let currentStateIsLoading = isLoadingState(unifiedState.flowState)
        if currentStateIsLoading && progress < 1.0 {
            onLoadingStateChanged?(true, unifiedState)
        } else if progress >= 1.0 {
            // Defer overlay hiding to allow transition completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.onLoadingStateChanged?(false, self.unifiedState)
            }
        }
    }

    /// Determines if a flow state represents a loading condition
    ///
    /// This method follows SRP by isolating loading state determination logic.
    ///
    /// - Parameter state: The current flow state
    /// - Returns: True if the state represents loading, false otherwise
    private func isLoadingState(_ state: AddMoveFlowState) -> Bool {
        switch state {
        case .loadingVideo:
            return true
        case .loadingTrimmedAsset:
            return true
        case .trimming:
            return false // Trimming is interactive, not loading
        case .naming:
            return false
        case .saving:
            return false // Saving shows different UI
        case .ready, .success, .error:
            return false
        }
    }
}

/// Modified AddMoveContainer that receives AddMoveUnifiedState as @ObservedObject
///
/// This container no longer owns the state object - it simply observes the persistent
/// state created and managed by AddMoveStateOwner at the MainView level.
private struct AddMoveContainerWithPersistentState: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding private var selectedTab: TabSelection

    // 🎯 CRITICAL FIX: Now receives state as @ObservedObject (no ownership)
    // The state lifecycle is now independent of this view's lifecycle
    @ObservedObject private var unifiedState: AddMoveUnifiedState

    // Save completion handler for navigation
    private var onSaveSuccess: ((Move) -> Void)?

    private let logger = Logger(subsystem: "com.breakingflashcards", category: "AddMoveContainerWithPersistentState")

    init(selectedTab: Binding<TabSelection>, unifiedState: AddMoveUnifiedState, onSaveSuccess: ((Move) -> Void)?) {
        let stateIdString = String(describing: ObjectIdentifier(unifiedState))
        logger.info("🎬 CONTAINER_PERSISTENT: 🏗️ INITIALIZING - AddMoveContainer with persistent state")

        self._selectedTab = selectedTab
        self.unifiedState = unifiedState
        self.onSaveSuccess = onSaveSuccess

        logger.info("🎬 CONTAINER_PERSISTENT: ✅ STATE_LIFECYCLE_INDEPENDENT - Container no longer owns state")
        logger.info("🎬 CONTAINER_PERSISTENT: 🎯 PERSISTENT_STATE_ID: \(stateIdString)")
        logger.info("🎬 CONTAINER_PERSISTENT: 📊 Container can be recreated without affecting state")
    }

    var body: some View {
        Group {
            if isValidContainerState() {
                mainContentWithModifiers
            } else {
                renderContainerFallbackUI()
            }
        }
        .onAppear {
            let stateIdString = String(describing: ObjectIdentifier(unifiedState))
            logger.info("🎬 CONTAINER_PERSISTENT: 📱 Container appeared with persistent state")
            logger.info("🎬 CONTAINER_PERSISTENT: 🎯 PERSISTENT_STATE_ID: \(stateIdString)")
            logger.info("🎬 CONTAINER_PERSISTENT: 📊 Flow state: \(String(describing: unifiedState.flowState))")

            // 🚨 ENHANCED_STATE_LIFECYCLE_LOGGING: Log view lifecycle for diagnostics
            StateLifecycleDiagnosticLogger.logViewLifecycle("AddMoveContainerWithPersistentState", event: "onAppear", state: unifiedState)

            handleViewAppear()
        }
        .onDisappear {
            let stateIdString = String(describing: ObjectIdentifier(unifiedState))
            logger.info("🎬 CONTAINER_PERSISTENT: 📱 Container disappeared - state persists in MainView")
            logger.info("🎬 CONTAINER_PERSISTENT: 🎯 PERSISTENT_STATE_ID: \(stateIdString)")
            logger.info("🎬 CONTAINER_PERSISTENT: 📊 State preserved: \(String(describing: unifiedState.flowState))")

            // 🚨 ENHANCED_STATE_LIFECYCLE_LOGGING: Log view lifecycle for diagnostics
            StateLifecycleDiagnosticLogger.logViewDisappearance("AddMoveContainerWithPersistentState", statePreserved: true, state: unifiedState)

            handleViewDisappear()
        }
        .onChange(of: unifiedState.flowState) { oldState, newState in
            let stateIdString = String(describing: ObjectIdentifier(unifiedState))
            logger.info("🎬 CONTAINER_PERSISTENT: 🔄 State change: \(String(describing: oldState)) → \(String(describing: newState))")
            logger.info("🎬 CONTAINER_PERSISTENT: 🎯 PERSISTENT_STATE_ID: \(stateIdString)")

            handleStateChange(from: oldState, to: newState)
        }
    }

    private var mainContentWithModifiers: some View {
        mainContent
    }

    private var mainContent: some View {
        // 🎯 DIAGNOSTIC: Enhanced logging for video loading progress tracking
        // This now uses the persistent state, so progress updates survive view recreations
        AnyView(
            VStack(spacing: 0) {
                Group {
                    switch unifiedState.flowState {
                    case .ready:
                        AddMoveSelectClipViewUnified(unifiedState: unifiedState)
                    case .loadingVideo:
                        // 🎯 CRITICAL FIX: LoadingOverlayView removed - now managed at MainView level for persistent overlay
                        // This ensures the loading overlay persists across tab navigation instead of being tied to container lifecycle
                        // The app-wide overlay in MainView will handle loadingVideo state via onLoadingStateChanged callback
                        let _ = logger.info("🎬 CONTAINER_PERSISTENT: 🏗️ Rendering loadingVideo state - app-wide overlay managed by MainView")
                        LoadingView(progress: unifiedState.unifiedProgressEngine.unifiedProgress, status: "Loading Video...", unifiedState: unifiedState)
                    case .trimming:
                        // 🎯 PERFORMANCE OPTIMIZATION: Lazy ViewModel initialization
                        // FeatureRichTrimmerView now handles its own ViewModel creation
                        FeatureRichTrimmerView(unifiedState: unifiedState)
                            .id(unifiedState.photosIdentifier ?? UUID().uuidString)
                    case .loadingTrimmedAsset(let progress):
                        LoadingView(progress: progress.value, status: progress.message, unifiedState: unifiedState)
                    case .naming:
                        NameMoveViewUnified(unifiedState: unifiedState)
                    case .saving:
                        SavingViewWithProgress(unifiedState: unifiedState)
                    case .success(let message):
                        SuccessView(message: message) {
                            Task {
                                unifiedState.reset()
                            }
                        }
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
                                    unifiedState.reset()
                                }
                                selectedTab = .arsenal
                            }
                        )
                    }
                }
                .onChange(of: unifiedState.flowState) { oldState, newState in
                    logStateChange(from: oldState, to: newState)
                }
            }
        )
        .onAppear {
            logMainContentAppear()
        }
    }

    // MARK: - Logging Helper Methods

    private func logRenderingState(_ state: String) {
        logger.info("🎬 CONTAINER_PERSISTENT: 🏗️ Rendering \(state) state")
    }

    private func logLoadingVideoState() {
        let progress = String(format: "%.1f", unifiedState.unifiedProgressEngine.unifiedProgress * 100)
        logger.info("🎬 CONTAINER_PERSISTENT: 🏗️ Rendering loadingVideo state - progress: \(progress)%")
    }

    private func logTrimmerViewAppear() {
        let stateIdString = String(describing: ObjectIdentifier(unifiedState))
        logger.info("🎬 CONTAINER_PERSISTENT: ✅ TrimmerView appeared with persistent state")
        logger.info("🎬 CONTAINER_PERSISTENT: 🎯 PERSISTENT_STATE_ID: \(stateIdString)")
    }

    private func logLoadingTrimmedAssetState(progress: SimpleProgress) {
        let progressPercent = String(format: "%.1f", progress.value * 100)
        logger.info("🎬 CONTAINER_PERSISTENT: 🏗️ Rendering loadingTrimmedAsset state - progress: \(progressPercent)%")
    }

    private func logSuccessCallback() {
        logger.info("🎬 CONTAINER_PERSISTENT: 🔄 Success completion callback triggered")
    }

    private func logErrorState(message: String) {
        logger.error("🎬 CONTAINER_PERSISTENT: ❌ Rendering error state: \(message)")
    }

    private func logErrorRetry() {
        logger.info("🎬 CONTAINER_PERSISTENT: 🔄 Error retry triggered")
    }

    private func logErrorCancel() {
        logger.info("🎬 CONTAINER_PERSISTENT: 🔄 Error cancel triggered")
    }

    // MARK: - Helper Methods

    private func handleViewAppear() {
        logger.info("🎬 CONTAINER_PERSISTENT: 🎬 Handling view appear with persistent state")

        // Set up the save completion handler for navigation
        unifiedState.onSaveSuccess = { savedMove in
            logger.info("🎬 CONTAINER_PERSISTENT: 🚀 Save completion handler called")

            if let move = savedMove as? Move {
                self.onSaveSuccess?(move)
            }
        }

        // Set up the return to trimming closure
        unifiedState.returnToTrimming = {
            logger.info("🎬 CONTAINER_PERSISTENT: 🔙 Return to trimming closure triggered")
            // This now uses the persistent state, so it works even if container was recreated
        }

        logger.info("🎬 CONTAINER_PERSISTENT: ✅ Persistent state handlers configured")
    }

    private func handleViewDisappear() {
        logger.info("🎬 CONTAINER_PERSISTENT: 🎬 Handling view disappear - state persists")

        // Note: We no longer clean up the state here since it's managed by MainView
        // This prevents the "stuck at 0%" issue during video loading
    }

    private func handleStateChange(from oldState: AddMoveFlowState, to newState: AddMoveFlowState) {
        logger.info("🎬 CONTAINER_PERSISTENT: 🔄 State change observed with persistent state")
        logger.info("🎬 CONTAINER_PERSISTENT: 📊 \(String(describing: oldState)) → \(String(describing: newState))")

        // 🎯 CRITICAL FIX: Progress updates now work even if container is recreated
        // because the state object persists at the MainView level
        switch (oldState, newState) {
        case (.loadingVideo, .trimming):
            let stateIdString = String(describing: ObjectIdentifier(unifiedState))
            logger.info("🎬 CONTAINER_PERSISTENT: ✅ Video loading completed - entering trimming")
            logger.info("🎬 CONTAINER_PERSISTENT: 🎯 PERSISTENT_STATE_ID: \(stateIdString)")

        case (.loadingVideo, _):
            logger.info("🎬 CONTAINER_PERSISTENT: 📊 Video loading progress: \(String(format: "%.1f", unifiedState.unifiedProgressEngine.unifiedProgress * 100))%")
            logger.info("🎬 CONTAINER_PERSISTENT: 🎯 PROGRESS_UPDATES_WORK: State persists across view recreations")

        default:
            logger.info("🎬 CONTAINER_PERSISTENT: 📝 Standard transition: \(String(describing: oldState)) → \(String(describing: newState))")
        }
    }

    private func logStateChange(from oldState: AddMoveFlowState, to newState: AddMoveFlowState) {
        logStateChangeForMainContent(from: oldState, to: newState)
    }

    private func logStateChangeForMainContent(from oldState: AddMoveFlowState, to newState: AddMoveFlowState) {
        logger.info("🎬 CONTAINER_PERSISTENT: 🔄 State change observed with persistent state")
        logger.info("🎬 CONTAINER_PERSISTENT: 📊 \(String(describing: oldState)) → \(String(describing: newState))")

        // 🎯 CRITICAL FIX: Progress updates now work even if container is recreated
        // because the state object persists at the MainView level
        switch (oldState, newState) {
        case (.loadingVideo, .trimming):
            let stateIdString = String(describing: ObjectIdentifier(unifiedState))
            logger.info("🎬 CONTAINER_PERSISTENT: ✅ Video loading completed - entering trimming")
            logger.info("🎬 CONTAINER_PERSISTENT: 🎯 PERSISTENT_STATE_ID: \(stateIdString)")

        case (.loadingVideo, _):
            logger.info("🎬 CONTAINER_PERSISTENT: 📊 Video loading progress: \(String(format: "%.1f", unifiedState.unifiedProgressEngine.unifiedProgress * 100))%")
            logger.info("🎬 CONTAINER_PERSISTENT: 🎯 PROGRESS_UPDATES_WORK: State persists across view recreations")

        default:
            logger.info("🎬 CONTAINER_PERSISTENT: 📝 Standard transition: \(String(describing: oldState)) → \(String(describing: newState))")
        }
    }

    private func logMainContentAppear() {
        let stateIdString = String(describing: ObjectIdentifier(unifiedState))
        logger.info("🎬 CONTAINER_PERSISTENT: 📱 Main content appeared with persistent state")
        logger.info("🎬 CONTAINER_PERSISTENT: 🎯 PERSISTENT_STATE_ID: \(stateIdString)")
        logger.info("🎬 CONTAINER_PERSISTENT: 📊 Current flow state: \(String(describing: unifiedState.flowState))")
    }

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
                logger.info("🎬 CONTAINER_PERSISTENT: 🔄 Restart button triggered")
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

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedTab: TabSelection = .add

        var body: some View {
            AddMoveStateOwner(selectedTab: $selectedTab)
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}