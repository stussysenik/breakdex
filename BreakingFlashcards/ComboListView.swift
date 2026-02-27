// ComboListView.swift — Main combo browsing screen for the Breakdex app
//
// Searchable list of all breakdancing combos. Each row shows the combo name,
// move count, and composite learning state as plain text.
// Tapping navigates to ComboDetailView. Swipe-left to delete.
// 3 visual anchors: nav title, search bar, text list rows.

import SwiftUI
import SwiftData

struct ComboListView: View {

    // MARK: - Environment & Data

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Combo.name)
    private var combos: [Combo]

    @Query(sort: \ComboMove.sequenceIndex)
    private var comboMoves: [ComboMove]

    // MARK: - Local State

    @State private var searchText = ""

    // MARK: - Computed Properties

    var searchResults: [Combo] {
        if searchText.isEmpty {
            return combos
        } else {
            return combos.filter { $0.name?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
    }

    private var statsByComboID: [PersistentIdentifier: ComboStats] {
        ComboStatsBuilder.build(from: comboMoves)
    }

    private func stats(for combo: Combo) -> ComboStats {
        statsByComboID[combo.persistentModelID] ?? ComboStats()
    }

    private func getMoveCount(for combo: Combo) -> String {
        let count = stats(for: combo).count
        return "\(count) moves"
    }

    private func getComboLearningState(for combo: Combo) -> LearningState {
        stats(for: combo).learningState
    }

    // MARK: - Actions

    private func deleteCombo(_ combo: Combo) {
        modelContext.delete(combo)
        do {
            try modelContext.save()
        } catch {
            print("Error deleting combo: \(error)")
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                if combos.isEmpty {
                    ContentUnavailableView("No combos created yet", systemImage: "square.stack.3d.up.slash")
                        .frame(maxHeight: .infinity)
                } else {
                    List(searchResults) { combo in
                        NavigationLink(destination: ComboDetailView(combo: combo)) {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    // Level 1: Combo name — darkest
                                    Text(combo.name ?? "Untitled Combo")
                                        .font(.ibmPlexMono(size: 16, weight: .bold))
                                        .foregroundColor(.textPrimary)
                                        .lineLimit(2)

                                    HStack(spacing: Spacing.sm) {
                                        // Level 2: State — colored
                                        let state = getComboLearningState(for: combo)
                                        Text(state.actionLabel)
                                            .font(.ibmPlexMono(size: 12, weight: .medium))
                                            .foregroundColor(state.color)

                                        // Level 3: Move count — lightest
                                        Text(getMoveCount(for: combo))
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
                                deleteCombo(combo)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Search Combos...")
                }
            }
            .navigationTitle("Combos")
            .navigationBarTitleDisplayMode(.inline)
        }
        .appMotion(combos.count)
    }
}

// MARK: - Preview

#Preview("ComboList - Light") {
    ComboListView()
        .modelContainer(.preview)
}

#Preview("ComboList - Dark") {
    ComboListView()
        .modelContainer(.preview)
        .preferredColorScheme(.dark)
}
