import SwiftUI

enum TabSelection: String, Hashable {
    case arsenal = "ArsenalTab"
    case add = "AddTab"
    case combo = "ComboTab"
    case review = "ReviewTab"
}

struct MainView: View {
    @State private var selectedTab: TabSelection = .add // Default to Add tab

    var body: some View {
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

            // Add Tab
            AddMoveContainer(selectedTab: $selectedTab)
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
}
