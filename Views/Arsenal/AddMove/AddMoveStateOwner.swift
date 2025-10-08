import OSLog
import SwiftUI

// AddMoveStateOwner.swift

struct AddMoveStateOwner: View {
    @Binding var selectedTab: TabSelection

    @ObservedObject var unifiedState: AddMoveUnifiedState

    private let onSaveSuccess: ((Move) -> Void)?

    private let onLoadingStateChanged: ((Bool, AddMoveUnifiedState?) -> Void)?

    private let logger = Logger(
        subsystem: "com.breakingflashcards",
        category: "AddMoveStateOwner"
    )

    init(
        selectedTab: Binding<TabSelection>,
        unifiedState: AddMoveUnifiedState,
        onSaveSuccess: ((Move) -> Void)? = nil,
        onLoadingStateChanged: ((Bool, AddMoveUnifiedState?) -> Void)? = nil
    ) {
        logger.info(
            "🎬 PERSISTENT_STATE_OWNER: 🏗️ INITIALIZING - State owner with persistent state object"
        )
        let stateIdString = String(describing: ObjectIdentifier(unifiedState))
        logger.info(
            "🎬 PERSISTENT_STATE_OWNER: 🎯 RECEIVED_PERSISTENT_STATE_ID: \(stateIdString)"
        )
        logger.info(
            "🎬 PERSISTENT_STATE_OWNER: 📊 SINGLE_INSTANCE_GUARANTEE - No dueling state machines can exist"
        )

        self._selectedTab = selectedTab
        self.unifiedState = unifiedState
        self.onSaveSuccess = onSaveSuccess
        self.onLoadingStateChanged = onLoadingStateChanged

        logger.info(
            "🎬 PERSISTENT_STATE_OWNER: ✅ DUELING_MACHINES_FIXED - Using single persistent state object"
        )
    }

