import SwiftUI
import CoreData

struct ComboDetailTimelineView: View {
    let comboMoves: [ComboMove]
    @Binding var activeMoveIndex: Int?

    var body: some View {
        if !comboMoves.isEmpty { // timeline Section
            Text("COMBO SEQUENCE")
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
}