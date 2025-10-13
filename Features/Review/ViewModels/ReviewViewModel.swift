//
//  ReviewViewModel.swift
//  BreakingFlashcards
//
//  Created by Claude on 10/10/25.
//

import SwiftUI
import CoreData
import OSLog

/// Clean ViewModel for review feature management
/// Handles learning state calculations and review statistics
@MainActor
class ReviewViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var moves: [Move] = []
    @Published var combos: [Combo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - Dependencies
    private let viewContext: NSManagedObjectContext
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "📚 REVIEW_VIEWMODEL")

    // MARK: - Caching
    private var _comboStatesCache: [NSManagedObjectID: String] = [:]
    private var _lastCacheUpdate: Date = Date.distantPast

    // MARK: - Initialization
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        logger.info("📚 REVIEW_VIEWMODEL: Initialized with clean architecture")
    }

    // MARK: - Data Loading
    /// Load moves and combos from Core Data
    func loadData() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let (loadedMoves, loadedCombos) = try await fetchFromCoreData()

            await MainActor.run {
                self.moves = loadedMoves
                self.combos = loadedCombos
                self.isLoading = false
                self.invalidateComboStatesCache()
            }

            logger.info("📚 REVIEW_VIEWMODEL: Loaded \(loadedMoves.count) moves and \(loadedCombos.count) combos")

        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to load review data: \(error.localizedDescription)"
                self.showError = true
            }
            logger.error("📚 REVIEW_VIEWMODEL: Error loading data: \(error)")
        }
    }

    private func fetchFromCoreData() async throws -> (moves: [Move], combos: [Combo]) {
        let movesRequest: NSFetchRequest<Move> = Move.fetchRequest()
        movesRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Move.createdAt, ascending: false)]

        let combosRequest: NSFetchRequest<Combo> = Combo.fetchRequest()
        combosRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Combo.name, ascending: true)]

        let loadedMoves = try viewContext.fetch(movesRequest)
        let loadedCombos = try viewContext.fetch(combosRequest)

        return (loadedMoves, loadedCombos)
    }

    // MARK: - Move Learning States
    /// Count moves by learning state
    var newMovesCount: Int {
        moves.filter { $0.learningState == "NEW" }.count
    }

    var learningMovesCount: Int {
        moves.filter { $0.learningState == "LEARNING" }.count
    }

    var masteryMovesCount: Int {
        moves.filter { $0.learningState == "MASTERY" }.count
    }

    /// Check if there are any moves to review
    var hasMovesToReview: Bool {
        !moves.isEmpty
    }

    // MARK: - Combo Learning States (Optimized)
    /// Optimized combo states cache with performance tracking
    /// 🚀 PERFORMANCE: Reduces O(N) database queries to O(1) using memoization
    ///  METRICS: Logs performance and state distribution for debugging
    var comboStates: [NSManagedObjectID: String] {
        let cacheAge = Date().timeIntervalSince(_lastCacheUpdate)

        // Invalidate cache if it's older than 5 seconds or if combos changed
        if cacheAge > 5.0 || _comboStatesCache.count != combos.count {
            logger.info("📚 REVIEW_VIEWMODEL: 🔄 Refreshing combo states cache (age: \(cacheAge)s)")
            refreshComboStatesCache()
        }

        return _comboStatesCache
    }

    /// Count combos by learning state using optimized cache
    var newCombosCount: Int {
        comboStates.values.filter { $0 == "NEW" }.count
    }

    var learningCombosCount: Int {
        comboStates.values.filter { $0 == "LEARNING" }.count
    }

    var masteryCombosCount: Int {
        comboStates.values.filter { $0 == "MASTERY" }.count
    }

    /// Check if there are any combos to review
    var hasCombosToReview: Bool {
        !combos.isEmpty
    }

    /// Check if there's anything to review at all
    var hasContentToReview: Bool {
        hasMovesToReview || hasCombosToReview
    }

    // MARK: - Combo State Calculation
    /// Refresh the combo states cache with current data
    private func refreshComboStatesCache() {
        logger.info("📚 REVIEW_VIEWMODEL: 🔄 Calculating combo learning states for \(combos.count) combos")

        var newStates: [NSManagedObjectID: String] = [:]
        var stateCounts: [String: Int] = ["NEW": 0, "LEARNING": 0, "MASTERY": 0]

        for combo in combos {
            let state = calculateComboLearningState(for: combo)
            newStates[combo.objectID] = state
            stateCounts[state, default: 0] += 1
        }

        _comboStatesCache = newStates
        _lastCacheUpdate = Date()

        logger.info("📚 REVIEW_VIEWMODEL: ✅ Combo state calculation complete")
        logger.info("📚 REVIEW_VIEWMODEL:  State distribution - NEW: \(stateCounts["NEW"] ?? 0), LEARNING: \(stateCounts["LEARNING"] ?? 0), MASTERY: \(stateCounts["MASTERY"] ?? 0)")
    }

    /// Invalidate the combo states cache (call when data changes)
    func invalidateComboStatesCache() {
        _comboStatesCache.removeAll()
        _lastCacheUpdate = Date.distantPast
        logger.info("📚 REVIEW_VIEWMODEL: 🗑️ Combo states cache invalidated")
    }

    /// Calculate learning state for a single combo using in-memory data
    /// MARK: - MEMORY: Uses relationship data instead of additional database queries
    ///  LOGS: Detailed logging for debugging combo state logic
    private func calculateComboLearningState(for combo: Combo) -> String {
        logger.info("📚 REVIEW_VIEWMODEL: 🔄 Calculating state for combo: \(combo.name ?? "Unknown")")

        // Use existing relationship data instead of fetching
        guard let comboMoves = combo.comboMoves as? Set<ComboMove> else {
            logger.warning("📚 REVIEW_VIEWMODEL: ⚠️ No combo moves relationship found for combo: \(combo.name ?? "Unknown")")
            return "NEW"
        }

        let moveStates = comboMoves.compactMap { $0.move?.learningState }
        logger.info("📚 REVIEW_VIEWMODEL:  Found \(moveStates.count) move states: \(moveStates)")

        // Business logic for determining combo learning state
        let calculatedState: String

        if moveStates.isEmpty {
            calculatedState = "NEW"
        } else if moveStates.allSatisfy({ $0 == "MASTERY" }) {
            calculatedState = "MASTERY"
        } else if moveStates.contains("NEW") {
            calculatedState = "NEW"
        } else if moveStates.contains("LEARNING") {
            calculatedState = "LEARNING"
        } else {
            calculatedState = "NEW" // Fallback for edge cases
        }

        logger.info("📚 REVIEW_VIEWMODEL: ✅ Combo '\(combo.name ?? "Unknown")' calculated state: \(calculatedState)")
        return calculatedState
    }

    // MARK: - Review Statistics
    /// Get total items available for review
    var totalItemsToReview: Int {
        moves.count + combos.count
    }

    /// Get items by learning state across both moves and combos
    func getItemsByLearningState(_ state: String) -> (moves: Int, combos: Int) {
        let movesCount = moves.filter { $0.learningState == state }.count
        let combosCount = comboStates.values.filter { $0 == state }.count
        return (moves: movesCount, combos: combosCount)
    }

    /// Get review statistics for all learning states
    var reviewStatistics: ReviewStatistics {
        ReviewStatistics(
            newMoves: newMovesCount,
            learningMoves: learningMovesCount,
            masteryMoves: masteryMovesCount,
            newCombos: newCombosCount,
            learningCombos: learningCombosCount,
            masteryCombos: masteryCombosCount,
            totalMoves: moves.count,
            totalCombos: combos.count
        )
    }

    // MARK: - Error Handling
    /// Dismiss error message
    func dismissError() {
        showError = false
        errorMessage = nil
    }

    // MARK: - Navigation Helpers
    /// Check if a specific learning state has content for review
    func hasContentForLearningState(_ state: String, type: ReviewType) -> Bool {
        switch type {
        case .moves:
            return moves.contains { $0.learningState == state }
        case .combos:
            return comboStates.values.contains(state)
        }
    }

    /// Get count for specific learning state and type
    func getCountForLearningState(_ state: String, type: ReviewType) -> Int {
        switch type {
        case .moves:
            switch state {
            case "NEW": return newMovesCount
            case "LEARNING": return learningMovesCount
            case "MASTERY": return masteryMovesCount
            default: return 0
            }
        case .combos:
            switch state {
            case "NEW": return newCombosCount
            case "LEARNING": return learningCombosCount
            case "MASTERY": return masteryCombosCount
            default: return 0
            }
        }
    }
}

// MARK: - Supporting Types
struct ReviewStatistics {
    let newMoves: Int
    let learningMoves: Int
    let masteryMoves: Int
    let newCombos: Int
    let learningCombos: Int
    let masteryCombos: Int
    let totalMoves: Int
    let totalCombos: Int

    var totalItems: Int {
        totalMoves + totalCombos
    }

    var hasContent: Bool {
        totalItems > 0
    }
}

enum ReviewType {
    case moves
    case combos
}

// MARK: - Preview Support
#if DEBUG
extension ReviewViewModel {
    /// Create a preview version for SwiftUI previews
    static var preview: ReviewViewModel {
        let context = PersistenceController.preview.container.viewContext
        return ReviewViewModel(viewContext: context)
    }
}
#endif