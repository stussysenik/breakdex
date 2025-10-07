import SwiftUI
import Foundation
import CoreData
import OSLog

// MARK: - Logger Instance
private let logger = Logger(subsystem: "com.breakingflashcards", category: "MainView")

// MARK: - Tab Selection Enum
enum TabSelection: String, Hashable {
    case arsenal = "ArsenalTab"
    case add = "AddTab"
    case combo = "ComboTab"
    case review = "ReviewTab"
}

struct MainView: View {
    @State private var selectedTab: TabSelection = .add // Default to Add tab

    // 🎯 CRITICAL FIX: Navigation state for programmatic navigation to MoveDetailView
    @State private var navigateToMoveDetail: Bool = false
    @State private var savedMove: Move?

    // 🎯 CRITICAL FIX: App-wide loading overlay state management
    // ROOT CAUSE: LoadingOverlayView was tied to AddMoveContainer lifecycle, causing disappearance on tab switches
    // SOLUTION: Elevate loading overlay to MainView level with app-wide state management
    @State private var showLoadingOverlay: Bool = false
    @State private var loadingOverlayUnifiedState: AddMoveUnifiedState?

    // MARK: - Critical State Lifecycle Fix Implementation
    //
    // ROOT CAUSE: AddMoveUnifiedState was created inside AddMoveContainer with @StateObject.
    // When SwiftUI recreates the view during video loading, the state object is destroyed,
    // but background video loading continues and tries to update the destroyed object,
    // causing progress updates to fail and video loading to appear "stuck at 0%".
    //
    // THE FIX: Move AddMoveUnifiedState creation to MainView (persistent parent) using @StateObject.
    // AddMoveContainer now receives the state as @ObservedObject (no ownership).
    // This ensures state persistence independent of view lifecycle.
    //
    // ARCHITECTURE:
    // MainView (persistent) → AddMoveStateOwner (owns @StateObject) → AddMoveContainerWithPersistentState (uses @ObservedObject)
    //
    // BENEFITS:
    // ✅ State persists across SwiftUI view recreations
    // ✅ Video loading progress updates work correctly
    // ✅ No more "stuck at 0%" issues
    // ✅ Maintains existing navigation and error handling