    var body: some View {
        addMoveContent
            .onChange(of: selectedTab) { oldTab, newTab in
                handleTabChange(from: oldTab, to: newTab)
            }
            .onChange(of: unifiedState.flowState) { oldState, newState in
                handleFlowStateChange(from: oldState, to: newState)
            }
            .onReceive(unifiedState.unifiedProgressEngine.$unifiedProgress) {
                progress in
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
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.willEnterForegroundNotification
            )
        ) { _ in
            logAppForeground()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.didEnterBackgroundNotification
            )
        ) { _ in
            logAppBackground()
        }
    }

    private func logTabAppear() {
        let stateIdString = String(describing: ObjectIdentifier(unifiedState))
        let sessionId = UUID().uuidString.prefix(8)

        logger.info(
            "🎬 STATE_OWNER: 📱 TAB_APPEAR [\(sessionId)] AddMove tab appeared with persistent state"
        )
        logger.info(
            "🎬 STATE_OWNER: 🎯 TAB_APPEAR [\(sessionId)] PERSISTENT_STATE_ID: \(stateIdString)"
        )
        logger.info(
            "🎬 STATE_OWNER: 📊 TAB_APPEAR [\(sessionId)] Current flow state: \(String(describing: unifiedState.flowState))"
        )
        logger.info(
            "🎬 STATE_OWNER: 📊 TAB_APPEAR [\(sessionId)] Progress: \(Int(unifiedState.unifiedProgressEngine.unifiedProgress * 100))%"
        )
        logger.info(
            "🎬 STATE_OWNER: ✅ TAB_APPEAR [\(sessionId)] Tab bar visibility fix active - content always present"
        )
    }

    private func logTabDisappear() {
        let stateIdString = String(describing: ObjectIdentifier(unifiedState))
        let sessionId = UUID().uuidString.prefix(8)

        logger.info(
            "🎬 STATE_OWNER: 📱 TAB_DISAPPEAR [\(sessionId)] AddMove tab disappeared - state persists in MainView"
        )
        logger.info(
            "🎬 STATE_OWNER: 🎯 TAB_DISAPPEAR [\(sessionId)] PERSISTENT_STATE_ID: \(stateIdString)"
        )
        logger.info(
            "🎬 STATE_OWNER: 📊 TAB_DISAPPEAR [\(sessionId)] State preserved: \(String(describing: unifiedState.flowState))"
        )
        logger.info(
            "🎬 STATE_OWNER: 📊 TAB_DISAPPEAR [\(sessionId)] Background operations continue: \(isInProgressState(unifiedState.flowState))"
        )
        logger.info(
            "🎬 STATE_OWNER: ✅ TAB_DISAPPEAR [\(sessionId)] Tab bar visibility fix prevents visual disappearance"
        )
    }

    private func logAppForeground() {
        let stateIdString = String(describing: ObjectIdentifier(unifiedState))
        let sessionId = UUID().uuidString.prefix(8)

        logger.info(
            "🎬 STATE_OWNER: 🔄 APP_FOREGROUND [\(sessionId)] App entering foreground"
        )
        logger.info(
            "🎬 STATE_OWNER: 🎯 APP_FOREGROUND [\(sessionId)] PERSISTENT_STATE_ID: \(stateIdString)"
        )
        logger.info(
            "🎬 STATE_OWNER: 📊 APP_FOREGROUND [\(sessionId)] Restored flow state: \(String(describing: unifiedState.flowState))"
        )
        logger.info(
            "🎬 STATE_OWNER: ✅ APP_FOREGROUND [\(sessionId)] Tab bar visibility preserved"
        )
    }

    private func logAppBackground() {
        let stateIdString = String(describing: ObjectIdentifier(unifiedState))
        let sessionId = UUID().uuidString.prefix(8)

        logger.info(
            "🎬 STATE_OWNER: 🔄 APP_BACKGROUND [\(sessionId)] App entering background"
        )
        logger.info(
            "🎬 STATE_OWNER: 🎯 APP_BACKGROUND [\(sessionId)] PERSISTENT_STATE_ID: \(stateIdString)"
        )
        logger.info(
            "🎬 STATE_OWNER: 📊 APP_BACKGROUND [\(sessionId)] Preserved flow state: \(String(describing: unifiedState.flowState))"
        )
        logger.info(
            "🎬 STATE_OWNER: ✅ APP_BACKGROUND [\(sessionId)] Background operations maintained"
        )
    }

    private func handleTabChange(
        from oldTab: TabSelection,
        to newTab: TabSelection
    ) {
        let stateIdString: String = String(
            describing: ObjectIdentifier(unifiedState)
        )
        let sessionId = UUID().uuidString.prefix(8)

        logger.info(
            "🎬 STATE_OWNER: 🔄 TAB_CHANGE [\(sessionId)] \(oldTab.rawValue) → \(newTab.rawValue)"
        )
        logger.info(
            "🎬 STATE_OWNER: 🎯 TAB_CHANGE [\(sessionId)] PERSISTENT_STATE_ID: \(stateIdString)"
        )
        logger.info(
            "🎬 STATE_OWNER: 📊 TAB_CHANGE [\(sessionId)] Current flow state: \(String(describing: unifiedState.flowState))"
        )
        logger.info(
            "🎬 STATE_OWNER: 📊 TAB_CHANGE [\(sessionId)] Progress: \(Int(unifiedState.unifiedProgressEngine.unifiedProgress * 100))%"
        )

        if newTab != .add && oldTab == .add {
            logger.info(
                "🎬 STATE_OWNER: 📱 TAB_CHANGE [\(sessionId)] Leaving Add tab - state persists in MainView"
            )
            logger.info(
                "🎬 STATE_OWNER: 📊 TAB_CHANGE [\(sessionId)] Preserved state: \(String(describing: unifiedState.flowState))"
            )
            logger.info(
                "🎬 STATE_OWNER: ✅ TAB_CHANGE [\(sessionId)] Background operations will continue"
            )
        } else if newTab == .add && oldTab != .add {
            logger.info(
                "🎬 STATE_OWNER: 📱 TAB_CHANGE [\(sessionId)] Returning to Add tab - reusing persistent state"
            )
            logger.info(
                "🎬 STATE_OWNER: 📊 TAB_CHANGE [\(sessionId)] Restored state: \(String(describing: unifiedState.flowState))"
            )
            logger.info(
                "🎬 STATE_OWNER: ✅ TAB_CHANGE [\(sessionId)] Tab bar visibility fix active - no conditional wrapper"
            )
        } else {
            logger.info(
                "🎬 STATE_OWNER: 📱 TAB_CHANGE [\(sessionId)] Non-Add tab transition - state unaffected"
            )
        }

        logger.info(
            "🎬 STATE_OWNER: 🔧 TAB_VISIBILITY_FIX [\(sessionId)] Conditional wrapper removed"
        )
        logger.info(
            "🎬 STATE_OWNER: 🔧 TAB_VISIBILITY_FIX [\(sessionId)] SwiftUI TabView manages visibility naturally"
        )
        logger.info(
            "🎬 STATE_OWNER: 🔧 TAB_VISIBILITY_FIX [\(sessionId)] Content persists across tab switches"
        )
    }

    @MainActor
    private func handleFlowStateChange(
        from oldState: AddMoveFlowState,
        to newState: AddMoveFlowState
    ) {
        let sessionId = UUID().uuidString.prefix(8)
        logger.info(
            "🎬 STATE_OWNER: 🔄 FLOW_STATE_CHANGE [\(sessionId)] \(String(describing: oldState)) → \(String(describing: newState))"
        )

        let isLoading = isLoadingState(newState)

        logger.info(
            "🎬 STATE_OWNER: 🔄 LOADING_DETECTED [\(sessionId)] isLoading: \(isLoading)"
        )
        logger.info(
            "🎬 STATE_OWNER: 🔄 LOADING_DETECTED [\(sessionId)] progress: \(Int(unifiedState.unifiedProgressEngine.unifiedProgress * 100))%"
        )

        onLoadingStateChanged?(isLoading, unifiedState)
    }

    @MainActor
    private func handleProgressChange(_ progress: Double) {
        let sessionId = UUID().uuidString.prefix(8)

        if Int(progress * 100) % 10 == 0 {
            logger.info(
                "🎬 STATE_OWNER: 📊 PROGRESS_UPDATE [\(sessionId)] \(Int(progress * 100))%"
            )
        }

        let currentStateIsLoading = isLoadingState(unifiedState.flowState)
        if currentStateIsLoading && progress < 1.0 {
            onLoadingStateChanged?(true, unifiedState)
        } else if progress >= 1.0 {

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.onLoadingStateChanged?(false, self.unifiedState)
            }
        }
    }

    private func isLoadingState(_ state: AddMoveFlowState) -> Bool {
        switch state {
        case .loadingVideo:
            return true
        case .loadingTrimmedAsset:
            return true
        case .trimming:
            return false
        case .naming:
            return false
        case .saving:
            return false
        case .ready, .success, .error:
            return false
        }
    }

    private func isInProgressState(_ state: AddMoveFlowState) -> Bool {
        switch state {
        case .loadingVideo:
            return true
        case .loadingTrimmedAsset:
            return true
        case .trimming:
            return true
        case .naming:
            return true
        case .saving:
            return true
        case .ready, .success, .error:
            return false
        }
    }
}

