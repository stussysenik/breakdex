//
//  CreateComboView.swift
//  BreakingFlashcards
//
//  Created by Claude on 10/10/25.
//

import SwiftUI
import AVKit
import CoreData
import OSLog

/// Clean combo creation view using shared components and clean architecture
/// Follows MVVM pattern with proper separation of concerns
struct CreateComboView: View {
    // MARK: - Environment & Dependencies
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Move.createdAt, ascending: true)])
    private var allMoves: FetchedResults<Move>

    // MARK: - State
    @StateObject private var viewModel: ComboViewModel
    @State private var showSheet = false

    // MARK: - Initialization
    init() {
        // ViewModel will be injected with viewContext in the body
        _viewModel = StateObject(wrappedValue: ComboViewModel(viewContext: PersistenceController.shared.container.viewContext))
    }

    private init(viewModel: ComboViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // MARK: - Header Section
                headerSection

                // MARK: - Video Player Section
                videoPlayerSection

                // MARK: - Timeline Section
                timelineSection

                // MARK: - Actions Section
                actionsSection

                Spacer(minLength: 20)
            }
            .navigationTitle("Create Combo")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemBackground))
        }
        .onAppear {
            // Inject proper viewContext when view appears
            viewModel.viewContext = viewContext
        }
        .sheet(isPresented: $viewModel.isMovePickerPresented) {
            MovePickerSheet(allMoves: allMoves, selectedMoves: Binding(
                get: { viewModel.comboMoves },
                set: { newMoves in
                    // Handle moves being added/removed from the picker
                    let currentMoves = Set(viewModel.comboMoves.map { $0.id })
                    let newMovesSet = Set(newMoves.map { $0.id })

                    // Add new moves
                    for move in newMoves where !currentMoves.contains(move.id) {
                        viewModel.addMove(move)
                    }

                    // Remove moves that are no longer selected
                    for move in viewModel.comboMoves where !newMovesSet.contains(move.id) {
                        if let index = viewModel.comboMoves.firstIndex(where: { $0.id == move.id }) {
                            viewModel.removeMove(at: index)
                        }
                    }
                }
            ))
        }
        .alert("Name Your Combo", isPresented: $viewModel.isNamingAlertPresented) {
            TextField("Combo Name", text: $viewModel.comboName)
            Button("Cancel", role: .cancel) {
                viewModel.hideNamingAlert()
            }
            Button("Save") {
                viewModel.saveCombo()
            }
        } message: {
            Text("Enter a name for your combo to save it.")
        }
        .alert("Success", isPresented: $viewModel.showSuccessMessage) {
            Button("OK") {
                viewModel.hideSuccessMessage()
            }
        } message: {
            Text(viewModel.successMessage)
        }
        .alert("Error", isPresented: $viewModel.showErrorMessage) {
            Button("OK") {
                viewModel.hideErrorMessage()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .task(id: viewModel.activeMove?.id) {
            if let activeMove = viewModel.activeMove {
                await viewModel.loadVideoForActiveMove()
            }
        }
    }

    // MARK: - View Components
    private var headerSection: some View {
        VStack(spacing: 16) {
            SharedButton(
                title: "+ Create Combo",
                style: .primary,
                size: .large,
                isLoading: false,
                action: {
                    MotionCatalog.Accessibility.buttonTap()
                    MotionCatalog.Accessibility.actionHaptic()
                    viewModel.showMovePicker()
                }
            )
            .padding(.horizontal, 20)

            if !viewModel.comboMoves.isEmpty {
                Text("\(viewModel.comboMoves.count) move\(viewModel.comboMoves.count == 1 ? "" : "s") selected")
                    .font(.ibmPlexMono(size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var videoPlayerSection: some View {
        VStack(spacing: 16) {
            if let activeMove = viewModel.activeMove {
                ZStack {
                    if let player = viewModel.currentPlayer {
                        // Use shared VideoPlayerView for consistent video playback
                        VideoPlayerView(
                            player: player,
                            configuration: .preview,
                            showsControls: true,
                            autoPlay: true
                        )
                    } else if viewModel.isLoadingVideo {
                        // Use shared LoadingView for consistent loading states
                        LoadingView(
                            style: .circular,
                            message: "Loading video...",
                            showMessage: true
                        )
                    } else {
                        ContentUnavailableView(
                            "Video Unavailable",
                            systemImage: "video.slash",
                            description: Text("Unable to load video for this move")
                        )
                    }
                }
                .frame(height: 300)
                .background(Color.black)
                .cornerRadius(12)
                .padding(.horizontal)
                .id(activeMove.id) // Use stable ID to trigger updates

                // Active move name
                Text(activeMove.name ?? "Unknown Move")
                    .font(.ibmPlexMono(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal)

            } else {
                // Empty state when no move is selected
                ContentUnavailableView(
                    "No Move Selected",
                    systemImage: "video.circle",
                    description: Text("Add moves to your combo to see video previews")
                )
                .frame(height: 300)
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    private var timelineSection: some View {
        VStack(spacing: 16) {
            if !viewModel.comboMoves.isEmpty {
                Text("COMBO SEQUENCE")
                    .font(.ibmPlexMono(size: 18, weight: .bold))
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                // Timeline view will be created separately
                ComboTimelineView(
                    moves: viewModel.comboMoves,
                    activeIndex: Binding(
                        get: { viewModel.activeNodeIndex },
                        set: { newIndex in
                            if let newIndex = newIndex {
                                viewModel.selectMove(at: newIndex)
                            }
                        }
                    ),
                    onDelete: { index in
                        viewModel.removeMove(at: index)
                    }
                )
                .frame(height: 120)
                .padding(.horizontal, 20)
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 16) {
            if !viewModel.comboMoves.isEmpty {
                SharedButton(
                    title: "Save Combo",
                    style: .primary,
                    size: .large,
                    isLoading: false,
                    isDisabled: !viewModel.canSaveCombo,
                    action: {
                        MotionCatalog.Accessibility.actionHaptic()
                        MotionCatalog.Accessibility.successHaptic()
                        viewModel.showNamingAlert()
                    }
                )
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Dependency Injection Extension
extension ComboViewModel {
    /// Allow viewContext injection after initialization
    var viewContext: NSManagedObjectContext {
        get { fatalError("Use injected viewContext") }
        set { /* handled via closure */ }
    }
}

// MARK: - Preview
#Preview {
    CreateComboView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        .previewDisplayName("Create Combo View")
}