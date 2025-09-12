import SwiftUI
import CoreData

// MARK: - Button Styles
// Using MotionCatalog for consistent animations

struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct MoveListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let onNavigateToAdd: () -> Void

    @FetchRequest(     // this fetches all 'Move' objects from Core Data.
        sortDescriptors: [NSSortDescriptor(keyPath: \Move.createdAt, ascending: false)],
        animation: .default)
    private var moves: FetchedResults<Move>

    @State private var searchText = ""
    
    
    var searchResults: [Move] { // filter results based on search
        if searchText.isEmpty {
            return Array(moves)
        } else {
            return moves.filter { $0.name?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
    }
    
    private func deleteMove(_ move: Move) { // delete move from Core Data
        viewContext.delete(move)
        do {
            try viewContext.save()
        } catch {
            print("Error deleting move: \(error)")
        }
    }

    private func addTestMoves() {
        let testMoves = [
            ("Windmill", "NEW"),
            ("Flare", "LEARNING"),
            ("Top Rock", "MASTERY"),
            ("Freeze", "NEW")
        ]

        for (name, state) in testMoves {
            let newMove = Move(context: viewContext)
            // Note: We don't set the managedObjectID as it's read-only and managed by Core Data
            newMove.name = name
            newMove.createdAt = Date().addingTimeInterval(Double.random(in: -86400...0)) // Random time in last 24 hours
            newMove.learningState = state
            newMove.photosIdentifier = "test-\(UUID().uuidString)"
            newMove.trimStartTime = 0.0
            newMove.trimEndTime = 5.0
        }

        do {
            try viewContext.save()
            print("✅ Added \(testMoves.count) test moves")
        } catch {
            print("❌ Error adding test moves: \(error)")
        }
    }
    
    var body: some View {
        NavigationStack {
            // Debugging: Print the number of moves
            // print("Number of moves: \(moves.count)")
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                if moves.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "figure.martial.arts")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary.opacity(0.5))

                        Text("No moves added yet")
                            .font(.ibmPlexMono(size: 24, weight: .bold))
                            .foregroundColor(.textPrimary)

                        Text("Tap below to start building your breaking arsenal!")
                            .font(.ibmPlexMono(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Add Move") {
                            onNavigateToAdd()
                        }
                        .buttonStyle(.appPrimary(size: .medium))
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 40)
                } else if searchResults.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))

                        Text("No moves found")
                            .font(.ibmPlexMono(size: 20, weight: .bold))
                            .foregroundColor(.textPrimary)

                        Text("Try a different search term")
                            .font(.ibmPlexMono(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(searchResults) {
                        move in
                        NavigationLink {
                            MoveDetailView(move: move)
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(move.name ?? "Untitled Move")
                                        .font(.ibmPlexMono(size: 16, weight: .bold))
                                        .foregroundColor(.textPrimary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)

                                    Text("Added: \(move.createdAt ?? Date(), format: .dateTime.month().day().year().hour().minute())")
                                        .font(.ibmPlexMono(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                StatePillView(learningState: move.learningState)
                                    .fixedSize()
                                    .frame(maxHeight: .infinity, alignment: .center)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(SpringButtonStyle())
                        .listRowBackground(Color.backgroundPrimary)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                MotionCatalog.Accessibility.actionHaptic()
                                deleteMove(move)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Search Moves...")
                }
            }
            .navigationTitle("Moves")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MoveListView(onNavigateToAdd: {})
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
