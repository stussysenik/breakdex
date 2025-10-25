//
//  ComboDetailView.swift
//  BreakingFlashcards
//
//  Created by Claude Code on 10/25/25.
//  Detail view for displaying combo information and interactive timeline
//

import SwiftUI
import CoreData
import OSLog
import UIKit

// MARK: - Combo Detail View
/// Detail view for displaying combo information with interactive timeline
/// Follows single responsibility principle - only handles UI presentation
struct ComboDetailView: View {

    // MARK: - Properties
    let combo: Combo
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🎯 COMBO_DETAIL_VIEW")

    // MARK: - State
    @State private var selectedMoveIndex: Int?
    @State private var comboMoves: [ComboMove] = []
    @State private var isLoading = true

    // MARK: - Computed Properties
    private var moves: [Move] {
        comboMoves.sorted { $0.sequenceIndex < $1.sequenceIndex }.compactMap { $0.move }
    }

    private var moveCount: String {
        "\(moves.count) move\(moves.count == 1 ? "" : "s")"
    }

    private var learningState: String {
        // Calculate overall learning state based on moves
        if moves.isEmpty { return "NEW" }

        let states = moves.compactMap { $0.learningState }
        if states.allSatisfy({ $0 == "MASTERY" }) { return "MASTERY" }
        if states.contains(where: { $0 == "LEARNING" }) { return "LEARNING" }
        return "NEW"
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Combo Header
                comboHeader

                // Timeline Section
                if isLoading {
                    loadingView
                } else if moves.isEmpty {
                    emptyTimelineView
                } else {
                    timelineSection
                }

                Spacer()
            }
        }
        .navigationTitle(combo.name ?? "Untitled Combo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .navigationDestination(for: NSManagedObjectID.self) { objectID in
            // Navigate to move detail when timeline node is tapped
            if let move = viewContext.object(with: objectID) as? Move {
                moveDetailView(for: move)
            }
        }
        .onAppear {
            logger.info("🎯 COMBO_DETAIL_VIEW: 🚀 View appeared for combo: \(combo.name ?? "Untitled Combo")")
            loadComboMoves()
        }
        .onChange(of: selectedMoveIndex) { _, newIndex in
            handleTimelineSelection(newIndex)
        }
    }

    // MARK: - Combo Header
    private var comboHeader: some View {
        VStack(spacing: 16) {
            // Combo name and stats
            VStack(spacing: 8) {
                Text(combo.name ?? "Untitled Combo")
                    .font(.ibmPlexMono(size: 28, weight: .bold))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text(moveCount)
                            .font(.ibmPlexMono(size: 16, weight: .medium))
                            .foregroundColor(.textPrimary)

                        Text("Total Moves")
                            .font(.ibmPlexMono(size: 12))
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 4) {
                        StatePillView(learningState: learningState)

                        Text("Progress")
                            .font(.ibmPlexMono(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider()
                .background(Color.gray.opacity(0.3))
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Timeline Section
    private var timelineSection: some View {
        VStack(spacing: 16) {
            Text("Timeline")
                .font(.ibmPlexMono(size: 20, weight: .bold))
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

            // Interactive timeline
            ComboTimelineView(
                moves: moves,
                activeIndex: $selectedMoveIndex,
                onDelete: { index in
                    deleteMove(at: index)
                }
            )
            .frame(height: 120)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)

            // Selected move info
            if let selectedIndex = selectedMoveIndex,
               selectedIndex < moves.count,
               let selectedMove = moves[selectedIndex] as Move? {
                selectedMoveInfo(selectedMove)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Selected Move Info
    private func selectedMoveInfo(_ move: Move) -> some View {
        VStack(spacing: 12) {
            Text("Selected Move")
                .font(.ibmPlexMono(size: 16, weight: .medium))
                .foregroundColor(.textPrimary)

            VStack(spacing: 8) {
                Text(move.name ?? "Untitled Move")
                    .font(.ibmPlexMono(size: 18, weight: .bold))
                    .foregroundColor(.textPrimary)

                StatePillView(learningState: move.learningState ?? "NEW")

                NavigationLink(value: move.objectID) {
                    HStack {
                        Text("View Details")
                            .font(.ibmPlexMono(size: 14, weight: .medium))
                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            SharedLoadingView(message: "Loading combo...")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty Timeline View
    private var emptyTimelineView: some View {
        VStack(spacing: 20) {
            Image(systemName: "timeline.selection")
                .font(.system(size: 64))
                .foregroundColor(.primary.opacity(0.5))

            Text("No moves in this combo")
                .font(.ibmPlexMono(size: 20, weight: .bold))
                .foregroundColor(.textPrimary)

            Text("Add moves to see the interactive timeline")
                .font(.ibmPlexMono(size: 16))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    // MARK: - Move Detail View
    private func moveDetailView(for move: Move) -> some View {
        MoveDetailView(move: move)
    }

    // MARK: - Actions
    private func loadComboMoves() {
        logger.info("🎯 COMBO_DETAIL_VIEW: Loading moves for combo")

        Task {
            await MainActor.run {
                isLoading = true

                // Fetch combo moves from Core Data relationship
                if let movesSet = combo.comboMoves as? Set<ComboMove> {
                    comboMoves = Array(movesSet)
                    logger.info("🎯 COMBO_DETAIL_VIEW: Loaded \(comboMoves.count) moves")
                } else {
                    comboMoves = []
                    logger.warning("🎯 COMBO_DETAIL_VIEW: No combo moves found for combo")
                }

                // Restore timeline node state from preserved active move
                restoreTimelineNodeState()

                isLoading = false
            }
        }
    }

    private func restoreTimelineNodeState() {
        logger.info("🎯 COMBO_DETAIL_VIEW: 🔄 Restoring timeline node state")

        // Try to get the active move from preserved state
        if let activeMove = combo.getActiveMove(in: viewContext) {
            // Find the index of this move in the current combo moves
            let moveIDs = moves.compactMap { ($0 as Move?)?.objectID }

            if let activeIndex = moveIDs.firstIndex(of: activeMove.objectID) {
                selectedMoveIndex = activeIndex
                logger.info("🎯 COMBO_DETAIL_VIEW: ✅ Restored timeline node to index \(activeIndex) - move: '\(activeMove.name ?? "Unknown")'")
            } else {
                logger.warning("🎯 COMBO_DETAIL_VIEW: ⚠️ Active move found but not in current combo moves - defaulting to index 0")
                selectedMoveIndex = moves.isEmpty ? nil : 0
            }
        } else {
            logger.info("🎯 COMBO_DETAIL_VIEW: ℹ️ No preserved timeline node state found - defaulting to index 0")
            selectedMoveIndex = moves.isEmpty ? nil : 0
        }
    }

    private func handleTimelineSelection(_ index: Int?) {
        guard let index, index < moves.count else {
            logger.warning("🎯 COMBO_DETAIL_VIEW: Invalid timeline selection: \(String(describing: index))")
            return
        }

        let move = moves[index]
        logger.info("🎯 COMBO_DETAIL_VIEW: Timeline selection changed to move '\(move.name ?? "Unknown")' at index \(index)")

        // Here you could trigger video playback or other actions
        // For now, just log the selection
    }

    private func deleteMove(at index: Int) {
        guard index < comboMoves.count else { return }

        let comboMoveToDelete = comboMoves[index]
        logger.info("🎯 COMBO_DETAIL_VIEW: Deleting move at index \(index)")

        withAnimation {
            comboMoves.remove(at: index)
            viewContext.delete(comboMoveToDelete)

            do {
                try viewContext.save()
                logger.info("🎯 COMBO_DETAIL_VIEW: Successfully deleted move")

                // Reset selection if needed
                if selectedMoveIndex == index {
                    selectedMoveIndex = comboMoves.isEmpty ? nil : max(0, index - 1)
                } else if let selected = selectedMoveIndex, selected > index {
                    selectedMoveIndex = selected - 1
                }
            } catch {
                logger.error("🎯 COMBO_DETAIL_VIEW: Failed to save after deleting move: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Preview
#Preview("Combo Detail - With Moves") {
    let context = PersistenceController.preview.container.viewContext

    // Create test combo with moves
    let combo = Combo(context: context)
    combo.name = "Test Combo"

    let moves = ["Top Rock", "Six Step", "Freeze", "Powermove"]
    for (index, moveName) in moves.enumerated() {
        let move = Move(context: context)
        move.name = moveName
        move.learningState = ["NEW", "LEARNING", "MASTERY", "LEARNING"][index]
        move.photosIdentifier = "test-\(UUID().uuidString)"

        let comboMove = ComboMove(context: context)
        comboMove.combo = combo
        comboMove.move = move
        comboMove.sequenceIndex = Int64(index)
    }

    try? context.save()

    return ComboDetailView(combo: combo)
        .environment(\.managedObjectContext, context)
}

#Preview("Combo Detail - Empty") {
    let context = PersistenceController.preview.container.viewContext

    let combo = Combo(context: context)
    combo.name = "Empty Combo"

    return ComboDetailView(combo: combo)
        .environment(\.managedObjectContext, context)
}