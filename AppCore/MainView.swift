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

    var body: some View {
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

            // Add Tab - Inline AddMoveContainer functionality
            AddMoveView(selectedTab: $selectedTab, onSaveSuccess: { savedMove in
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
            })
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
    }
}