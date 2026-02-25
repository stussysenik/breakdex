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
            VStack(spacing: Spacing.lg) {
                // Combo Header
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(combo.name ?? "Untitled Combo")
                        .font(.titleSmall)
                        .foregroundColor(.textPrimary)

                    if !comboMoves.isEmpty {
                        Text("\(comboMoves.count) moves")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.lg)

                // Video Player
                CustomVideoPlayerView(move: activeMove?.move)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    .padding(.horizontal, Spacing.lg)

                // Timeline Section
                if !comboMoves.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("SEQUENCE")
                            .font(.caption)
                            .tracking(2)
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, Spacing.lg)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                ForEach(Array(comboMoves.enumerated()), id: \.element.id) { index, comboMove in
                                    if let move = comboMove.move {
                                        VStack(spacing: Spacing.sm) {
                                            TimelineNodeView(
                                                sequenceNumber: index + 1,
                                                isActive: activeMoveIndex == index,
                                                onDelete: {},
                                                move: move,
                                                showDelete: false
                                            )
                                            .onTapGesture {
                                                activeMoveIndex = index
                                            }

                                            Text(move.name ?? "Move")
                                                .font(.caption)
                                                .foregroundColor(.textPrimary)
                                                .frame(width: 70)
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
                            .padding(.horizontal, Spacing.lg)
                        }
                    }
                }
            }
            .padding(.vertical, Spacing.lg)
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
    let context = PersistenceController.preview.container.viewContext
    let combo = Combo(context: context)
    combo.id = UUID()
    combo.name = "Sample Combo"

    return ComboDetailView(combo: combo)
        .environment(\.managedObjectContext, context)
}
