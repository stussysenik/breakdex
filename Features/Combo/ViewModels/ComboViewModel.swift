//
//  ComboViewModel.swift
//  BreakingFlashcards
//
//  Created by Claude on 10/10/25.
//

import SwiftUI
import AVKit
import CoreData
import OSLog
import Photos

/// Clean ViewModel for combo creation and management
/// Handles all business logic, state management, and video operations
@MainActor
class ComboViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var comboMoves: [Move] = []
    @Published var activeNodeIndex: Int? = nil
    @Published var isMovePickerPresented = false
    @Published var isNamingAlertPresented = false
    @Published var comboName = ""
    @Published var showSuccessMessage = false
    @Published var showErrorMessage = false
    @Published var successMessage = ""
    @Published var errorMessage = ""
    @Published var currentPlayer: AVPlayer?
    @Published var isLoadingVideo = false

    // MARK: - Dependencies
    private let viewContext: NSManagedObjectContext
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🚀 COMBO_VIEWMODEL")

    // MARK: - Initialization
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        logger.info("🚀 COMBO_VIEWMODEL: Initialized with clean architecture")
    }

    // MARK: - Computed Properties
    var activeMove: Move? {
        guard let activeNodeIndex,
              !comboMoves.isEmpty,
              comboMoves.indices.contains(activeNodeIndex) else {
            // Auto-select first move if no index is active but moves exist
            if activeNodeIndex == nil, !comboMoves.isEmpty {
                logger.info("🚀 COMBO_VIEWMODEL: Auto-selecting first move (index 0)")
                DispatchQueue.main.async {
                    self.activeNodeIndex = 0
                }
            }
            return nil
        }
        return comboMoves[activeNodeIndex]
    }

    var canSaveCombo: Bool {
        !comboMoves.isEmpty
    }

    // MARK: - Video Management
    /// Load video for the currently active move
    func loadVideoForActiveMove() async {
        guard let activeMove = activeMove else {
            logger.warning("🚀 COMBO_VIEWMODEL: No active move to load video for")
            return
        }

        await MainActor.run {
            self.isLoadingVideo = true
            self.currentPlayer = nil
        }

        logger.info("🚀 COMBO_VIEWMODEL: Starting video load for move '\(activeMove.name ?? "Unknown")'")

        guard let identifier = activeMove.photosIdentifier else {
            logger.error("🚀 COMBO_VIEWMODEL: No photosIdentifier for move '\(activeMove.name ?? "Unknown")'")
            await MainActor.run {
                self.isLoadingVideo = false
            }
            return
        }

        do {
            if let avAsset = try await PhotosAssetLoader.fetchAsset(with: identifier) {
                logger.info("🚀 COMBO_VIEWMODEL: Video asset loaded successfully for move '\(activeMove.name ?? "Unknown")'")

                await MainActor.run {
                    self.currentPlayer = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
                    self.isLoadingVideo = false
                }
            } else {
                logger.error("🚀 COMBO_VIEWMODEL: Failed to load video asset for move '\(activeMove.name ?? "Unknown")'")
                await MainActor.run {
                    self.isLoadingVideo = false
                }
            }
        } catch {
            logger.error("🚀 COMBO_VIEWMODEL: Error loading video asset: \(error)")
            await MainActor.run {
                self.isLoadingVideo = false
                self.errorMessage = "Failed to load video: \(error.localizedDescription)"
                self.showErrorMessage = true
            }
        }
    }

    // MARK: - Combo Management
    /// Add a move to the combo sequence
    func addMove(_ move: Move) {
        guard !comboMoves.contains(where: { $0.id == move.id }) else {
            logger.warning("🚀 COMBO_VIEWMODEL: Move '\(move.name ?? "Unknown")' already exists in combo")
            return
        }

        comboMoves.append(move)
        logger.info("🚀 COMBO_VIEWMODEL: Added move '\(move.name ?? "Unknown")' to combo (total: \(comboMoves.count))")

        // Auto-select first move if this is the only one
        if comboMoves.count == 1 {
            activeNodeIndex = 0
            Task {
                await loadVideoForActiveMove()
            }
        }
    }

    /// Remove a move from the combo sequence at the specified index
    func removeMove(at index: Int) {
        guard comboMoves.indices.contains(index) else {
            logger.warning("🚀 COMBO_VIEWMODEL: Invalid index \(index) for move removal")
            return
        }

        let removedMove = comboMoves[index]
        comboMoves.remove(at: index)
        logger.info("🚀 COMBO_VIEWMODEL: Removed move '\(removedMove.name ?? "Unknown")' at index \(index)")

        // Handle active index adjustment
        if comboMoves.isEmpty {
            logger.info("🚀 COMBO_VIEWMODEL: All moves removed, clearing active index")
            activeNodeIndex = nil
            currentPlayer = nil
        } else if let currentIndex = activeNodeIndex, index <= currentIndex {
            // Smartly adjust the active index after deletion
            let newIndex = max(0, currentIndex - 1)
            logger.info("🚀 COMBO_VIEWMODEL: Adjusting active index from \(currentIndex) to \(newIndex)")
            activeNodeIndex = newIndex

            // Load video for new active move
            Task {
                await loadVideoForActiveMove()
            }
        }
    }

    /// Move to a different move in the sequence
    func selectMove(at index: Int) {
        guard comboMoves.indices.contains(index) else {
            logger.warning("🚀 COMBO_VIEWMODEL: Invalid index \(index) for move selection")
            return
        }

        if activeNodeIndex != index {
            activeNodeIndex = index
            logger.info("🚀 COMBO_VIEWMODEL: Selected move at index \(index)")

            // Load video for newly selected move
            Task {
                await loadVideoForActiveMove()
            }
        }
    }

    // MARK: - Combo Saving
    /// Save the current combo with the specified name
    func saveCombo() {
        let name = comboName.isEmpty ?
            "Combo \(Date().formatted(date: .abbreviated, time: .shortened))" :
            comboName

        logger.info("🚀 COMBO_VIEWMODEL: Starting combo save process for '\(name)' with \(comboMoves.count) moves")

        // Validate combo name uniqueness (case-insensitive)
        guard validateComboNameUniqueness(name: name) else {
            return
        }

        // Create the combo entity
        let newCombo = Combo(context: viewContext)
        newCombo.name = name

        // Add combo moves with sequence indices
        for (index, move) in comboMoves.enumerated() {
            let comboMove = ComboMove(context: viewContext)
            comboMove.sequenceIndex = Int64(index)
            comboMove.move = move
            comboMove.combo = newCombo
            logger.info("🚀 COMBO_VIEWMODEL: Added move '\(move.name ?? "Unknown")' at sequence index \(index)")
        }

        // Save to Core Data
        do {
            try viewContext.save()
            logger.info("🚀 COMBO_VIEWMODEL: Combo '\(name)' saved successfully to Core Data")

            // Show success and reset state
            successMessage = "Combo '\(name)' created successfully!"
            showSuccessMessage = true

            resetAfterSave()

        } catch {
            logger.error("🚀 COMBO_VIEWMODEL: Failed to save combo: \(error.localizedDescription)")
            errorMessage = "Failed to save combo. Please try again."
            showErrorMessage = true
        }
    }

    /// Validate that the combo name is unique
    private func validateComboNameUniqueness(name: String) -> Bool {
        logger.info("🚀 COMBO_VIEWMODEL: 🔍 Validating combo name uniqueness")

        let fetchRequest: NSFetchRequest<Combo> = Combo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", name)

        do {
            let existingCombos = try viewContext.fetch(fetchRequest)
            if !existingCombos.isEmpty {
                logger.error("🚀 COMBO_VIEWMODEL: ❌ A combo named '\(name)' already exists (\(existingCombos.count) duplicates found)")
                logger.error("🚀 COMBO_VIEWMODEL: ❌ Duplicate combo IDs: \(existingCombos.map { $0.id ?? UUID() })")

                errorMessage = "A combo named '\(name)' already exists. Please use a different name."
                showErrorMessage = true
                return false
            }

            logger.info("🚀 COMBO_VIEWMODEL: ✅ Combo name uniqueness validated - no duplicates found")
            return true

        } catch {
            logger.error("🚀 COMBO_VIEWMODEL: ❌ Error checking for duplicate combo names: \(error)")
            errorMessage = "Failed to validate combo name. Please try again."
            showErrorMessage = true
            return false
        }
    }

    /// Reset the view model state after successful save
    private func resetAfterSave() {
        comboMoves.removeAll()
        activeNodeIndex = nil
        comboName = ""
        currentPlayer = nil

        // Auto-hide success message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showSuccessMessage = false
        }
    }

    // MARK: - UI State Management
    /// Show the move picker
    func showMovePicker() {
        logger.info("🚀 COMBO_VIEWMODEL: Showing move picker")
        isMovePickerPresented = true
    }

    /// Hide the move picker
    func hideMovePicker() {
        logger.info("🚀 COMBO_VIEWMODEL: Hiding move picker")
        isMovePickerPresented = false
    }

    /// Show the naming alert
    func showNamingAlert() {
        logger.info("🚀 COMBO_VIEWMODEL: Showing naming alert")
        guard canSaveCombo else {
            logger.warning("🚀 COMBO_VIEWMODEL: Cannot save combo - no moves added")
            return
        }
        isNamingAlertPresented = true
    }

    /// Hide the naming alert
    func hideNamingAlert() {
        logger.info("🚀 COMBO_VIEWMODEL: Hiding naming alert")
        comboName = ""
        isNamingAlertPresented = false
    }

    /// Hide success message
    func hideSuccessMessage() {
        showSuccessMessage = false
    }

    /// Hide error message
    func hideErrorMessage() {
        showErrorMessage = false
    }

    // MARK: - Cleanup
    /// Clean up resources when view model is deallocated
    deinit {
        logger.info("🚀 COMBO_VIEWMODEL: Deinitializing and cleaning up resources")
        // Access MainActor-isolated properties safely in deinit
        Task { @MainActor in
            self.currentPlayer?.pause()
            self.currentPlayer = nil
        }
    }
}

// MARK: - Preview Support
#if DEBUG
extension ComboViewModel {
    /// Create a preview version for SwiftUI previews
    static var preview: ComboViewModel {
        let context = PersistenceController.preview.container.viewContext
        return ComboViewModel(viewContext: context)
    }
}
#endif