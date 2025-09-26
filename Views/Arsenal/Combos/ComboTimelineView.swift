// In ComboTimelineView.swift
import SwiftUI
import OSLog

struct ComboTimelineView: View {
    let moves: [Move]
    @Binding var activeIndex: Int?
    let onDelete: ((Int) -> Void)?

    // A flexible initializer for both editable and read-only modes
    init(moves: [Move], activeIndex: Binding<Int?>, onDelete: ((Int) -> Void)? = nil) {
        self.moves = moves
        self._activeIndex = activeIndex
        self.onDelete = onDelete
    }

    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🎯 COMBO_TIMELINE_VIEW")

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(moves.enumerated()), id: \.element.managedObjectID) { index, move in
                        HStack(spacing: 0) {
                            VStack(spacing: 8) {
                                // 🎯 FIX: Use the advanced TimelineNodeView for consistent UI
                                TimelineNodeView(
                                    sequenceNumber: index + 1,
                                    isActive: activeIndex == index,
                                    onDelete: {
                                        logger.info("🎯 COMBO_TIMELINE_VIEW: Delete button tapped for move at index \(index)")
                                        onDelete?(index)
                                    },
                                    move: move,
                                    showDelete: onDelete != nil // Show delete button only if an onDelete handler is provided
                                )
                                .onTapGesture {
                                    logger.info("🎯 COMBO_TIMELINE_VIEW: Timeline node tapped for move '\(move.name ?? "Unknown")' at index \(index)")
                                    activeIndex = index
                                }

                                Text(move.name ?? "Move")
                                    .font(.ibmPlexMono(size: 12))
                                    .foregroundColor(.textPrimary)
                                    .frame(width: 70) // Match the node's frame width
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }

                            if index < moves.count - 1 {
                                Rectangle()
                                    .frame(width: 30, height: 2)
                                    .foregroundColor(.gray)
                                    .offset(y: -28) // Vertically align with the center of the nodes
                            }
                        }
                        .id(move.managedObjectID)
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: activeIndex) { _, newIndex in
                guard let newIndex, moves.indices.contains(newIndex) else {
                    logger.warning("🎯 COMBO_TIMELINE_VIEW: Invalid activeIndex change to \(String(describing: newIndex))")
                    return
                }

                logger.info("🎯 COMBO_TIMELINE_VIEW: Scrolling to active index \(newIndex)")
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    proxy.scrollTo(moves[newIndex].managedObjectID, anchor: .center)
                }
            }
        }
        .onAppear {
            logger.info("🎯 COMBO_TIMELINE_VIEW: Timeline view appeared with \(moves.count) moves")
            // Auto-select first move if none is active and moves exist
            if activeIndex == nil, !moves.isEmpty {
                logger.info("🎯 COMBO_TIMELINE_VIEW: Auto-selecting first move")
                activeIndex = 0
            }
        }
    }
}

#Preview {
    ComboTimelineView(moves: [], activeIndex: .constant(nil), onDelete: { _ in })
}
