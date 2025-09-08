//
//  ComboListView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/26/25.
//

import SwiftUI
import CoreData

// MARK: - Animation Modifiers
// Using MotionCatalog for consistent animations

struct FadeInModifier: ViewModifier {
    @State private var opacity: Double = 0
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                opacity = 1
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
                    VStack(spacing: 20) {
                        Image(systemName: "square.stack.3d.up")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary.opacity(0.5))

                        Text("No combos created yet")
                            .font(.ibmPlexMono(size: 24, weight: .bold))
                            .foregroundColor(.textPrimary)

                        Text("Tap the 'Create' tab to start building your combo arsenal!")
                            .font(.ibmPlexMono(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 40)
                } else if searchResults.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))

                        Text("No combos found")
                            .font(.ibmPlexMono(size: 20, weight: .bold))
                            .foregroundColor(.textPrimary)

                        Text("Try a different search term")
                            .font(.ibmPlexMono(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(searchResults) { combo in
                        NavigationLink {
                            ComboDetailView(combo: combo)
                        } label: {
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
                            .onTapGesture {
                                MotionCatalog.Accessibility.selectionHaptic()
                            }
                        }
                        .buttonStyle(SpringButtonStyle())
                        .listRowBackground(Color.backgroundPrimary)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                MotionCatalog.Accessibility.actionHaptic()
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
            // .toolbar {
            //     ToolbarItem(placement: .navigationBarTrailing) {
            //         Menu {
            //             Text("Learning States")
            //             Divider()
            //             HStack {
            //                 StatePillView(learningState: "NEW")
            //                 Text("New - Just added")
            //             }
            //             HStack {
            //                 StatePillView(learningState: "LEARNING")
            //                 Text("Learning - In progress")
            //             }
            //             HStack {
            //                 StatePillView(learningState: "MASTERY")
            //                 Text("Mastered - Complete")
            //             }
            //         } label: {
            //             Image(systemName: "info.circle")
            //         }
            //     }
            // }
        }
    }
}

#Preview {
    ComboListView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
