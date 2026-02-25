import SwiftUI
import CoreData

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

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Move.createdAt, ascending: false)],
        animation: .default)
    private var moves: FetchedResults<Move>

    @State private var searchText = ""

    var searchResults: [Move] {
        if searchText.isEmpty {
            return Array(moves)
        } else {
            return moves.filter { $0.name?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
    }

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
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                if moves.isEmpty {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "figure.dance")
                            .font(.system(size: 48))
                            .foregroundColor(.textSecondary)
                        Text("No Moves Yet")
                            .font(.titleSmall)
                            .foregroundColor(.textPrimary)
                        Text("Tap the Add tab to start building your arsenal")
                            .font(.bodySmall)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, Spacing.lg)
                } else {
                    List(searchResults) { move in
                        NavigationLink(destination: MoveDetailView(move: move)) {
                            HStack(alignment: .top, spacing: Spacing.md) {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(move.name ?? "Untitled Move")
                                        .font(.bodyMedium)
                                        .foregroundColor(.textPrimary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)

                                    Text(move.createdAt ?? Date(), format: .dateTime.month().day().year())
                                        .font(.caption)
                                        .foregroundColor(.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                StatePillView(learningState: move.learningState)
                                    .fixedSize()
                            }
                            .padding(.vertical, Spacing.sm)
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
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Search Moves...")
                }
            }
            .navigationTitle("MOVES")
            .navigationBarTitleDisplayMode(.inline)
        }
        .appMotion(moves.count)
    }
}

#Preview {
    MoveListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
