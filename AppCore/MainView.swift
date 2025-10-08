import CoreData
import Foundation
import OSLog
import SwiftUI

// MainView.swift

private let logger = Logger(
    subsystem: "com.breakingflashcards",
    category: "MainView"
)

enum TabSelection: String, Hashable {
    case arsenal = "ArsenalTab"
    case add = "AddTab"
    case combo = "ComboTab"
    case review = "ReviewTab"
}

struct MainView: View {
    @State private var selectedTab: TabSelection = .add

    @State private var navigateToMoveDetail: Bool = false
    @State private var savedMove: Move?

    @State private var showLoadingOverlay: Bool = false
    @State private var loadingOverlayUnifiedState: AddMoveUnifiedState?

    @StateObject private var unifiedState: AddMoveUnifiedState

    init() {

        logger.info(
            "🎬 MAIN_VIEW: 🏗️ INITIALIZING - Creating stable AddMoveUnifiedState instance"
        )
        logger.info(
            "🎬 MAIN_VIEW: 🎯 DUELING_MACHINES_FIX - Single state object prevents multiple state machines"
        )

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

        logger.info(
            "🎬 MAIN_VIEW: ✅ STABLE_STATE_OBJECT_CREATED - AddMoveUnifiedState will persist for app lifetime"
        )
        let stateIdString = String(
            describing: ObjectIdentifier(persistentState)
        )
        logger.info("🎬 MAIN_VIEW: 🎯 PERSISTENT_STATE_ID: \(stateIdString)")
    }