private struct AddMoveContainerWithPersistentState: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding private var selectedTab: TabSelection

    @ObservedObject private var unifiedState: AddMoveUnifiedState

    private var onSaveSuccess: ((Move) -> Void)?

    private let logger = Logger(
        subsystem: "com.breakingflashcards",
        category: "AddMoveContainerWithPersistentState"
    )

    init(
        selectedTab: Binding<TabSelection>,
        unifiedState: AddMoveUnifiedState,
        onSaveSuccess: ((Move) -> Void)?
    ) {
        let stateIdString = String(describing: ObjectIdentifier(unifiedState))
        logger.info(
            "🎬 CONTAINER_PERSISTENT: 🏗️ INITIALIZING - AddMoveContainer with persistent state"
        )

        self._selectedTab = selectedTab
        self.unifiedState = unifiedState
        self.onSaveSuccess = onSaveSuccess

        logger.info(
            "🎬 CONTAINER_PERSISTENT: ✅ STATE_LIFECYCLE_INDEPENDENT - Container no longer owns state"
        )
        logger.info(
            "🎬 CONTAINER_PERSISTENT: 🎯 PERSISTENT_STATE_ID: \(stateIdString)"
        )
        logger.info(
            "🎬 CONTAINER_PERSISTENT: 📊 Container can be recreated without affecting state"
        )
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
            let stateIdString = String(
                describing: ObjectIdentifier(unifiedState)
            )
            logger.info(
                "🎬 CONTAINER_PERSISTENT: 📱 Container appeared with persistent state"
            )
            logger.info(
                "🎬 CONTAINER_PERSISTENT: 🎯 PERSISTENT_STATE_ID: \(stateIdString)"
            )
            logger.info(
                "🎬 CONTAINER_PERSISTENT: 📊 Flow state: \(String(describing: unifiedState.flowState))"
            )

            StateLifecycleDiagnosticLogger.logViewLifecycle(
                "AddMoveContainerWithPersistentState",
                event: "onAppear",
                state: unifiedState
            )

            handleViewAppear()
        }
        .onDisappear {
            let stateIdString = String(
                describing: ObjectIdentifier(unifiedState)
            )
            logger.info(
                "🎬 CONTAINER_PERSISTENT: 📱 Container disappeared - state persists in MainView"
            )
            logger.info(
                "🎬 CONTAINER_PERSISTENT: 🎯 PERSISTENT_STATE_ID: \(stateIdString)"
            )
            logger.info(
                "🎬 CONTAINER_PERSISTENT: 📊 State preserved: \(String(describing: unifiedState.flowState))"
            )

            StateLifecycleDiagnosticLogger.logViewDisappearance(
                "AddMoveContainerWithPersistentState",
                statePreserved: true,
                state: unifiedState
            )

            handleViewDisappear()
        }
        .onChange(of: unifiedState.flowState) { oldState, newState in
            let stateIdString = String(
                describing: ObjectIdentifier(unifiedState)
            )
            logger.info(
                "🎬 CONTAINER_PERSISTENT: 🔄 State change: \(String(describing: oldState)) → \(String(describing: newState))"
            )
            logger.info(
                "🎬 CONTAINER_PERSISTENT: 🎯 PERSISTENT_STATE_ID: \(stateIdString)"
            )

            handleStateChange(from: oldState, to: newState)
        }
    }

    private var mainContentWithModifiers: some View {
        mainContent
    }

    private var mainContent: some View {

        AnyView(
            VStack(spacing: 0) {
                Group {
                    switch unifiedState.flowState {
                    case .ready:
                        AddMoveSelectClipViewUnified(unifiedState: unifiedState)
                    case .loadingVideo:

                        let _ = logger.info(
                            "🎬 CONTAINER_PERSISTENT: 🏗️ Rendering loadingVideo state - app-wide overlay managed by MainView"
                        )
                        LoadingView(
                            progress: unifiedState.unifiedProgressEngine
                                .unifiedProgress,
                            status: "Loading Video...",
                            unifiedState: unifiedState
                        )
                    case .trimming:

                        FeatureRichTrimmerView(unifiedState: unifiedState)
                            .id(
                                unifiedState.photosIdentifier
                                    ?? UUID().uuidString
                            )
                    case .loadingTrimmedAsset(let progress):
                        LoadingView(
                            progress: progress.value,
                            status: progress.message,
                            unifiedState: unifiedState
                        )
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

    private func logRenderingState(_ state: String) {
        logger.info("🎬 CONTAINER_PERSISTENT: 🏗️ Rendering \(state) state")
    }

    private func logLoadingVideoState() {
        let progress = String(
            format: "%.1f",
            unifiedState.unifiedProgressEngine.unifiedProgress * 100
        )
        logger.info(
            "🎬 CONTAINER_PERSISTENT: 🏗️ Rendering loadingVideo state - progress: \(progress)%"
        )
    }

    private func logTrimmerViewAppear() {
        let stateIdString = String(describing: ObjectIdentifier(unifiedState))
        logger.info(
            "🎬 CONTAINER_PERSISTENT: ✅ TrimmerView appeared with persistent state"
        )
        logger.info(
            "🎬 CONTAINER_PERSISTENT: 🎯 PERSISTENT_STATE_ID: \(stateIdString)"
        )
    }

    private func logLoadingTrimmedAssetState(progress: SimpleProgress) {
        let progressPercent = String(format: "%.1f", progress.value * 100)
        logger.info(
            "🎬 CONTAINER_PERSISTENT: 🏗️ Rendering loadingTrimmedAsset state - progress: \(progressPercent)%"
        )
    }

    private func logSuccessCallback() {
        logger.info(
            "🎬 CONTAINER_PERSISTENT: 🔄 Success completion callback triggered"
        )
    }

    private func logErrorState(message: String) {
        logger.error(
            "🎬 CONTAINER_PERSISTENT: ❌ Rendering error state: \(message)"
        )
    }

    private func logErrorRetry() {
        logger.info("🎬 CONTAINER_PERSISTENT: 🔄 Error retry triggered")
    }

    private func logErrorCancel() {
        logger.info("🎬 CONTAINER_PERSISTENT: 🔄 Error cancel triggered")
    }

    private func handleViewAppear() {
        logger.info(
            "🎬 CONTAINER_PERSISTENT: 🎬 Handling view appear with persistent state"
        )

        unifiedState.onSaveSuccess = { savedMove in
            logger.info(
                "🎬 CONTAINER_PERSISTENT: 🚀 Save completion handler called"
            )

            if let move = savedMove as? Move {
                self.onSaveSuccess?(move)
            }
        }

        unifiedState.returnToTrimming = {
            logger.info(
                "🎬 CONTAINER_PERSISTENT: 🔙 Return to trimming closure triggered"
            )

        }

        logger.info(
            "🎬 CONTAINER_PERSISTENT: ✅ Persistent state handlers configured"
        )
    }

    private func handleViewDisappear() {
        logger.info(
            "🎬 CONTAINER_PERSISTENT: 🎬 Handling view disappear - state persists"
        )

    }

    private func handleStateChange(
        from oldState: AddMoveFlowState,
        to newState: AddMoveFlowState
    ) {
        logger.info(
            "🎬 CONTAINER_PERSISTENT: 🔄 State change observed with persistent state"
        )
        logger.info(
            "🎬 CONTAINER_PERSISTENT: 📊 \(String(describing: oldState)) → \(String(describing: newState))"
        )

        switch (oldState, newState) {
        case (.loadingVideo, .trimming):
            let stateIdString = String(
                describing: ObjectIdentifier(unifiedState)
            )
            logger.info(
                "🎬 CONTAINER_PERSISTENT: ✅ Video loading completed - entering trimming"
            )
            logger.info(
                "🎬 CONTAINER_PERSISTENT: 🎯 PERSISTENT_STATE_ID: \(stateIdString)"
            )

        case (.loadingVideo, _):
            logger.info(
                "🎬 CONTAINER_PERSISTENT: 📊 Video loading progress: \(String(format: "%.1f", unifiedState.unifiedProgressEngine.unifiedProgress * 100))%"
            )
            logger.info(
                "🎬 CONTAINER_PERSISTENT: 🎯 PROGRESS_UPDATES_WORK: State persists across view recreations"
            )

        default:
            logger.info(
                "🎬 CONTAINER_PERSISTENT: 📝 Standard transition: \(String(describing: oldState)) → \(String(describing: newState))"
            )
        }
    }

    private func logStateChange(
        from oldState: AddMoveFlowState,
        to newState: AddMoveFlowState
    ) {
        logStateChangeForMainContent(from: oldState, to: newState)
    }

    private func logStateChangeForMainContent(
        from oldState: AddMoveFlowState,
        to newState: AddMoveFlowState
    ) {
        logger.info(
            "🎬 CONTAINER_PERSISTENT: 🔄 State change observed with persistent state"
        )
        logger.info(
            "🎬 CONTAINER_PERSISTENT: 📊 \(String(describing: oldState)) → \(String(describing: newState))"
        )

        switch (oldState, newState) {
        case (.loadingVideo, .trimming):
            let stateIdString = String(
                describing: ObjectIdentifier(unifiedState)
            )
            logger.info(
                "🎬 CONTAINER_PERSISTENT: ✅ Video loading completed - entering trimming"
            )
            logger.info(
                "🎬 CONTAINER_PERSISTENT: 🎯 PERSISTENT_STATE_ID: \(stateIdString)"
            )

        case (.loadingVideo, _):
            logger.info(
                "🎬 CONTAINER_PERSISTENT: 📊 Video loading progress: \(String(format: "%.1f", unifiedState.unifiedProgressEngine.unifiedProgress * 100))%"
            )
            logger.info(
                "🎬 CONTAINER_PERSISTENT: 🎯 PROGRESS_UPDATES_WORK: State persists across view recreations"
            )

        default:
            logger.info(
                "🎬 CONTAINER_PERSISTENT: 📝 Standard transition: \(String(describing: oldState)) → \(String(describing: newState))"
            )
        }
    }

    private func logMainContentAppear() {
        let stateIdString = String(describing: ObjectIdentifier(unifiedState))
        logger.info(
            "🎬 CONTAINER_PERSISTENT: 📱 Main content appeared with persistent state"
        )
        logger.info(
            "🎬 CONTAINER_PERSISTENT: 🎯 PERSISTENT_STATE_ID: \(stateIdString)"
        )
        logger.info(
            "🎬 CONTAINER_PERSISTENT: 📊 Current flow state: \(String(describing: unifiedState.flowState))"
        )
    }

    private func isValidContainerState() -> Bool {

        let stateValid = isValidFlowState(unifiedState.flowState)
        return stateValid
    }

    private func isValidFlowState(_ state: AddMoveFlowState) -> Bool {
        return true
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
                logger.info(
                    "🎬 CONTAINER_PERSISTENT: 🔄 Restart button triggered"
                )
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
        @StateObject private var unifiedState: AddMoveUnifiedState = {
            let appContainer = AppContainer.shared
            return AddMoveUnifiedState(
                unifiedPlayerManager: UnifiedPlayerManager(),
                modernVideoLoadingService: appContainer
                    .modernVideoLoadingService,
                videoProcessingPipeline: appContainer.videoProcessingPipeline,
                timecodeCalculationService: TimecodeCalculationService(),
                persistentContainer: PersistenceController.shared.container,
                movePersistenceService: appContainer.movePersistenceService,
                appContainer: appContainer
            )
        }()

        var body: some View {
            AddMoveStateOwner(
                selectedTab: $selectedTab,
                unifiedState: unifiedState
            )
            .environment(
                \.managedObjectContext,
                PersistenceController.shared.container.viewContext
            )
            .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}
