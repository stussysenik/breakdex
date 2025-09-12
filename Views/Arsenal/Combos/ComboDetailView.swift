//
//  ComboDetailView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/26/25.
//

import SwiftUI
import AVKit
import CoreData

struct ComboDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    let combo: Combo
    @State private var activeMoveIndex: Int? = 0
    
    var comboMoves: [ComboMove] {
        let fetchRequest = NSFetchRequest<ComboMove>(entityName: "ComboMove")
        fetchRequest.predicate = NSPredicate(format: "combo == %@", combo)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ComboMove.sequenceIndex, ascending: true)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            return []
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ComboDetailHeaderView(combo: combo, comboMovesCount: comboMoves.count)
                ComboDetailPlayerView(move: activeMove?.move)
                ComboDetailTimelineView(comboMoves: comboMoves, activeMoveIndex: $activeMoveIndex)
            }
            .padding(.vertical)
        }
        .background(Color.backgroundPrimary.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var activeMove: ComboMove? {
        guard let activeMoveIndex, comboMoves.indices.contains(activeMoveIndex) else {
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
