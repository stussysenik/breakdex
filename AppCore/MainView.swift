import SwiftUI
import Foundation
import CoreData

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
                // 🎯 CRITICAL FIX: Handle successful save and navigate to detail view
                self.savedMove = savedMove
                self.navigateToMoveDetail = true
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
        }
        .navigationDestination(isPresented: $navigateToMoveDetail) {
            if let move = savedMove {
                MoveDetailView(move: move)
            }
        }
    }
}