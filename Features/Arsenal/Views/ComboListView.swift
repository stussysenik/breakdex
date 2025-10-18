//
//  ComboListView.swift
//  BreakingFlashcards
//
//  Created by Claude Code on 10/10/25.
//  Refactored to use ArsenalViewModel and shared components
//

import SwiftUI
import CoreData
import OSLog
import UIKit

// MARK: - Combo List View
/// Clean view for displaying and managing combos list using ArsenalViewModel
/// Follows single responsibility principle - only handles UI presentation
struct ComboListView: View {

    // MARK: - Properties
    @Environment(\.managedObjectContext) private var viewContext
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "📋 COMBO_LIST_VIEW")

    // MARK: - ViewModel
    @StateObject private var viewModel: ArsenalViewModel

    // MARK: - Initialization
    init() {
        self._viewModel = StateObject(wrappedValue: ArsenalViewModel(viewContext: PersistenceController.shared.container.viewContext))
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                // MARK: - Content
                VStack {
                    if viewModel.isLoadingCombos {
                        loadingView
                    } else if viewModel.filteredCombos.isEmpty {
                        emptyStateView
                    } else {
                        combosList
                    }
                }
            }
            .navigationTitle("Combos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .searchable(text: $viewModel.combosSearchText, prompt: "Search Combos...")
            .onAppear {
                logger.info("📋 COMBO_LIST_VIEW: 🚀 View appeared with clean architecture")
                viewModel.refreshCombos()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    // MARK: - Loading View
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 20) {
            SharedLoadingView(message: "Loading combos...")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State View
    @ViewBuilder
    private var emptyStateView: some View {
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
    }

    // MARK: - No Search Results View
    @ViewBuilder
    private var noSearchResultsView: some View {
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

            Button("Clear Search") {
                viewModel.clearCombosSearch()
                logger.info("📋 COMBO_LIST_VIEW: 🧹 Cleared search")
            }
            .font(.ibmPlexMono(size: 14, weight: .medium))
            .foregroundColor(.blue)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.2))
            .clipShape(Capsule())
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Combos List
    @ViewBuilder
    private var combosList: some View {
        Group {
            if viewModel.filteredCombos.isEmpty && !viewModel.combosSearchText.isEmpty {
                noSearchResultsView
            } else {
                List(viewModel.filteredCombos) { combo in
                    ComboRowView(
                        combo: combo,
                        moveCount: viewModel.getMoveCount(for: combo),
                        learningState: viewModel.getComboLearningState(for: combo),
                        onTap: {
                            logger.info("📋 COMBO_LIST_VIEW: 👆 Tapped combo: \(combo.name ?? "Untitled Combo")")
                        },
                        onDelete: {
                            Task {
                                await viewModel.deleteCombo(combo)
                            }
                        }
                    )
                    .listRowBackground(Color.backgroundPrimary)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Combo Row View
/// Reusable component for displaying a single combo in the list
private struct ComboRowView: View {

    // MARK: - Properties
    let combo: Combo
    let moveCount: String
    let learningState: String
    let onTap: () -> Void
    let onDelete: () -> Void
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "📋 COMBO_ROW_VIEW")

    // MARK: - Body
    var body: some View {
        NavigationLink {
            // Placeholder for combo detail view
            VStack {
                Text("Combo Details")
                    .font(.title)
                Text(combo.name ?? "Untitled Combo")
                    .font(.headline)
                Text("Move count: \(moveCount)")
                    .font(.subheadline)
                Text("State: \(learningState)")
                    .font(.subheadline)
            }
            .padding()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(combo.name ?? "Untitled Combo")
                        .font(.ibmPlexMono(size: 18, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)

                    Text(moveCount)
                        .font(.ibmPlexMono(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                StatePillView(learningState: learningState)
                    .fixedSize()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(SpringButtonStyle())
        .onTapGesture {
            onTap()
            MotionCatalog.Accessibility.selectionHaptic()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", role: .destructive) {
                onDelete()
                MotionCatalog.Accessibility.actionHaptic()
                logger.info("📋 COMBO_ROW_VIEW: 🗑️ Deleted combo: \(combo.name ?? "Untitled Combo")")
            }
            .tint(.red)
        }
    }
}

// MARK: - Spring Button Style
/// Consistent button style for combo interactions
private struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview("Combo List - Empty") {
    let context = PersistenceController.preview.container.viewContext
    // Clear any existing combos for empty state preview
    let request = NSBatchDeleteRequest(fetchRequest: Combo.fetchRequest() as! NSFetchRequest<NSFetchRequestResult>)
    _ = try? context.execute(request)

    return ComboListView()
        .environment(\.managedObjectContext, context)
}

// MARK: - Test Data Creation
private func createTestCombos(in context: NSManagedObjectContext) {
    // Add test data for preview
    let testCombos = ["Basic Six Step Combo", "Powermove Sequence", "Freeze Combination"]
    for (index, name) in testCombos.enumerated() {
        let combo = Combo(context: context)
        combo.name = name

        // Create some combo moves for demonstration
        let moveNames = ["Top Rock", "Six Step", "Freeze"]
        for (moveIndex, moveName) in moveNames.enumerated() {
            let move = Move(context: context)
            move.name = moveName
            move.learningState = ["NEW", "LEARNING", "MASTERY"][moveIndex]
            move.photosIdentifier = "test-\(UUID().uuidString)"

            let comboMove = ComboMove(context: context)
            comboMove.combo = combo
            comboMove.move = move
            comboMove.sequenceIndex = Int64(moveIndex)
        }
    }
    _ = try? context.save()
}

#Preview("Combo List - With Data") {
    let context = PersistenceController.preview.container.viewContext
    createTestCombos(in: context)

    return ComboListView()
        .environment(\.managedObjectContext, context)
}