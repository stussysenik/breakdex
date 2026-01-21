//
//  MoveListView.swift
//  BreakingFlashcards
//
//  Created by Claude Code on 10/10/25.
//  Refactored to use ArsenalViewModel and shared components
//  Updated: Video-centric cards with golden ratio layouts
//

import SwiftUI
import CoreData
import OSLog
import UIKit

// MARK: - Move List View
/// Video-centric view for displaying and managing moves list using ArsenalViewModel.
/// Features golden ratio card layouts with smooth 60fps scroll performance.
struct MoveListView: View {

    // MARK: - Properties
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var accessibility = AccessibilityManager.shared
    private let onNavigateToAdd: () -> Void
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "📋 MOVE_LIST_VIEW")

    // MARK: - ViewModel
    @StateObject private var viewModel: ArsenalViewModel

    // MARK: - Layout State
    @State private var useGridLayout = false
    @State private var hasPreloadedThumbnails = false

    // MARK: - Initialization
    init(onNavigateToAdd: @escaping () -> Void) {
        self.onNavigateToAdd = onNavigateToAdd
        self._viewModel = StateObject(wrappedValue: ArsenalViewModel(viewContext: PersistenceController.shared.container.viewContext))
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    if viewModel.isLoadingMoves {
                        loadingView
                    } else if viewModel.filteredMoves.isEmpty && viewModel.movesSearchText.isEmpty {
                        emptyStateView
                    } else if viewModel.filteredMoves.isEmpty {
                        noSearchResultsView
                    } else {
                        movesList
                    }
                }
            }
            .navigationTitle("Moves")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.medium))
                    }
                    .accessibilityLabel("Go back")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // Layout toggle
                        Button {
                            withAnimation(MotionSystem.micro) {
                                useGridLayout.toggle()
                            }
                            HapticFeedback.selectionHaptic()
                        } label: {
                            Image(systemName: useGridLayout ? "list.bullet" : "square.grid.2x2")
                                .font(.body)
                        }
                        .accessibilityLabel(useGridLayout ? "Switch to list view" : "Switch to grid view")

                        // Theme toggle
                        ThemeToggleButton()
                    }
                }
            }
            .searchable(text: $viewModel.movesSearchText, prompt: "Search Moves...")
            .navigationDestination(for: Move.self) { move in
                MoveDetailView(move: move)
            }
        }
        .onAppear {
            logger.info("📋 MoveListView: View appeared")
            viewModel.refreshMoves()
            preloadThumbnailsIfNeeded()
        }
        .onChange(of: viewModel.filteredMoves) { _, newMoves in
            // Preload thumbnails when moves change
            preloadThumbnailsForVisibleMoves(newMoves)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Thumbnail Preloading

    private func preloadThumbnailsIfNeeded() {
        guard !hasPreloadedThumbnails else { return }
        hasPreloadedThumbnails = true

        Task {
            await ThumbnailGenerator.shared.preloadThumbnails(
                for: Array(viewModel.filteredMoves.prefix(10))
            )
        }
    }

    private func preloadThumbnailsForVisibleMoves(_ moves: [Move]) {
        Task {
            await ThumbnailGenerator.shared.preloadThumbnails(
                for: Array(moves.prefix(6))
            )
        }
    }

    // MARK: - Loading View
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 20) {
            SharedLoadingView.withMessage("Loading moves...", style: .circular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State View
    @ViewBuilder
    private var emptyStateView: some View {
        VStack {
            EmptyStateView(
                icon: "figure.martial.arts",
                title: "No Moves Yet",
                description: "Start building your breaking arsenal by adding your first move.",
                ctaTitle: "Add Move",
                ctaAction: {
                    onNavigateToAdd()
                    logger.info("📋 MOVE_LIST_VIEW: ➕ Navigate to Add Move")
                }
            )

            // Development helper - add test moves
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                Button("Add Test Moves") {
                    Task {
                        await viewModel.addTestMoves()
                    }
                }
                .font(.ibmPlexMono(size: 14, weight: .medium))
                .foregroundColor(.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.neutralGray100)
                .clipShape(Capsule())
                .padding(.bottom, Spacing.xl)
            }
        }
    }

    // MARK: - No Search Results View
    @ViewBuilder
    private var noSearchResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.primary.opacity(0.5))

            Text("No moves found")
                .font(.ibmPlexMono(size: 20, weight: .bold))
                .foregroundColor(.textPrimary)

            Text("Try a different search term")
                .font(.ibmPlexMono(size: 16))
                .foregroundColor(.primary)

            Button("Clear Search") {
                viewModel.clearMovesSearch()
                logger.info("📋 MOVE_LIST_VIEW: 🧹 Cleared search")
            }
            .font(.ibmPlexMono(size: 14, weight: .medium))
            .foregroundColor(.blue)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.2))
            .clipShape(Capsule())
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Moves List
    @ViewBuilder
    private var movesList: some View {
        ScrollView {
            if useGridLayout {
                gridLayout
            } else {
                listLayout
            }
        }
        .refreshable {
            viewModel.refreshMoves()
        }
        .onAppear {
            logger.info("📋 NAVIGATION_SUCCESS: Video-centric MovesList appeared")
        }
    }

    // MARK: - Grid Layout
    @ViewBuilder
    private var gridLayout: some View {
        let columns = [
            GridItem(.flexible(), spacing: Spacing.md),
            GridItem(.flexible(), spacing: Spacing.md)
        ]

        LazyVGrid(columns: columns, spacing: Spacing.md) {
            ForEach(viewModel.filteredMoves, id: \.objectID) { move in
                NavigationLink(value: move) {
                    CompactMoveCard(move: move)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.deleteMove(move)
                        }
                        HapticFeedback.actionHaptic()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .transition(.springScale)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - List Layout
    @ViewBuilder
    private var listLayout: some View {
        LazyVStack(spacing: Spacing.md) {
            ForEach(viewModel.filteredMoves, id: \.objectID) { move in
                NavigationLink(value: move) {
                    MoveListRowCard(move: move)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.deleteMove(move)
                        }
                        HapticFeedback.actionHaptic()
                        logger.info("📋 MOVE_LIST_VIEW: 🗑️ Deleted move via context menu: \(move.name ?? "Untitled Move")")
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .transition(.springScale)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Preview

#if DEBUG
// MARK: - Test Data Creation
private func createTestMoves(in context: NSManagedObjectContext) {
    // Add test data for preview
    let testMoves = [
        ("Windmill", "NEW"),
        ("Flare", "LEARNING"),
        ("Top Rock", "MASTERY"),
        ("Six Step", "LEARNING"),
        ("Air Flare", "NEW")
    ]
    for (index, (name, state)) in testMoves.enumerated() {
        let move = Move(context: context)
        move.name = name
        move.createdAt = Date().addingTimeInterval(Double(-index * 3600))
        move.learningState = state
        move.photosIdentifier = "test-\(UUID().uuidString)"
        move.id = UUID()
        move.trimStartTime = 0
        move.trimEndTime = Double(15 + index * 5) // 15-35 second clips
    }
    _ = try? context.save()
}

#Preview("Move List - Empty") {
    let context = PersistenceController.preview.container.viewContext
    // Clear any existing moves for empty state preview
    let request = NSBatchDeleteRequest(fetchRequest: Move.fetchRequest() as! NSFetchRequest<NSFetchRequestResult>)
    _ = try? context.execute(request)

    return MoveListView(onNavigateToAdd: {})
        .environment(\.managedObjectContext, context)
}

#Preview("Move List - With Data") {
    let context = PersistenceController.preview.container.viewContext
    createTestMoves(in: context)

    return MoveListView(onNavigateToAdd: {})
        .environment(\.managedObjectContext, context)
}
#endif