    var body: some View {
        ZStack {

            NavigationStack {
                EnhancedTabView(selection: $selectedTab) {

                    // MAIN: - Arsenal Tab
                    BreakingArsenalView(selectedTab: $selectedTab)
                        .tabItem {
                            Label {
                                Text("Arsenal").font(.ibmPlexMono(size: 12))
                            } icon: {
                                Image(systemName: "book.closed")
                            }
                        }
                        .tag(TabSelection.arsenal)
                        .accessibilityLabel("Breaking Arsenal")
                        .accessibilityHint(
                            "View your collection of breaking moves, or combos"
                        )

                    // MAIN: - Add Move Tab
                    AddMoveStateOwner(
                        selectedTab: $selectedTab,
                        unifiedState: unifiedState,
                        onSaveSuccess: { savedMove in

                            logger.info(
                                "🎬 MAIN_VIEW: Save success callback triggered for move: \(savedMove.name ?? "unnamed")"
                            )

                            self.savedMove = savedMove
                            self.navigateToMoveDetail = true

                            DispatchQueue.main.asyncAfter(
                                deadline: .now() + 0.1
                            ) {
                                logger.info(
                                    "🎬 MAIN_VIEW: Switching to Arsenal tab for navigation context"
                                )
                                selectedTab = .arsenal

                                DispatchQueue.main.asyncAfter(
                                    deadline: .now() + 0.2
                                ) {
                                    logger.info(
                                        "🎬 MAIN_VIEW: Executing navigation to MoveDetailView for move: \(savedMove.name ?? "unnamed")"
                                    )
                                    self.navigateToMoveDetail = true
                                }
                            }
                        },
                        onLoadingStateChanged: { isLoading, unifiedState in

                            logger.info(
                                "🎬 MAIN_VIEW: 🔄 Loading state changed - isLoading: \(isLoading)"
                            )
                            handleLoadingStateChange(
                                isLoading: isLoading,
                                unifiedState: unifiedState
                            )
                        }
                    )
                    .tabItem {
                        Label {
                            Text("Add").font(.ibmPlexMono(size: 12))
                        } icon: {
                            Image(systemName: "plus.app")
                        }
                    }
                    .tag(TabSelection.add)
                    .accessibilityLabel("Add Move")
                    .accessibilityHint(
                        "Add a new breaking move to your collection"
                    )

                    // MAIN: - Create Combo Tab
                    CreateComboView()
                        .tabItem {
                            Label {
                                Text("Create").font(.ibmPlexMono(size: 12))
                            } icon: {
                                Image(systemName: "wand.and.stars")
                            }
                        }
                        .tag(TabSelection.combo)
                        .accessibilityLabel("Create Combo")
                        .accessibilityHint(
                            "Create a new combination of breaking moves"
                        )

                    // MAIN: - Review Tab
                    ReviewView()
                        .tabItem {
                            Label {
                                Text("Review").font(.ibmPlexMono(size: 12))
                            } icon: {
                                Image(systemName: "skateboard")
                            }
                        }
                        .tag(TabSelection.review)
                        .accessibilityLabel("Review")
                        .accessibilityHint(
                            "Review and practice your breaking moves"
                        )
                }

                .navigationDestination(isPresented: $navigateToMoveDetail) {
                    if let move = savedMove {
                        MoveDetailView(move: move)
                            .onAppear {
                                logger.info(
                                    "🎬 MAIN_VIEW: MoveDetailView appeared successfully for move: \(move.name ?? "unnamed")"
                                )
                            }
                            .onDisappear {
                                logger.info(
                                    "🎬 MAIN_VIEW: MoveDetailView disappeared - resetting navigation state"
                                )
                                self.navigateToMoveDetail = false
                                self.savedMove = nil
                            }
                    } else {

                        Text("Error: Move not found")
                            .foregroundColor(.red)
                            .onAppear {
                                logger.error(
                                    "🎬 MAIN_VIEW: ❌ Navigation triggered but savedMove is nil"
                                )
                            }
                    }
                }
            }

            // MARK: - is this the ideal placement of the loading?
            if showLoadingOverlay, let unifiedState = loadingOverlayUnifiedState
            {
                LoadingOverlayView(unifiedState: unifiedState)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(
                                with: .scale(scale: 0.95)
                            ),
                            removal: .opacity.combined(
                                with: .scale(scale: 1.05)
                            )
                        )
                    )
                    .zIndex(1000)
            }
        }
        .onAppear {
            let stateIdString = String(
                describing: ObjectIdentifier(unifiedState)
            )
            logger.info(
                "🎬 MAIN_VIEW: 🚀 MainView appeared - DEFINITIVE DUELING MACHINES FIX ACTIVE"
            )
            logger.info(
                "🎬 MAIN_VIEW: 🎯 SINGLE_STATE_OBJECT: AddMoveUnifiedState created once at MainView level"
            )
            logger.info("🎬 MAIN_VIEW: 🎯 PERSISTENT_STATE_ID: \(stateIdString)")
            logger.info(
                "🎬 MAIN_VIEW: 📊 CATEGORICAL_LIMIT_VIOLATION_FIXED: Only one state machine exists"
            )
            logger.info(
                "🎬 MAIN_VIEW: ✅ VIDEO_LOADING_FIX: Progress updates will survive view recreations"
            )
            logger.info(
                "🎬 MAIN_VIEW: ✅ STUCK_AT_0_PERCENT_BUG_FIXED: State lifecycle independent of view lifecycle"
            )
            logger.info(
                "🎬 MAIN_VIEW: 🔄 APP_WIDE_OVERLAY: LoadingOverlayView elevated to MainView level"
            )
        }
    }

    @MainActor
    private func handleLoadingStateChange(
        isLoading: Bool,
        unifiedState: AddMoveUnifiedState?
    ) {
        let sessionId = UUID().uuidString.prefix(8)
        let timestamp = Date()

        logger.info(
            "🎬 MAIN_VIEW: 🔄 APP_WIDE_OVERLAY [\(sessionId)] Loading state change at \(timestamp)"
        )
        logger.info(
            "🎬 MAIN_VIEW: 🔄 APP_WIDE_OVERLAY [\(sessionId)] ├─ isLoading: \(isLoading)"
        )
        logger.info(
            "🎬 MAIN_VIEW: 🔄 APP_WIDE_OVERLAY [\(sessionId)] ├─ hasUnifiedState: \(unifiedState != nil)"
        )
        logger.info(
            "🎬 MAIN_VIEW: 🔄 APP_WIDE_OVERLAY [\(sessionId)] ├─ currentTab: \(selectedTab.rawValue)"
        )
        logger.info(
            "🎬 MAIN_VIEW: 🔄 APP_WIDE_OVERLAY [\(sessionId)] └─ overlayVisible: \(showLoadingOverlay)"
        )

        let shouldShowOverlay = isLoading && unifiedState != nil

        if shouldShowOverlay != showLoadingOverlay
            || (shouldShowOverlay
                && loadingOverlayUnifiedState !== unifiedState)
        {
            logger.info(
                "🎬 MAIN_VIEW: 🔄 APP_WIDE_OVERLAY [\(sessionId)] State update required"
            )

            withAnimation(.easeInOut(duration: 0.3)) {
                showLoadingOverlay = shouldShowOverlay
                loadingOverlayUnifiedState = unifiedState
            }

            logger.info(
                "🎬 MAIN_VIEW: ✅ APP_WIDE_OVERLAY [\(sessionId)] Updated - showLoadingOverlay: \(showLoadingOverlay)"
            )
        } else {
            logger.info(
                "🎬 MAIN_VIEW: ⏭️ APP_WIDE_OVERLAY [\(sessionId)] No update needed - state unchanged"
            )
        }

        if !isLoading && !showLoadingOverlay {
            loadingOverlayUnifiedState = nil
            logger.info(
                "🎬 MAIN_VIEW: 🧹 APP_WIDE_OVERLAY [\(sessionId)] Cleared unifiedState reference for memory management"
            )
        }
    }
}
