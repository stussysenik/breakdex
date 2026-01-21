import SwiftUI
import OSLog
import UIKit
import CoreData

/// Clean combo timeline view using shared components
/// Displays a horizontal timeline of moves with selection, deletion, and export capabilities
struct ComboTimelineView: View {
    // MARK: - Properties
    let moves: [Move]
    @Binding var activeIndex: Int?
    let onDelete: ((Int) -> Void)?
    let onExportMove: ((Move) -> Void)?
    let onExportSegment: ((Range<Int>) -> Void)?

    // MARK: - Logging
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🎯 COMBO_TIMELINE_VIEW")

    // MARK: - State
    @State private var showExportAlert = false
    @State private var selectedMoveForExport: Move?
    @State private var selectedIndexForExport: Int = 0

    // MARK: - Initialization
    init(
        moves: [Move],
        activeIndex: Binding<Int?>,
        onDelete: ((Int) -> Void)? = nil,
        onExportMove: ((Move) -> Void)? = nil,
        onExportSegment: ((Range<Int>) -> Void)? = nil
    ) {
        self.moves = moves
        self._activeIndex = activeIndex
        self.onDelete = onDelete
        self.onExportMove = onExportMove
        self.onExportSegment = onExportSegment
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
        .alert("Export Options", isPresented: $showExportAlert) {
            Button("Export This Move") {
                if let move = selectedMoveForExport {
                    onExportMove?(move)
                }
            }
            Button("Export from Here") {
                let startIndex = selectedIndexForExport
                let endIndex = moves.count
                onExportSegment?(startIndex..<endIndex)
            }
            Button("Cancel", role: .cancel) {
                selectedMoveForExport = nil
                selectedIndexForExport = 0
            }
        } message: {
            if let move = selectedMoveForExport {
                Text("Choose what to export for '\(move.name ?? "This move")':")
            }
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
                .onLongPressGesture {
                    handleNodeLongPress(at: index, move: move)
                }
                .background(
                    NavigationLink(value: move.objectID) {
                        EmptyView() // Navigation handled by parent view
                    }
                    .opacity(0) // Invisible but tappable
                )

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

        // Provide haptic feedback
        MotionCatalog.Accessibility.selectionHaptic()

        // Log previous selection state
        logger.info("🎯 COMBO_TIMELINE_VIEW: Previous selection state: \(String(describing: activeIndex))")

        // Update active index for visual feedback
        activeIndex = index

        // Log new selection state
        logger.info("🎯 COMBO_TIMELINE_VIEW: Updated selection to index: \(index)")

        // Navigation is handled by the NavigationLink in the background
        logger.info("🎯 COMBO_TIMELINE_VIEW: Navigation triggered for move objectID: \(move.objectID)")
    }

    private func handleNodeLongPress(at index: Int, move: Move) {
        logger.info("🎯 COMBO_TIMELINE_VIEW: Timeline node long-pressed for move '\(move.name ?? "Unknown")' at index \(index)")

        // Provide haptic feedback
        MotionCatalog.Accessibility.selectionHaptic()

        // Show export options
        selectedMoveForExport = move
        selectedIndexForExport = index
        showExportAlert = true
    }

    private func handleActiveIndexChange(_ newIndex: Int?, proxy: ScrollViewProxy) {
        logger.info("🎯 COMBO_TIMELINE_VIEW: Active index binding changed from \(String(describing: activeIndex)) to \(String(describing: newIndex))")

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

        // Log current selection state in detail
        if let currentIndex = activeIndex {
            logger.info("🎯 COMBO_TIMELINE_VIEW: Existing selection found at index \(currentIndex)")
            if moves.indices.contains(currentIndex) {
                logger.info("🎯 COMBO_TIMELINE_VIEW: Preserving valid selection at index \(currentIndex)")
                if currentIndex < moves.count {
                    let moveName = moves[currentIndex].name ?? "Unknown"
                    logger.info("🎯 COMBO_TIMELINE_VIEW: Currently selected move: '\(moveName)'")
                }
                return // Exit early - preserve existing selection
            } else {
                logger.warning("🎯 COMBO_TIMELINE_VIEW: Invalid selection index \(currentIndex), resetting to 0")
            }
        } else {
            logger.info("🎯 COMBO_TIMELINE_VIEW: No current selection - activeIndex is nil")
        }

        // Auto-select first move only if no valid selection exists
        if !moves.isEmpty {
            logger.info("🎯 COMBO_TIMELINE_VIEW: Auto-selecting first move")
            activeIndex = 0
        } else {
            logger.info("🎯 COMBO_TIMELINE_VIEW: No moves available - keeping selection nil")
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