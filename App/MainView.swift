import CoreData
import SwiftUI

// MARK: - Unified Navigation
enum AppDestination: Hashable {
    case arsenal
    case addMove
    case createCombo
    case review
}

@Observable final class AppRouter {
    var path = NavigationPath()
    func push(_ destination: AppDestination) { path.append(destination) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path = NavigationPath() }
}

// MARK: - Dummy Destination Views
struct ArsenalDummyView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Arsenal")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Your movement collection")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .navigationTitle("Arsenal")
    }
}

struct AddMoveDummyView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Move")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Import and trim new movements")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .navigationTitle("Add Move")
    }
}

struct CreateComboDummyView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Combo")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Combine movements into sequences")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .navigationTitle("Create Combo")
    }
}

struct ReviewDummyView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Review")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Practice with spaced repetition")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .navigationTitle("Review")
    }
}

struct MainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var router = AppRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            GeometryReader { geometry in
                ZStack {
                    // Header (positioned at top, doesn't affect centering)
                    VStack(spacing: 0) {
                        Text("breakdex")
                            .font(.largeTitle)
                            .fontWeight(.semibold)
//                        Divider()
                    }
                    .frame(maxHeight: .infinity, alignment: .top)

                    // Navigation VStack centered to absolute screen center
                    VStack(spacing: 15) {
                        HStack {
                            Image(systemName: "book.closed")
                                .font(.system(size: 23)) // 15% larger
                            Text("Arsenal")
                                .font(.system(size: 20).weight(.regular))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            router.push(.arsenal)
                        }
                        .padding(4)

                        HStack {
                            Image(systemName: "plus.app")
                                .font(.system(size: 23))
                            Text("Add Move")
                                .font(.system(size: 20).weight(.regular))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            router.push(.addMove)
                        }
                        .padding(4)

                        HStack {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 23))
                            Text("Create Combo")
                                .font(.system(size: 20).weight(.regular))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            router.push(.createCombo)
                        }
                        .padding(4)

                        HStack {
                            Image(systemName: "skateboard")
                                .font(.system(size: 23))
                            Text("Review")
                                .font(.system(size: 20).weight(.regular))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            router.push(.review)
                        }
                        .padding(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            }
            .ignoresSafeArea(.keyboard)
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .arsenal:
                    ArsenalDummyView()
                case .addMove:
                    AddMoveDummyView()
                case .createCombo:
                    CreateComboDummyView()
                case .review:
                    ReviewDummyView()
                }
            }
        }
        .padding(20)
        .environment(router)
    }
}

#Preview {
    MainView()
        .environment(
            \.managedObjectContext,
            PersistenceController.preview.container.viewContext
        )
}
