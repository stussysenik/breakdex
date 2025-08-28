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
                // Combo Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(combo.name ?? "Untitled Combo")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)

                    if !comboMoves.isEmpty {
                        Text("\(comboMoves.count) moves")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // Video Player Section
                CustomVideoPlayerView(move: activeMove?.move)
                    .frame(height: 300)
                    .cornerRadius(10)
                    .padding(.horizontal)

                // Timeline Section
                if !comboMoves.isEmpty {
                    Text("Combo Sequence")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(comboMoves.enumerated()), id: \.element.id) { index, comboMove in
                                if let move = comboMove.move {
                                    VStack(spacing: 8) {
                                        TimelineNodeView(
                                            sequenceNumber: index + 1,
                                            isActive: activeMoveIndex == index,
                                            onDelete: {}, // No delete functionality in detail view
                                            move: move,
                                            showDelete: false
                                        )
                                        .onTapGesture {
                                            activeMoveIndex = index
                                        }

                                        Text(move.name ?? "Move")
                                            .font(.caption)
                                            .foregroundColor(.textPrimary)
                                            .frame(width: 60)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                    }
                                }

                                if index < comboMoves.count - 1 {
                                    Rectangle()
                                        .frame(width: 30, height: 2)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Combo Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var activeMove: ComboMove? {
        guard let activeMoveIndex, comboMoves.indices.contains(activeMoveIndex) else {
            return nil
        }
        return comboMoves[activeMoveIndex]
    }

    private func videoURL(for move: Move) -> URL {
        let path = String(data: move.videoReference ?? Data(), encoding: .utf8) ?? ""
        return URL(filePath: path)
    }
}

#Preview {
    let context = PersistenceController.shared.container.viewContext
    let combo = Combo(context: context)
    combo.id = UUID()
    combo.name = "Sample Combo"

    return ComboDetailView(combo: combo)
        .environment(\.managedObjectContext, context)
}
