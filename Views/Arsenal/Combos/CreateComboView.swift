// In CreateComboView.swift
import SwiftUI
import AVKit
import CoreData
import OSLog

struct CreateComboView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Move.createdAt, ascending: true)])
    private var allMoves: FetchedResults<Move>

    @State private var comboMoves: [Move] = []
    @State private var activeNodeIndex: Int? = nil
    @State private var isMovePickerPresented = false
    @State private var isNamingAlertPresented = false
    @State private var comboName = ""
    @State private var showSuccessMessage = false
    @State private var showErrorMessage = false
    @State private var successMessage = ""
    @State private var errorMessage = ""
    @State private var currentPlayer: AVPlayer? // MARK: - ADD: State for the async player

    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🚀 CREATE_COMBO_VIEW")
    
    var body: some View {
        VStack(spacing: 6) {
            Button("+ Create Combo") {
                MotionCatalog.Accessibility.buttonTap()
                MotionCatalog.Accessibility.actionHaptic()
                isMovePickerPresented = true
            }
            .font(.ibmPlexMono(size: 20, weight: .regular))
            .padding(.vertical, 40)
            .padding(.horizontal, 20)
            
            // MARK: - FIX: Asynchronous Video Player Section
            if let activeMove = activeMove {
                ZStack {
                    if let player = currentPlayer {
                        CustomVideoPlayerView(viewModel: UnifiedVideoPlayerViewModel(player: player, mode: .main, appContainer: AppContainer.shared))
                    } else {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading video...")
                                .font(.ibmPlexMono(size: 14))
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
                .frame(height: 300)
                .background(Color.black)
                .cornerRadius(10)
                .padding(.horizontal)
                .id(activeMove.id) // Use stable ID to trigger updates
                .task(id: activeMove.id) {
                    logger.info("🚀 CREATE_COMBO_VIEW: Starting video load for move '\(activeMove.name ?? "Unknown")'")
                    currentPlayer = nil // Reset the player to show the loader
                    guard let identifier = activeMove.photosIdentifier else {
                        logger.error("🚀 CREATE_COMBO_VIEW: No photosIdentifier for move '\(activeMove.name ?? "Unknown")'")
                        return
                    }

                    if let avAsset = await PhotosAssetLoader.fetchAsset(with: identifier) {
                        logger.info("🚀 CREATE_COMBO_VIEW: Video asset loaded successfully for move '\(activeMove.name ?? "Unknown")'")
                        // Once the asset is loaded, create the player on the main thread
                        await MainActor.run {
                            self.currentPlayer = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
                        }
                    } else {
                        logger.error("🚀 CREATE_COMBO_VIEW: Failed to load video asset for move '\(activeMove.name ?? "Unknown")'")
                    }
                }
            } else {
                ContentUnavailableView("No move selected", systemImage: "video.slash")
                    .frame(height: 300)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {   // bottom Section: timeline group
                Text("COMBO SEQUENCE")
                    .font(.ibmPlexMono(size: 18, weight: .bold))
                    .foregroundColor(.textPrimary)
                
                // MARK: - FIX: Use the upgraded, unified ComboTimelineView
                ComboTimelineView(moves: comboMoves, activeIndex: $activeNodeIndex) { index in
                    logger.info("🚀 CREATE_COMBO_VIEW: Delete button tapped for move at index \(index)")
                    // Deletion logic
                    comboMoves.remove(at: index)

                    if comboMoves.isEmpty {
                        logger.info("🚀 CREATE_COMBO_VIEW: All moves removed, clearing active index")
                        activeNodeIndex = nil
                    } else if let currentIndex = activeNodeIndex, index <= currentIndex {
                        // Smartly adjust the active index after deletion
                        let newIndex = max(0, currentIndex - 1)
                        logger.info("🚀 CREATE_COMBO_VIEW: Adjusting active index from \(currentIndex) to \(newIndex)")
                        activeNodeIndex = newIndex
                    }
                }
                .frame(height: 120)
                
                Button("Save Combo") {
                    MotionCatalog.Accessibility.actionHaptic()
                    MotionCatalog.Accessibility.successHaptic()
                    isNamingAlertPresented = true
                }
                .font(.custom("IBMPlexMono-Regular", size: 18)) // IBM Plex Mono font
                .buttonStyle(.appAccent(size: .large))
                .disabled(comboMoves.isEmpty)
                
                Spacer(minLength: 20)
            }
        }
        .sheet(isPresented: $isMovePickerPresented) {
            MovePickerSheet(allMoves: allMoves, selectedMoves: $comboMoves)
        }
        .alert("Name Your Combo", isPresented: $isNamingAlertPresented) { // alert dialog
            TextField("Combo Name", text: $comboName)
            Button("Cancel", role: .cancel) {
                comboName = ""
            }
            Button("Save") {
                saveCombo(name: comboName.isEmpty ? "Combo \(Date().formatted(date: .abbreviated, time: .shortened))" : comboName)
                comboName = ""
            }
        } message: {
            Text("Enter a name for your combo to save it.")
        }
        .alert("Success", isPresented: $showSuccessMessage) {
            Button("OK") { showSuccessMessage = false }
        } message: {
            Text(successMessage)
        }
        .alert("Error", isPresented: $showErrorMessage) {
            Button("OK") { showErrorMessage = false }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var activeMove: Move? {
        guard let activeNodeIndex, !comboMoves.isEmpty, comboMoves.indices.contains(activeNodeIndex) else {
            // Default to the first move if no index is active but moves exist
            if activeNodeIndex == nil, !comboMoves.isEmpty {
                logger.info("🚀 CREATE_COMBO_VIEW: Auto-selecting first move (index 0)")
                DispatchQueue.main.async { activeNodeIndex = 0 }
            }
            return nil
        }
        return comboMoves[activeNodeIndex]
    }
    
    private func saveCombo(name: String) {
        logger.info("🚀 CREATE_COMBO_VIEW: Starting combo save process for '\(name)' with \(comboMoves.count) moves")

        // MARK: - NEW: Validate combo name uniqueness (case-insensitive)
        logger.info("🚀 CREATE_COMBO_VIEW: 🔍 Validating combo name uniqueness")
        let fetchRequest: NSFetchRequest<Combo> = Combo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", name)

        do {
            let existingCombos = try viewContext.fetch(fetchRequest)
            if !existingCombos.isEmpty {
                logger.error("🚀 CREATE_COMBO_VIEW: ❌ A combo named '\(name)' already exists (\(existingCombos.count) duplicates found)")
                logger.error("🚀 CREATE_COMBO_VIEW: ❌ Duplicate combo IDs: \(existingCombos.map { $0.id ?? UUID() })")
                errorMessage = "A combo named '\(name)' already exists. Please use a different name."
                showErrorMessage = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showErrorMessage = false
                }
                return
            }

            logger.info("🚀 CREATE_COMBO_VIEW: ✅ Combo name uniqueness validated - no duplicates found")
        } catch {
            logger.error("🚀 CREATE_COMBO_VIEW: ❌ Error checking for duplicate combo names: \(error)")
            errorMessage = "Failed to validate combo name. Please try again."
            showErrorMessage = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showErrorMessage = false
            }
            return
        }

        let newCombo = Combo(context: viewContext)
        // Note: We don't set the id as it's managed by Core Data
        newCombo.name = name

        for (index, move) in comboMoves.enumerated() {
            let comboMove = ComboMove(context: viewContext)
            // Note: We don't set the id as it's managed by Core Data
            comboMove.sequenceIndex = Int64(index)
            comboMove.move = move
            comboMove.combo = newCombo
            logger.info("🚀 CREATE_COMBO_VIEW: Added move '\(move.name ?? "Unknown")' at sequence index \(index)")
        }

        do {
            try viewContext.save()
            logger.info("🚀 CREATE_COMBO_VIEW: Combo '\(name)' saved successfully to Core Data")

            successMessage = "Combo '\(name)' created successfully!" // success message
            showSuccessMessage = true

            comboMoves.removeAll() // reset combo after saving
            activeNodeIndex = nil
            currentPlayer = nil // Clear the video player

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { // auto-hide success message after 3 seconds
                showSuccessMessage = false
            }
        } catch {
            logger.error("🚀 CREATE_COMBO_VIEW: Failed to save combo: \(error.localizedDescription)")
            errorMessage = "Failed to save combo. Please try again."
            showErrorMessage = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showErrorMessage = false
            }
        }
    }
}

#Preview {
    CreateComboView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
