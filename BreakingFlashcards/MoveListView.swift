// MoveListView.swift — Main move browsing screen for the Breakdex app
//
// Searchable, scrollable list of all recorded breakdancing moves.
// Each row shows the move name, creation date, and learning state as plain text.
// Tapping navigates to MoveDetailView. Swipe-left to delete.
// 3 visual anchors: nav title, search bar, text list rows.

import SwiftUI
import SwiftData

// MARK: - SpringButtonStyle

/// Reusable spring-animated press feedback style.
/// Applied to action buttons (not list rows — high-frequency taps become friction).
struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: configuration.isPressed)
    }
}

// MARK: - MoveListView

struct MoveListView: View {

    // MARK: - Environment & Data

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Move.createdAt, order: .reverse)
    private var moves: [Move]

    // MARK: - Local State

    @State private var searchText = ""

    // MARK: - Computed Properties

    var searchResults: [Move] {
        if searchText.isEmpty {
            return moves
        } else {
            return moves.filter { $0.name?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
    }

    // MARK: - Actions

    private func deleteMove(_ move: Move) {
        if let videoURL = move.resolveVideoURL() {
            do {
                try FileManager.default.removeItem(at: videoURL)
            } catch {
                print("[MoveList] Failed to remove video file at \(videoURL.path): \(error.localizedDescription)")
            }
        }

        modelContext.delete(move)
        do {
            try modelContext.save()
        } catch {
            print("Error deleting move: \(error)")
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                if moves.isEmpty {
                    ContentUnavailableView(
                        "No Moves Yet",
                        systemImage: "figure.dance",
                        description: Text("Tap the Add tab to record your first move.")
                    )
                } else {
                    List(searchResults) { move in
                        NavigationLink(destination: MoveDetailView(move: move)) {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    // Level 1: Move name — darkest, most prominent
                                    Text(move.name ?? "Untitled Move")
                                        .font(.ibmPlexMono(size: 16, weight: .bold))
                                        .foregroundColor(.textPrimary)
                                        .lineLimit(2)

                                    HStack(spacing: Spacing.sm) {
                                        // Level 2: State — colored for scanning
                                        let resolved = LearningState.resolve(from: move.learningState)
                                        Text(resolved.actionLabel)
                                            .font(.ibmPlexMono(size: 12, weight: .medium))
                                            .foregroundColor(resolved.color)

                                        // Level 3: Date — lightest
                                        Text(move.createdAt ?? Date(), format: .dateTime.month().day().year())
                                            .font(.ibmPlexMono(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.vertical, Spacing.xs)
                        }
                        .buttonStyle(.plain)
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
            .navigationTitle("Moves")
            .navigationBarTitleDisplayMode(.inline)
        }
        .appMotion(moves.count)
    }
}

// MARK: - Preview

#Preview("MoveList - Light") {
    MoveListView()
        .modelContainer(.preview)
}

#Preview("MoveList - Dark") {
    MoveListView()
        .modelContainer(.preview)
        .preferredColorScheme(.dark)
}
