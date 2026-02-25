// In ComboTimelineView.swift
import SwiftUI

struct ComboTimelineView: View {
    @Binding var moves: [Move]
    @Binding var activeIndex: Int?
    let showDeleteButtons: Bool
    
    init(moves: Binding<[Move]>, activeIndex: Binding<Int?>, showDeleteButtons: Bool = true) {
        self._moves = moves
        self._activeIndex = activeIndex
        self.showDeleteButtons = showDeleteButtons
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) { // Use regular HStack for this layout
                    ForEach(Array(moves.enumerated()), id: \.element.id) { index, move in
                        HStack(spacing: 0) {
                            TimelineNodeView(
                                sequenceNumber: index + 1,
                                isActive: activeIndex == index,
                                onDelete: {
                                    moves.remove(at: index)
                                    // Reset active index intelligently
                                    if moves.isEmpty {
                                        activeIndex = nil
                                    } else if index <= (activeIndex ?? 0) {
                                        activeIndex = 0
                                    }
                                },
                                move: move,
                                showDelete: showDeleteButtons
                            )
                            .onTapGesture { activeIndex = index }

                            if index < moves.count - 1 {
                                Rectangle().frame(width: 30, height: 2).foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: activeIndex) { oldIndex, newIndex in
                if let newIndex, moves.indices.contains(newIndex) {
                    withAnimation { proxy.scrollTo(moves[newIndex].id, anchor: .center) }
                }
            }
        }
        .appMotion(activeIndex ?? -1)
    }
}

#Preview {
    ComboTimelineView(moves: .constant([]), activeIndex: .constant(nil), showDeleteButtons: true)
}
