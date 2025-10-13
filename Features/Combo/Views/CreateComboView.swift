//
//  CreateComboView.swift
//  BreakingFlashcards
//
//  Created by Claude on 10/10/25.
//

import SwiftUI
import AVKit
import AVFoundation
import CoreData
import OSLog

/// Clean combo creation view using shared components and clean architecture
/// Follows MVVM pattern with proper separation of concerns
struct CreateComboView: View {
    // MARK: - Environment & Dependencies
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: Move.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Move.createdAt, ascending: true)],
        animation: .default
    )
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
        navigationContentView
            .sheet(isPresented: $viewModel.isMovePickerPresented) {
                movePickerSheet
            }
            .alert("Name Your Combo", isPresented: $viewModel.isNamingAlertPresented) {
                namingAlert
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
                if viewModel.activeMove != nil {
                    await viewModel.loadVideoForActiveMove()
                }
            }
    }

    // MARK: - Main View Content
    private var navigationContentView: some View {
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
    }
    // MARK: - Sheet Content
    private var movePickerSheet: some View {
        NavigationView {
            List(allMoves) { move in
                HStack {
                    Text(move.name ?? "Unnamed Move")
                        .font(.body)
                    Spacer()
                    if viewModel.comboMoves.contains(where: { $0.id == move.id }) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticFeedback.selectionHaptic()
                    if let index = viewModel.comboMoves.firstIndex(where: { $0.id == move.id }) {
                        viewModel.removeMove(at: index)
                    } else {
                        viewModel.addMove(move)
                    }
                }
            }
            .navigationTitle("Select Moves")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.hideMovePicker()
                    }
                }
            }
        }
    }

    // MARK: - Alert Content
    private var namingAlert: some View {
        Group {
            TextField("Combo Name", text: $viewModel.comboName)
            Button("Cancel", role: .cancel) {
                viewModel.hideNamingAlert()
            }
            Button("Save") {
                viewModel.saveCombo()
            }
        }
    }

    // MARK: - Timeline Binding
    private var timelineActiveIndexBinding: Binding<Int?> {
        Binding(
            get: { viewModel.activeNodeIndex },
            set: { newIndex in
                if let newIndex = newIndex {
                    viewModel.selectMove(at: newIndex)
                }
            }
        )
    }

    // MARK: - View Components
    private var headerSection: some View {
        VStack(spacing: 16) {
            SharedButton.primary(
                "+ Create Combo",
                size: .large
            ) {
                HapticFeedback.buttonTap()
                HapticFeedback.actionHaptic()
                viewModel.showMovePicker()
            }
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
                    if let currentPlayer = viewModel.currentPlayer {
                        // Use AVPlayerViewRepresentable for video playback
                        AVPlayerViewRepresentable(player: currentPlayer)
                            .onAppear {
                                // Start playing when view appears
                                currentPlayer.play()
                            }
                            .onDisappear {
                                // Pause when view disappears
                                currentPlayer.pause()
                            }
                    } else if viewModel.isLoadingVideo {
                        // Use shared SharedLoadingView
                        SharedLoadingView.withMessage("Loading video...", style: .circular)
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
                    activeIndex: timelineActiveIndexBinding,
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
                SharedButton.primary(
                    "Save Combo",
                    size: .large
                ) {
                    HapticFeedback.actionHaptic()
                    HapticFeedback.notificationHaptic(.success)
                    viewModel.showNamingAlert()
                }
                .padding(.horizontal, 20)
                .disabled(!viewModel.canSaveCombo)
            }
        }
    }
}


// MARK: - Preview
#Preview("Create Combo View") {
    CreateComboView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}