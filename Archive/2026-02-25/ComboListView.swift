//
//  ComboListView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/26/25.
//

import SwiftUI
import CoreData

// Motion-library inspired animations for list items
struct FadeInModifier: ViewModifier {
    @State private var opacity: Double = 0
    let delay: Double
    
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0).delay(delay)) {
                    opacity = 1
                }
            }
    }
}


struct ComboListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Combo.name, ascending: true)],
        animation: .default)
    private var combos: FetchedResults<Combo>

    @State private var searchText = ""

    var searchResults: [Combo] {
        if searchText.isEmpty {
            return Array(combos)
        } else {
            return combos.filter { $0.name?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
    }

    private func getMoveCount(for combo: Combo) -> String {
        let fetchRequest = NSFetchRequest<ComboMove>(entityName: "ComboMove")
        fetchRequest.predicate = NSPredicate(format: "combo == %@", combo)

        do {
            let count = try viewContext.count(for: fetchRequest)
            return "\(count) moves"
        } catch {
            return "0 moves"
        }
    }

    private func getComboLearningState(for combo: Combo) -> String {
        let fetchRequest = NSFetchRequest<ComboMove>(entityName: "ComboMove")
        fetchRequest.predicate = NSPredicate(format: "combo == %@", combo)

        do {
            let comboMoves = try viewContext.fetch(fetchRequest)
            let moveStates = comboMoves.compactMap { $0.move?.learningState }

            if moveStates.isEmpty {
                return "NEW"
            }

            if moveStates.allSatisfy({ $0 == "MASTERY" }) {
                return "MASTERY"
            } else if moveStates.contains(where: { $0 == "NEW" }) {
                return "NEW"
            } else if moveStates.contains(where: { $0 == "LEARNING" }) {
                return "LEARNING"
            } else {
                return "NEW"
            }
        } catch {
            return "NEW"
        }
    }

    private func deleteCombo(_ combo: Combo) {
        viewContext.delete(combo)
        do {
            try viewContext.save()
        } catch {
            print("Error deleting combo: \(error)")
        }
    }

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
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(combo.name ?? "Untitled Combo")
                                        .font(.ibmPlexMono(size: 18, weight: .bold))
                                        .foregroundColor(.textPrimary)

                                    Text(getMoveCount(for: combo))
                                        .font(.ibmPlexMono(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                StatePillView(learningState: getComboLearningState(for: combo))
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(SpringButtonStyle())
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
            .navigationTitle("Combo Arsenal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Text("Learning States")
                        Divider()
                        HStack {
                            StatePillView(learningState: "NEW")
                            Text("New - Just added")
                        }
                        HStack {
                            StatePillView(learningState: "LEARNING")
                            Text("Learning - In progress")
                        }
                        HStack {
                            StatePillView(learningState: "MASTERY")
                            Text("Mastered - Complete")
                        }
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
        }
    }
}

#Preview {
    ComboListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
