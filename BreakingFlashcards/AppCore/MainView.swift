import SwiftUI

enum TabSelection: String {
    case arsenal = "ArsenalTab"
    case add = "AddTab"
    case combo = "ComboTab"
    case review = "ReviewTab"
}

struct MainView: View {
    @State private var selectedTab: TabSelection = .arsenal // Default to Arsenal tab

    var body: some View {
        TabView(selection: $selectedTab) { // Bind TabView to selectedTab
            BreakingArsenalView()
                .tabItem {
                    Label {
                        Text("Arsenal").font(.ibmPlexMono(size: 12))
                    } icon: {
                        Image(systemName: "book.closed")
                    }
                }
                .tag(TabSelection.arsenal) // Add tag
                .accessibilityLabel("Breaking Arsenal")
                .accessibilityHint("View your collection of breaking moves")

            AddMoveContainer(selectedTab: $selectedTab) // Pass binding to AddMoveContainer
                .tabItem {
                    Label {
                        Text("Add").font(.ibmPlexMono(size: 12))
                    } icon: {
                        Image(systemName: "plus.app")
                    }
                }
                .tag(TabSelection.add) // Add tag
                .accessibilityLabel("Add Move")
                .accessibilityHint("Add a new breaking move to your collection")

            CreateComboView()
                .tabItem {
                    Label {
                        Text("Combo").font(.ibmPlexMono(size: 12))
                    } icon: {
                        Image(systemName: "wand.and.stars")
                    }
                }
                .tag(TabSelection.combo) // Add tag
                .accessibilityLabel("Create Combo")
                .accessibilityHint("Create a new combination of breaking moves")

            ReviewView()
                .tabItem {
                    Label {
                        Text("Review").font(.ibmPlexMono(size: 12))
                    } icon: {
                        Image(systemName: "skateboard")
                    }
                }
                .tag(TabSelection.review) // Add tag
                .accessibilityLabel("Review")
                .accessibilityHint("Review and practice your breaking moves")
        }
        // dark color scheme
        .preferredColorScheme(.dark)
    }
}
