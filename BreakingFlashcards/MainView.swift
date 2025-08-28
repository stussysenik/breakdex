import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {
            AddMoveView()
                .tabItem {
                    Label("Add Move", systemImage: "plus.circle")
                }

            BreakingArsenalView()
                .tabItem {
                    Label("Arsenal", systemImage: "figure.martial.arts")
                }

            CreateComboView()
                .tabItem {
                    Label("Create Combo", systemImage: "wand.and.stars")
                }

            ReviewView()
                .tabItem {
                    Label("Review", systemImage: "eye.fill")
                }
        }
        // dark color scheme
        .preferredColorScheme(.dark)
    }
}
