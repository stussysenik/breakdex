import SwiftUI
import OSLog
import UIKit
import CoreData

/// Clean combo timeline view using shared components
/// Displays a horizontal timeline of moves with selection and deletion capabilities
struct ComboTimelineView: View {
    // MARK: - Properties
    let moves: [Move]
    @Binding var activeIndex: Int?
    let onDelete: ((Int) -> Void)?

    // MARK: - Logging
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🎯 COMBO_TIMELINE_VIEW")

    // MARK: - Initialization
    init(moves: [Move], activeIndex: Binding<Int?>, onDelete: @escaping (Int) -> Void) {
        self.moves = moves
        self._activeIndex = activeIndex
        self.onDelete = onDelete
    }

    // MARK: - Body
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(moves.enumerated()), id: \.element.objectID) { index, move in
                        moveNode(at: index, move: move)

                        if index < moves.count - 1 {
                            connectionLine
                        }
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: activeIndex) { _, newIndex in
                handleActiveIndexChange(newIndex, proxy: proxy)
            }
        }
        .onAppear {
            handleViewAppear()
        }
    }

    // MARK: - View Components
    private func moveNode(at index: Int, move: Move) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 8) {
                // Simple timeline node for build compatibility
                VStack(spacing: 4) {
                    // Delete button
                    if let onDelete = onDelete {
                        Button("×") {
                            logger.info("🎯 COMBO_TIMELINE_VIEW: Delete button tapped for move at index \(index)")
                            onDelete(index)
                        }
                        .foregroundColor(.red)
                        .font(.system(size: 16, weight: .bold))
                    }

                    // Circle node
                    Circle()
                        .fill(activeIndex == index ? Color.primary : Color.gray)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .onTapGesture {
                    handleNodeTap(at: index, move: move)
                }

                // Move name
                Text(move.name ?? "Move")
                    .font(.ibmPlexMono(size: 12))
                    .foregroundColor(.textPrimary)
                    .frame(width: 70)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .id(move.objectID)
        }
    }

    private var connectionLine: some View {
        Rectangle()
            .frame(width: 30, height: 2)
            .foregroundColor(.gray)
            .offset(y: -28) // Align with center of nodes
    }

    // MARK: - Actions
    private func handleNodeTap(at index: Int, move: Move) {
        logger.info("🎯 COMBO_TIMELINE_VIEW: Timeline node tapped for move '\(move.name ?? "Unknown")' at index \(index)")
        activeIndex = index
    }

    private func handleActiveIndexChange(_ newIndex: Int?, proxy: ScrollViewProxy) {
        guard let newIndex, moves.indices.contains(newIndex) else {
            logger.warning("🎯 COMBO_TIMELINE_VIEW: Invalid activeIndex change to \(String(describing: newIndex))")
            return
        }

        logger.info("🎯 COMBO_TIMELINE_VIEW: Scrolling to active index \(newIndex)")

        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            proxy.scrollTo(moves[newIndex].objectID, anchor: UnitPoint.center)
        }
    }

    private func handleViewAppear() {
        logger.info("🎯 COMBO_TIMELINE_VIEW: Timeline view appeared with \(moves.count) moves")

        // Auto-select first move if none is active and moves exist
        if activeIndex == nil, !moves.isEmpty {
            logger.info("🎯 COMBO_TIMELINE_VIEW: Auto-selecting first move")
            activeIndex = 0
        }
    }
}

// MARK: - Preview
#Preview("Combo Timeline View") {
    VStack(spacing: 20) {
        Text("Combo Timeline")
            .font(.title)
            .padding()

        // Example with empty moves array for build compatibility
        ComboTimelineView(
            moves: [],
            activeIndex: .constant(nil),
            onDelete: { index in
                print("Delete move at index \(index)")
            }
        )
        .frame(height: 120)
        .border(Color.gray.opacity(0.3))

        Spacer()
    }
    .padding()
}