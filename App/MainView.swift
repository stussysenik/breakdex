import CoreData
import SwiftUI

// MainView.swift - main tab navigation system

struct MainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Arsenal Tab
            BreakingArsenalView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "book.closed")
                    Text("Arsenal")
                }
                .tag(0)

            // Add Move Tab
            AddMoveView(selectedTab: $selectedTab)
            .tabItem {
                Image(systemName: "plus.app")
                Text("Add Move")
            }
            .tag(1)

            // Create Combo Tab
            CreateComboView()
                .tabItem {
                    Image(systemName: "wand.and.stars")
                    Text("Create Combo")
                }
                .tag(2)

            // Review Tab
            // ReviewView()
            //     .tabItem {
            //         Image(systemName: "skateboard")
            //         Text("Review")
            //     }
            //     .tag(3)
        }
        .accentColor(.accent)
        .withToastOverlay() // CW&T: Legibility — every action gets visible confirmation
        .onChange(of: selectedTab) { oldValue, newValue in
            Logger.main.info("📍 NAVIGATION: Tab changed from \(oldValue) to \(newValue)")
        }
    }
}

#Preview {
    // Create a preview that bypasses Core Data initialization issues
    struct PreviewWrapper: View {
        @State private var selectedTab = 0

        var body: some View {
            TabView(selection: $selectedTab) {
                // Arsenal Tab - using BreakingArsenalView (single source of truth)
                BreakingArsenalView(selectedTab: $selectedTab)
                    .tabItem {
                        Image(systemName: "book.closed")
                        Text("Arsenal")
                    }
                    .tag(0)

                // Add Move Tab - using AddMoveView
                AddMoveView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "plus.app")
                    Text("Add Move")
                }
                .tag(1)

                // Create Combo Tab - using dummy text
                NavigationStack {
                    VStack(spacing: 30) {
                        Spacer()
                        Text("Create Combo")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("🎬 Combo creation will be here")
                            .font(.title2)
                        Spacer()
                    }
                }
                .tabItem {
                    Image(systemName: "wand.and.stars")
                    Text("Create Combo")
                }
                .tag(2)

                // Review Tab - using dummy text
                NavigationStack {
                    VStack(spacing: 30) {
                        Spacer()
                        Text("Review")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("📚 Review system will be here")
                            .font(.title2)
                        Spacer()
                    }
                }
                .tabItem {
                    Image(systemName: "skateboard")
                    Text("Review")
                }
                .tag(3)
            }
            .accentColor(.accent)
        }
    }

    return PreviewWrapper()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
