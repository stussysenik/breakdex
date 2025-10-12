import CoreData
import SwiftUI

// MainView.swift - main tab navigation system

struct MainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0
    @State private var unifiedState = AddMoveUnifiedState()

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
            SelectClip(
                selectedTab: Binding(
                    get: { .add },
                    set: { _ in }
                ),
                unifiedState: unifiedState
            )
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
            ReviewView()
                .tabItem {
                    Image(systemName: "skateboard")
                    Text("Review")
                }
                .tag(3)
        }
        .accentColor(.accent)
    }
}

#Preview {
    // Create a preview that bypasses Core Data initialization issues
    struct PreviewWrapper: View {
        @State private var selectedTab = 0
        @State private var unifiedState = AddMoveUnifiedState()

        var body: some View {
            TabView(selection: $selectedTab) {
                // Arsenal Tab - using dummy text
                NavigationStack {
                    VStack(spacing: 40) {
                        Spacer()
                        Text("MOVE")
                            .font(.ibmPlexMono(size: 42, weight: .bold))
                            .foregroundColor(.textPrimary)

                        Text("COMBO")
                            .font(.ibmPlexMono(size: 42, weight: .bold))
                            .foregroundColor(.textPrimary)

                        Spacer()
                    }
                }
                .tabItem {
                    Image(systemName: "book.closed")
                    Text("Arsenal")
                }
                .tag(0)

                // Add Move Tab - using SelectClip
                SelectClip(
                    selectedTab: Binding(
                        get: { .add },
                        set: { _ in }
                    ),
                    unifiedState: unifiedState
                )
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