    var body: some View {
        ZStack {
            // Main app content
            NavigationStack {
                EnhancedTabView(selection: $selectedTab) {
                // Arsenal Tab
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
                    .accessibilityHint("View your collection of breaking moves, or combos")

                // Add Tab - 🎯 CRITICAL FIX: Use AddMoveStateOwner for persistent state management
                // This fixes the "stuck at 0%" video loading issue by elevating AddMoveUnifiedState
                // ownership from AddMoveContainer to MainView level, making state independent of view lifecycle
                AddMoveStateOwner(
                    selectedTab: $selectedTab,
                    onSaveSuccess: { savedMove in
                        // 🎯 CRITICAL FIX: Enhanced navigation handler with comprehensive logging
                        logger.info("🎬 MAIN_VIEW: Save success callback triggered for move: \(savedMove.name ?? "unnamed")")

                        // Store the saved move and trigger navigation
                        self.savedMove = savedMove
                        self.navigateToMoveDetail = true

                        // 🎯 STRATEGIC FIX: Switch to Arsenal tab before navigation for proper NavigationStack context
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            logger.info("🎬 MAIN_VIEW: Switching to Arsenal tab for navigation context")
                            selectedTab = .arsenal

                            // Navigate after tab switch is complete
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                logger.info("🎬 MAIN_VIEW: Executing navigation to MoveDetailView for move: \(savedMove.name ?? "unnamed")")
                                self.navigateToMoveDetail = true
                            }
                        }
                    },
                    onLoadingStateChanged: { isLoading, unifiedState in
                        // 🎯 CRITICAL FIX: App-wide loading overlay management
                        logger.info("🎬 MAIN_VIEW: 🔄 Loading state changed - isLoading: \(isLoading)")
                        handleLoadingStateChange(isLoading: isLoading, unifiedState: unifiedState)
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
                    .accessibilityHint("Add a new breaking move to your collection")

                // Create Combo Tab
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
                    .accessibilityHint("Create a new combination of breaking moves")

                // Review Tab
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
                    .accessibilityHint("Review and practice your breaking moves")
                }
                // 🎯 CRITICAL FIX: Enhanced navigationDestination with proper error handling
                .navigationDestination(isPresented: $navigateToMoveDetail) {
                    if let move = savedMove {
                        MoveDetailView(move: move)
                            .onAppear {
                                logger.info("🎬 MAIN_VIEW: MoveDetailView appeared successfully for move: \(move.name ?? "unnamed")")
                            }
                            .onDisappear {
                                logger.info("🎬 MAIN_VIEW: MoveDetailView disappeared - resetting navigation state")
                                self.navigateToMoveDetail = false
                                self.savedMove = nil
                            }
                    } else {
                        // 🎯 ERROR HANDLING: Fallback view for missing move
                        Text("Error: Move not found")
                            .foregroundColor(.red)
                            .onAppear {
                                logger.error("🎬 MAIN_VIEW: ❌ Navigation triggered but savedMove is nil")
                            }
                    }
                }
            }

            // 🎯 CRITICAL FIX: App-wide loading overlay
            // ELEVATED: LoadingOverlayView moved from FeatureRichTrimmerView to MainView level
            // This ensures the loading overlay persists across tab switches and view recreations
            if showLoadingOverlay, let unifiedState = loadingOverlayUnifiedState {
                LoadingOverlayView(unifiedState: unifiedState)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 1.05))
                    ))
                    .zIndex(1000) // Ensure overlay appears above all content
            }
        }
        .onAppear {
            logger.info("🎬 MAIN_VIEW: 🚀 MainView appeared - CRITICAL STATE LIFECYCLE FIX ACTIVE")
            logger.info("🎬 MAIN_VIEW: 🎯 STATE_OWNERSHIP: AddMoveUnifiedState now owned at MainView level")
            logger.info("🎬 MAIN_VIEW: 📊 VIDEO_LOADING_FIX: Progress updates will survive view recreations")
            logger.info("🎬 MAIN_VIEW: ✅ STUCK_AT_0_PERCENT_BUG_FIXED: State lifecycle independent of view lifecycle")
            logger.info("🎬 MAIN_VIEW: 🔄 APP_WIDE_OVERLAY: LoadingOverlayView elevated to MainView level")
        }
    }

    // MARK: - 🎯 CRITICAL FIX: App-wide Loading Overlay Management

    /// Handles loading state changes from AddMoveStateOwner to show/hide app-wide overlay
    ///
    /// This method ensures the loading overlay persists across tab switches by managing
    /// overlay state at the MainView level, independent of individual view lifecycles.
    ///
    /// - Parameters:
    ///   - isLoading: Whether the app should show loading state
    ///   - unifiedState: The AddMoveUnifiedState instance for progress tracking
    @MainActor
    private func handleLoadingStateChange(isLoading: Bool, unifiedState: AddMoveUnifiedState?) {
        let sessionId = UUID().uuidString.prefix(8)
        let timestamp = Date()

        logger.info("🎬 MAIN_VIEW: 🔄 APP_WIDE_OVERLAY [\(sessionId)] Loading state change at \(timestamp)")
        logger.info("🎬 MAIN_VIEW: 🔄 APP_WIDE_OVERLAY [\(sessionId)] ├─ isLoading: \(isLoading)")
        logger.info("🎬 MAIN_VIEW: 🔄 APP_WIDE_OVERLAY [\(sessionId)] ├─ hasUnifiedState: \(unifiedState != nil)")
        logger.info("🎬 MAIN_VIEW: 🔄 APP_WIDE_OVERLAY [\(sessionId)] ├─ currentTab: \(selectedTab.rawValue)")
        logger.info("🎬 MAIN_VIEW: 🔄 APP_WIDE_OVERLAY [\(sessionId)] └─ overlayVisible: \(showLoadingOverlay)")

        // Performance optimization: Only update if state actually changes
        let shouldShowOverlay = isLoading && unifiedState != nil

        if shouldShowOverlay != showLoadingOverlay || (shouldShowOverlay && loadingOverlayUnifiedState !== unifiedState) {
            logger.info("🎬 MAIN_VIEW: 🔄 APP_WIDE_OVERLAY [\(sessionId)] State update required")

            // Use withAnimation for smooth transitions
            withAnimation(.easeInOut(duration: 0.3)) {
                showLoadingOverlay = shouldShowOverlay
                loadingOverlayUnifiedState = unifiedState
            }

            logger.info("🎬 MAIN_VIEW: ✅ APP_WIDE_OVERLAY [\(sessionId)] Updated - showLoadingOverlay: \(showLoadingOverlay)")
        } else {
            logger.info("🎬 MAIN_VIEW: ⏭️ APP_WIDE_OVERLAY [\(sessionId)] No update needed - state unchanged")
        }

        // Memory management: Clear unifiedState reference when overlay is hidden
        if !isLoading && !showLoadingOverlay {
            loadingOverlayUnifiedState = nil
            logger.info("🎬 MAIN_VIEW: 🧹 APP_WIDE_OVERLAY [\(sessionId)] Cleared unifiedState reference for memory management")
        }
    }
}