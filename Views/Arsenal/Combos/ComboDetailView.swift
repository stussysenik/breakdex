//
//  ComboDetailView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/26/25.
//

import SwiftUI
import AVKit
import CoreData
import OSLog

struct ComboDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext

    let combo: Combo
    @State private var activeMoveIndex: Int? = 0

    private let logger = Logger(subsystem: "com.breakingflashcards", category: "📋 COMBO_DETAIL_VIEW")

    var comboMoves: [ComboMove] {
        let fetchRequest = NSFetchRequest<ComboMove>(entityName: "ComboMove")
        fetchRequest.predicate = NSPredicate(format: "combo == %@", combo)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ComboMove.sequenceIndex, ascending: true)]

        do {
            let moves = try viewContext.fetch(fetchRequest)
            logger.info("📋 COMBO_DETAIL_VIEW: Fetched \(moves.count) moves for combo '\(combo.name ?? "Unknown")'")
            return moves
        } catch {
            logger.error("📋 COMBO_DETAIL_VIEW: Failed to fetch combo moves: \(error.localizedDescription)")
            return []
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ComboDetailHeaderView(combo: combo, comboMovesCount: comboMoves.count)

                // This view now correctly handles async loading internally
                ComboDetailPlayerView(move: activeMove?.move)

                // 🎯 FIX: Use the unified ComboTimelineView for read-only display
                let movesForTimeline = comboMoves.compactMap { $0.move }
                if !movesForTimeline.isEmpty {
                    Text("COMBO SEQUENCE")
                        .font(.ibmPlexMono(size: 18, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    ComboTimelineView(
                        moves: movesForTimeline,
                        activeIndex: $activeMoveIndex
                        // No onDelete handler is passed, so it will be read-only
                    )
                    .frame(height: 120)
                } else {
                    Text("No moves in this combo")
                        .font(.ibmPlexMono(size: 16))
                        .foregroundColor(.textSecondary)
                        .frame(height: 120)
                }
            }
            .padding(.vertical)
        }
        .background(Color.backgroundPrimary.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            logger.info("📋 COMBO_DETAIL_VIEW: Detail view appeared for combo '\(combo.name ?? "Unknown")'")
            // Auto-select first move if none is active and moves exist
            if activeMoveIndex == nil, !comboMoves.isEmpty {
                logger.info("📋 COMBO_DETAIL_VIEW: Auto-selecting first move")
                activeMoveIndex = 0
            }
        }
    }

    private var activeMove: ComboMove? {
        guard let activeMoveIndex, comboMoves.indices.contains(activeMoveIndex) else {
            // Default to the first move if no index is active but moves exist
            if activeMoveIndex == nil, !comboMoves.isEmpty {
                logger.info("📋 COMBO_DETAIL_VIEW: Auto-selecting first move (index 0)")
                DispatchQueue.main.async { activeMoveIndex = 0 }
            }
            return nil
        }
        return comboMoves[activeMoveIndex]
    }
}

#Preview {
    let context = PersistenceController.shared.container.viewContext
    let combo = Combo(context: context)
    // Note: We don't set the id as it's managed by Core Data
    combo.name = "Sample Combo"
    
    return ComboDetailView(combo: combo)
        .environment(\.managedObjectContext, context)
}
