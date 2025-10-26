//
//  MoveListView.swift
//  BreakingFlashcards
//
//  Created by Claude Code on 10/10/25.
//  Refactored to use ArsenalViewModel and shared components
//

import SwiftUI
import CoreData
import OSLog
import UIKit

// MARK: - Move List View
/// Clean view for displaying and managing moves list using ArsenalViewModel
/// Follows single responsibility principle - only handles UI presentation
struct MoveListView: View {

    // MARK: - Properties
    @Environment(\.managedObjectContext) private var viewContext
    private let onNavigateToAdd: () -> Void
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "📋 MOVE_LIST_VIEW")

    // MARK: - ViewModel
    @StateObject private var viewModel: ArsenalViewModel

    // MARK: - Initialization
    init(onNavigateToAdd: @escaping () -> Void) {
        self.onNavigateToAdd = onNavigateToAdd
        self._viewModel = StateObject(wrappedValue: ArsenalViewModel(viewContext: PersistenceController.shared.container.viewContext))
    }

    // MARK: - Body
    var body: some View {
        ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                // MARK: - Content
                VStack {
                    if viewModel.isLoadingMoves {
                        loadingView
                    } else if viewModel.filteredMoves.isEmpty {
                        emptyStateView
                    } else {
                        movesList
                    }
                }
            }
            .searchable(text: $viewModel.movesSearchText, prompt: "Search Moves...")
            .onAppear {
                logger.info("📋 MoveListView: View appeared")
                viewModel.refreshMoves()
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
        VStack(spacing: 20) {
            Image(systemName: "figure.martial.arts")
                .font(.system(size: 64))
                .foregroundColor(.primary.opacity(0.5))

            Text("No moves added yet")
                .font(.ibmPlexMono(size: 24, weight: .bold))
                .foregroundColor(.textPrimary)

            Text("Tap below to start building your breaking arsenal!")
                .font(.ibmPlexMono(size: 16))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            Button("Add Move") {
                onNavigateToAdd()
                logger.info("📋 MOVE_LIST_VIEW: ➕ Navigate to Add Move")
            }
            .font(.ibmPlexMono(size: 16, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 40)
            .padding(.top, 20)

            // Development helper - add test moves
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                Button("Add Test Moves") {
                    Task {
                        await viewModel.addTestMoves()
                    }
                }
                .font(.ibmPlexMono(size: 14, weight: .medium))
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.2))
                .clipShape(Capsule())
                .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
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
        Group {
            if viewModel.filteredMoves.isEmpty && !viewModel.movesSearchText.isEmpty {
                noSearchResultsView
            } else {
                List(viewModel.filteredMoves, id: \.objectID) { move in
                    MoveRowView(
                        move: move,
                        onDelete: {
                            Task {
                                await viewModel.deleteMove(move)
                            }
                        }
                    )
                    .listRowBackground(Color.backgroundPrimary)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .onAppear {
                    logger.info("📋 NAVIGATION_SUCCESS: List+NavigationLink working - MovesList appeared")
                }
            }
        }
    }
}

// MARK: - Move Row View
/// Reusable component for displaying a single move in the list
private struct MoveRowView: View {

    // MARK: - Properties
    let move: Move
    let onDelete: () -> Void
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "📋 MOVE_ROW_VIEW")

    // MARK: - Body
    var body: some View {
        NavigationLink(value: move) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(move.name ?? "Untitled Move")
                        .font(.ibmPlexMono(size: 18, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text("Added: \(move.createdAt ?? Date(), format: .dateTime.month().day().year().hour().minute())")
                        .font(.ibmPlexMono(size: 11))
                        .foregroundColor(.primary)

                    // Enhanced debugging info
                    if let photosIdentifier = move.photosIdentifier {
                        Text("Video ID: \(String(photosIdentifier.prefix(8)))...")
                            .font(.caption2)
                            .foregroundColor(.primary.opacity(0.7))
                    } else {
                        Text("No Video ID")
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                StatePillView(learningState: move.learningState ?? "NEW")
                    .fixedSize()
                    .frame(maxHeight: .infinity, alignment: .center)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(SpringButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", role: .destructive) {
                onDelete()
                MotionCatalog.Accessibility.actionHaptic()
                logger.info("📋 MOVE_ROW_VIEW: 🗑️ Deleted move: \(move.name ?? "Untitled Move")")
            }
            .tint(.red)
        }
    }
}

// MARK: - Spring Button Style
/// Consistent button style for move interactions
private struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview("Move List - Empty") {
    let context = PersistenceController.preview.container.viewContext
    // Clear any existing moves for empty state preview
    let request = NSBatchDeleteRequest(fetchRequest: Move.fetchRequest() as! NSFetchRequest<NSFetchRequestResult>)
    try? context.execute(request)

    return MoveListView(onNavigateToAdd: {})
        .environment(\.managedObjectContext, context)
}

// MARK: - Test Data Creation
private func createTestMoves(in context: NSManagedObjectContext) {
    // Add test data for preview
    let testMoves = ["Windmill", "Flare", "Top Rock"]
    for (index, name) in testMoves.enumerated() {
        let move = Move(context: context)
        move.name = name
        move.createdAt = Date().addingTimeInterval(Double(-index * 3600))
        move.learningState = ["NEW", "LEARNING", "MASTERY"][index]
        move.photosIdentifier = "test-\(UUID().uuidString)"
        move.id = UUID()  // Ensure test data has proper UUID assignment
    }
    _ = try? context.save()
}

#Preview("Move List - With Data") {
    let context = PersistenceController.preview.container.viewContext
    createTestMoves(in: context)

    return MoveListView(onNavigateToAdd: {})
        .environment(\.managedObjectContext, context)
}