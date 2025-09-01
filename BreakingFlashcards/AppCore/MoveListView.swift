import SwiftUI
import CoreData
import BreakingFlashcards

// Motion-library inspired button style with spring animations
struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: configuration.isPressed)
    }
}

struct MoveListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // 1. FETCH THE DATA
    // This fetches all 'Move' objects from Core Data.
    // They are sorted by 'createdAt' in descending order (newest first).
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Move.createdAt, ascending: false)],
        animation: .default)
    private var moves: FetchedResults<Move>

    // New state for the search text.
    @State private var searchText = ""

    // Filtered results based on search text.
    var searchResults: [Move] {
        if searchText.isEmpty {
            return Array(moves)
        } else {
            return moves.filter { $0.name?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
    }

    // Function to delete a move from Core Data
    private func deleteMove(_ move: Move) {
        viewContext.delete(move)
        do {
            try viewContext.save()
        } catch {
            print("Error deleting move: \(error)")
        }
    }

    var body: some View {
        NavigationStack {
            // Use a ZStack to set a background color.
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                // 2. HANDLE EMPTY STATE
                // If there are no moves, show a message.
                if moves.isEmpty {
                    Text("No moves added yet\nTap the 'Add' tab to start!")
                        .font(.ibmPlexMono(size: 18, weight: .thin))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    // 3. DISPLAY THE LIST
                    // If there are moves, display them in a List.
                    List(searchResults) { move in
                        NavigationLink(destination: MoveDetailView(move: move)) {
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
                            .scaleEffect(1.0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0), value: UUID())
                        }
                        .buttonStyle(SpringButtonStyle())
                        .listRowBackground(Color.backgroundPrimary)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteMove(move)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .listStyle(.plain) // Use plain style for a cleaner look.
                    // Add the searchable modifier here.
                    .searchable(text: $searchText, prompt: "Search Moves...")
                }
            }
            .navigationTitle("Move Arsenal")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MoveListView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
