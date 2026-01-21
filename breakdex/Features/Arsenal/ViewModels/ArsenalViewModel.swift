//
//  ArsenalViewModel.swift
//  BreakingFlashcards
//
//  Created by Claude Code on 10/10/25.
//

import SwiftUI
import CoreData
import OSLog
import Foundation

// MARK: - Arsenal ViewModel
/// Clean ViewModel for Arsenal feature that manages state and business logic
/// for both Moves and Combos lists, following single responsibility principle
@MainActor
class ArsenalViewModel: ObservableObject {

    // MARK: - Properties
    private let viewContext: NSManagedObjectContext
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🏟️ ARSENAL_VIEWMODEL")

    // MARK: - Published State
    @Published var movesSearchText = ""
    @Published var combosSearchText = ""
    @Published var isLoadingMoves = false
    @Published var isLoadingCombos = false
    @Published var errorMessage: String?

    // MARK: - Core Data Fetch Requests
    private lazy var movesFetchRequest: NSFetchRequest<Move> = {
        let request = Move.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Move.createdAt, ascending: false)]
        return request
    }()

    private lazy var combosFetchRequest: NSFetchRequest<Combo> = {
        let request = Combo.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Combo.name, ascending: true)]
        return request
    }()

    // MARK: - Fetched Results
    @Published private(set) var moves: [Move] = []
    @Published private(set) var combos: [Combo] = []

    // MARK: - Computed Properties
    var filteredMoves: [Move] {
        if movesSearchText.isEmpty {
            return moves
        } else {
            return moves.filter { move in
                move.name?.localizedCaseInsensitiveContains(movesSearchText) ?? false
            }
        }
    }

    var filteredCombos: [Combo] {
        if combosSearchText.isEmpty {
            return combos
        } else {
            return combos.filter { combo in
                combo.name?.localizedCaseInsensitiveContains(combosSearchText) ?? false
            }
        }
    }

    // MARK: - Initialization
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        self.logger.info("🏟️ ARSENAL_VIEWMODEL: 🚀 Initialized with clean architecture")

        // Load initial data
        loadData()
    }

    // MARK: - Data Loading
    /// Loads moves and combos from Core Data asynchronously
    func loadData() {
        logger.info("🏟️ ARSENAL_VIEWMODEL: 📥 Loading Arsenal data...")

        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadMoves() }
                group.addTask { await self.loadCombos() }
            }

            logger.info("🏟️ ARSENAL_VIEWMODEL: ✅ Data loading completed - Moves: \(moves.count), Combos: \(combos.count)")
        }
    }

    /// Loads moves from Core Data
    private func loadMoves() async {
        await MainActor.run {
            isLoadingMoves = true
        }

        do {
            let fetchedMoves = try viewContext.fetch(movesFetchRequest)
            await MainActor.run {
                self.moves = fetchedMoves
                self.isLoadingMoves = false
                logger.info("🏟️ ARSENAL_VIEWMODEL: ✅ Loaded \(fetchedMoves.count) moves")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load moves: \(error.localizedDescription)"
                self.isLoadingMoves = false
                logger.error("🏟️ ARSENAL_VIEWMODEL: ❌ Error loading moves: \(error.localizedDescription)")
            }
        }
    }

    /// Loads combos from Core Data
    private func loadCombos() async {
        await MainActor.run {
            isLoadingCombos = true
        }

        do {
            let fetchedCombos = try viewContext.fetch(combosFetchRequest)
            await MainActor.run {
                self.combos = fetchedCombos
                self.isLoadingCombos = false
                logger.info("🏟️ ARSENAL_VIEWMODEL: ✅ Loaded \(fetchedCombos.count) combos")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load combos: \(error.localizedDescription)"
                self.isLoadingCombos = false
                logger.error("🏟️ ARSENAL_VIEWMODEL: ❌ Error loading combos: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Move Operations
    
    /// Recently deleted move for undo support
    private var recentlyDeletedMove: (move: Move, wasDeleted: Bool)?
    private var undoTask: Task<Void, Never>?
    
    /// Deletes a move with undo support via toast
    func deleteMove(_ move: Move) async {
        let moveName = move.name ?? "Untitled Move"
        logger.info("🏟️ ARSENAL_VIEWMODEL: 🗑️ Deleting move: \(moveName)")

        do {
            // Store for potential undo
            recentlyDeletedMove = (move, false)
            
            // Remove from UI immediately
            await MainActor.run {
                moves.removeAll { $0.objectID == move.objectID }
            }
            
            // Show toast with undo action
            ToastManager.shared.show(
                "\(moveName) deleted",
                style: .success,
                duration: 4.0,
                action: { [weak self] in
                    Task {
                        await self?.undoDeleteMove()
                    }
                },
                actionLabel: "Undo"
            )
            
            // Schedule permanent deletion after toast duration
            undoTask?.cancel()
            undoTask = Task {
                try? await Task.sleep(nanoseconds: 4_500_000_000) // 4.5 seconds
                if !Task.isCancelled {
                    await self.permanentlyDeleteMove(move)
                }
            }

            logger.info("🏟️ ARSENAL_VIEWMODEL: ✅ Move marked for deletion with undo window")
        }
    }
    
    /// Permanently delete the move from Core Data
    private func permanentlyDeleteMove(_ move: Move) async {
        guard recentlyDeletedMove?.move.objectID == move.objectID else { return }
        
        do {
            viewContext.delete(move)
            try viewContext.save()
            recentlyDeletedMove = nil
            logger.info("🏟️ ARSENAL_VIEWMODEL: ✅ Move permanently deleted")
        } catch {
            // If permanent delete fails, restore to UI
            await loadMoves()
            ToastManager.shared.showError("Failed to delete: \(error.localizedDescription)")
            logger.error("🏟️ ARSENAL_VIEWMODEL: ❌ Error deleting move: \(error.localizedDescription)")
        }
    }
    
    /// Undo the most recent move deletion
    func undoDeleteMove() async {
        guard let deleted = recentlyDeletedMove else { return }
        
        undoTask?.cancel()
        undoTask = nil
        
        // Restore to UI
        await loadMoves()
        recentlyDeletedMove = nil
        
        ToastManager.shared.showInfo("\(deleted.move.name ?? "Move") restored")
        logger.info("🏟️ ARSENAL_VIEWMODEL: ↩️ Undo delete move")
    }

    /// Adds test moves for development/demo purposes
    func addTestMoves() async {
        logger.info("🏟️ ARSENAL_VIEWMODEL: ➕ Adding test moves...")

        let testMoves = [
            ("Windmill", "NEW"),
            ("Flare", "LEARNING"),
            ("Top Rock", "MASTERY"),
            ("Freeze", "NEW"),
            ("Six Step", "LEARNING"),
            ("Headspin", "NEW")
        ]

        await MainActor.run {
            for (name, state) in testMoves {
                let newMove = Move(context: viewContext)
                newMove.name = name
                newMove.createdAt = Date().addingTimeInterval(Double.random(in: -86400...0))
                newMove.learningState = state
                newMove.photosIdentifier = "test-\(UUID().uuidString)"
                newMove.trimStartTime = 0.0
                newMove.trimEndTime = 5.0
            }
        }

        do {
            try viewContext.save()
            await loadMoves()
            logger.info("🏟️ ARSENAL_VIEWMODEL: ✅ Added \(testMoves.count) test moves")
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to add test moves: \(error.localizedDescription)"
            }
            logger.error("🏟️ ARSENAL_VIEWMODEL: ❌ Error adding test moves: \(error.localizedDescription)")
        }
    }

    // MARK: - Combo Operations
    /// Deletes a combo from Core Data with error handling
    func deleteCombo(_ combo: Combo) async {
        logger.info("🏟️ ARSENAL_VIEWMODEL: 🗑️ Deleting combo: \(combo.name ?? "Untitled Combo")")

        do {
            viewContext.delete(combo)
            try viewContext.save()

            // Refresh combos list
            await loadCombos()

            logger.info("🏟️ ARSENAL_VIEWMODEL: ✅ Successfully deleted combo")
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to delete combo: \(error.localizedDescription)"
            }
            logger.error("🏟️ ARSENAL_VIEWMODEL: ❌ Error deleting combo: \(error.localizedDescription)")
        }
    }

    // MARK: - Combo Helper Methods
    /// Gets the number of moves in a combo
    func getMoveCount(for combo: Combo) -> String {
        let fetchRequest = ComboMove.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "combo == %@", combo)

        do {
            let count = try viewContext.count(for: fetchRequest)
            return "\(count) move\(count == 1 ? "" : "s")"
        } catch {
            logger.error("🏟️ ARSENAL_VIEWMODEL: ❌ Error getting move count for combo: \(error.localizedDescription)")
            return "0 moves"
        }
    }

    /// Determines the learning state for a combo based on its moves
    func getComboLearningState(for combo: Combo) -> String {
        let fetchRequest = ComboMove.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "combo == %@", combo)

        do {
            let comboMoves = try viewContext.fetch(fetchRequest)
            let moveStates = comboMoves.compactMap { $0.move?.learningState }

            if moveStates.isEmpty {
                return "NEW"
            }

            if moveStates.allSatisfy({ $0 == "MASTERY" }) {
                return "MASTERY"
            } else if moveStates.contains(where: { $0 == "LEARNING" }) {
                return "LEARNING"
            } else if moveStates.contains(where: { $0 == "NEW" }) {
                return "NEW"
            } else {
                return "NEW"
            }
        } catch {
            logger.error("🏟️ ARSENAL_VIEWMODEL: ❌ Error getting combo learning state: \(error.localizedDescription)")
            return "NEW"
        }
    }

    // MARK: - Search Management
    /// Clears the moves search text
    func clearMovesSearch() {
        movesSearchText = ""
        logger.info("🏟️ ARSENAL_VIEWMODEL: 🧹 Cleared moves search")
    }

    /// Clears the combos search text
    func clearCombosSearch() {
        combosSearchText = ""
        logger.info("🏟️ ARSENAL_VIEWMODEL: 🧹 Cleared combos search")
    }

    /// Clears all error messages
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Refresh Operations
    /// Refreshes all Arsenal data
    func refreshData() {
        logger.info("🏟️ ARSENAL_VIEWMODEL: 🔄 Refreshing Arsenal data...")
        loadData()
    }

    /// Refreshes only moves data
    func refreshMoves() {
        logger.info("🏟️ ARSENAL_VIEWMODEL: 🔄 Refreshing moves data...")
        Task {
            await loadMoves()
        }
    }

    /// Refreshes only combos data
    func refreshCombos() {
        logger.info("🏟️ ARSENAL_VIEWMODEL: 🔄 Refreshing combos data...")
        Task {
            await loadCombos()
        }
    }
}

// MARK: - Preview Support
#if DEBUG
extension ArsenalViewModel {
    /// Creates a preview instance for SwiftUI previews
    static var preview: ArsenalViewModel {
        let context = PersistenceController.shared.container.viewContext
        return ArsenalViewModel(viewContext: context)
    }
}
#endif