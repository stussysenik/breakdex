import Foundation
import CoreData
import Combine
import OSLog

// MARK: - Review Type

enum ReviewType: String, CaseIterable, Identifiable {
    case moves = "Moves"
    case combos = "Combos"
    case all = "All"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .moves: return "figure.dance"
        case .combos: return "link"
        case .all: return "square.grid.2x2"
        }
    }
}

// MARK: - Flashcard Review View Model
/// Manages the state and logic for flashcard review sessions.
/// Handles card navigation, rating, and CoreData updates.

@MainActor
final class FlashcardReviewViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var moves: [Move] = []
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var isCardRevealed: Bool = false
    @Published private(set) var isLoading: Bool = true
    @Published private(set) var isSessionComplete: Bool = false
    @Published private(set) var sessionStats: ReviewSessionStats = ReviewSessionStats()
    @Published private(set) var sessionXPEarned: Int = 0

    // MARK: - Properties

    let learningState: String
    let reviewType: ReviewType
    private let viewContext: NSManagedObjectContext
    private let logger = Logger(subsystem: "com.breakdex", category: "FlashcardReview")

    // MARK: - Computed Properties

    var currentMove: Move? {
        guard currentIndex < moves.count else { return nil }
        return moves[currentIndex]
    }

    var totalCards: Int {
        moves.count
    }

    var sessionProgress: Double {
        guard totalCards > 0 else { return 0 }
        return Double(currentIndex) / Double(totalCards)
    }

    var currentSpacedRepetitionState: SpacedRepetitionState {
        guard let move = currentMove else { return SpacedRepetitionState() }
        return getSpacedRepetitionState(for: move)
    }

    var remainingCards: Int {
        max(0, totalCards - currentIndex)
    }

    // MARK: - Initialization

    init(learningState: String, reviewType: ReviewType, viewContext: NSManagedObjectContext) {
        self.learningState = learningState
        self.reviewType = reviewType
        self.viewContext = viewContext

        sessionStats.startTime = Date()
    }

    // MARK: - Loading

    func loadMoves() {
        isLoading = true

        Task {
            do {
                let fetchRequest: NSFetchRequest<Move> = Move.fetchRequest()

                // Build predicate based on learning state and review type
                var predicates: [NSPredicate] = []

                // Filter by learning state if not "All"
                if learningState != "ALL" {
                    predicates.append(NSPredicate(format: "learningState == %@", learningState))
                }

                // Filter by due date (items that need review)
                let now = Date()
                let duePredicate = NSPredicate(
                    format: "nextReviewDate == nil OR nextReviewDate <= %@",
                    now as NSDate
                )
                predicates.append(duePredicate)

                // Combine predicates
                if !predicates.isEmpty {
                    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                }

                // Sort by priority:
                // 1. Most overdue first
                // 2. Then by creation date
                fetchRequest.sortDescriptors = [
                    NSSortDescriptor(keyPath: \Move.nextReviewDate, ascending: true),
                    NSSortDescriptor(keyPath: \Move.createdAt, ascending: true)
                ]

                // Limit session size
                fetchRequest.fetchLimit = 20

                let fetchedMoves = try viewContext.fetch(fetchRequest)
                moves = fetchedMoves
                sessionStats.totalCards = fetchedMoves.count

                logger.info("Loaded \(fetchedMoves.count) moves for review")

            } catch {
                logger.error("Failed to fetch moves: \(error.localizedDescription)")
                moves = []
            }

            isLoading = false
        }
    }

    // MARK: - Card Actions

    func revealCard() {
        guard !isCardRevealed else { return }

        isCardRevealed = true
        HapticFeedback.selectionHaptic()
    }

    func rateCard(_ rating: RecallRating) {
        guard let move = currentMove else { return }

        // Get current SR state
        let currentState = getSpacedRepetitionState(for: move)

        // Calculate new state
        let newState = SM2Algorithm.calculateNextState(current: currentState, rating: rating)

        // Update move with new SR values
        updateMove(move, with: newState)

        // Update session stats
        sessionStats.cardsReviewed += 1
        if rating != .again {
            sessionStats.correctCount += 1
        } else {
            sessionStats.incorrectCount += 1
        }

        // Award XP
        let xpEarned = calculateXP(for: rating, newState: newState)
        sessionXPEarned += xpEarned

        // Record in learning progress
        LearningProgress.shared.recordReview(rating: rating)

        // Check for mastery
        if newState.phase == .mastered && currentState.phase != .mastered {
            LearningProgress.shared.recordMastery()
        }

        // Haptic feedback based on rating
        provideRatingFeedback(rating)

        // Move to next card
        moveToNextCard()

        logger.info("Rated move '\(move.name ?? "")' as \(rating.label), next review: \(newState.intervalDays) days")
    }

    func skipCard() {
        moveToNextCard()
    }

    // MARK: - Private Methods

    private func moveToNextCard() {
        isCardRevealed = false

        if currentIndex < moves.count - 1 {
            currentIndex += 1
        } else {
            completeSession()
        }
    }

    private func completeSession() {
        sessionStats.endTime = Date()
        isSessionComplete = true

        // Check for perfect session
        if sessionStats.accuracy >= 100.0 && sessionStats.cardsReviewed > 0 {
            LearningProgress.shared.recordPerfectSession()
        }

        // Save context
        saveContext()

        HapticFeedback.notificationHaptic(.success)
        logger.info("Session complete: \(self.sessionStats.cardsReviewed) cards, \(self.sessionStats.accuracy)% accuracy")
    }

    private func getSpacedRepetitionState(for move: Move) -> SpacedRepetitionState {
        // Build state from Move's CoreData properties
        return SpacedRepetitionState(
            repetitionCount: Int(move.repetitionCount),
            easeFactor: move.easeFactor > 0 ? move.easeFactor : SM2Algorithm.defaultEaseFactor,
            intervalDays: Int(move.intervalDays),
            nextReviewDate: move.nextReviewDate,
            lastReviewDate: move.lastReviewDate,
            totalReviews: Int(move.totalReviews),
            lapses: Int(move.lapses),
            phase: LearningPhase(rawValue: move.learningState ?? "NEW") ?? .new
        )
    }

    private func updateMove(_ move: Move, with state: SpacedRepetitionState) {
        move.repetitionCount = Int16(state.repetitionCount)
        move.easeFactor = state.easeFactor
        move.intervalDays = Int16(state.intervalDays)
        move.nextReviewDate = state.nextReviewDate
        move.lastReviewDate = state.lastReviewDate
        move.totalReviews = Int16(state.totalReviews)
        move.lapses = Int16(state.lapses)
        move.learningState = state.phase.learningState
    }

    private func calculateXP(for rating: RecallRating, newState: SpacedRepetitionState) -> Int {
        var xp = 10 // Base XP for reviewing

        switch rating {
        case .easy:
            xp += 15 // Bonus for easy recall
        case .good:
            xp += 5  // Small bonus
        case .hard:
            xp += 0  // No bonus
        case .again:
            xp += 0  // No bonus
        }

        // Mastery bonus
        if newState.phase == .mastered {
            xp += 50
        }

        return xp
    }

    private func provideRatingFeedback(_ rating: RecallRating) {
        switch rating {
        case .again:
            HapticFeedback.notificationHaptic(.warning)
        case .hard:
            HapticFeedback.impactHaptic(.light)
        case .good:
            HapticFeedback.impactHaptic(.medium)
        case .easy:
            HapticFeedback.notificationHaptic(.success)
        }
    }

    private func saveContext() {
        guard viewContext.hasChanges else { return }

        do {
            try viewContext.save()
            logger.info("Saved review session changes")
        } catch {
            logger.error("Failed to save context: \(error.localizedDescription)")
        }
    }

    // MARK: - Session Management

    func restartSession() {
        currentIndex = 0
        isCardRevealed = false
        isSessionComplete = false
        sessionStats = ReviewSessionStats()
        sessionStats.startTime = Date()
        sessionXPEarned = 0

        loadMoves()
    }

    func endSession() {
        if !isSessionComplete {
            sessionStats.endTime = Date()
            isSessionComplete = true
            saveContext()
        }
    }
}

// MARK: - Review Session Manager
/// Coordinates review scheduling across the app

@MainActor
final class ReviewSessionManager: ObservableObject {

    static let shared = ReviewSessionManager()

    @Published private(set) var dueCount: Int = 0
    @Published private(set) var newCount: Int = 0
    @Published private(set) var learningCount: Int = 0

    private let viewContext: NSManagedObjectContext
    private let logger = Logger(subsystem: "com.breakdex", category: "ReviewSession")

    private init() {
        self.viewContext = PersistenceController.shared.container.viewContext
    }

    func refreshCounts() {
        Task {
            await calculateDueCounts()
        }
    }

    private func calculateDueCounts() async {
        let now = Date()

        // Count due items
        let dueFetch: NSFetchRequest<Move> = Move.fetchRequest()
        dueFetch.predicate = NSPredicate(
            format: "nextReviewDate != nil AND nextReviewDate <= %@",
            now as NSDate
        )

        // Count new items
        let newFetch: NSFetchRequest<Move> = Move.fetchRequest()
        newFetch.predicate = NSPredicate(format: "learningState == %@", "NEW")

        // Count learning items
        let learningFetch: NSFetchRequest<Move> = Move.fetchRequest()
        learningFetch.predicate = NSPredicate(format: "learningState == %@", "LEARNING")

        do {
            dueCount = try viewContext.count(for: dueFetch)
            newCount = try viewContext.count(for: newFetch)
            learningCount = try viewContext.count(for: learningFetch)

            logger.info("Review counts - Due: \(self.dueCount), New: \(self.newCount), Learning: \(self.learningCount)")
        } catch {
            logger.error("Failed to calculate due counts: \(error.localizedDescription)")
        }
    }

    var totalDueForReview: Int {
        dueCount + newCount + learningCount
    }

    var hasItemsDue: Bool {
        totalDueForReview > 0
    }
}

// MARK: - Review Notification Manager
/// Handles review reminder notifications

final class ReviewNotificationManager {

    static let shared = ReviewNotificationManager()

    private init() {}

    func scheduleReviewReminder(at hour: Int = 20, minute: Int = 0) {
        let center = UNUserNotificationCenter.current()

        // Remove existing reminders
        center.removePendingNotificationRequests(withIdentifiers: ["daily-review-reminder"])

        // Create content
        let content = UNMutableNotificationContent()
        content.title = "Time to Practice!"
        content.body = "Keep your streak going - review your moves today."
        content.sound = .default

        // Create trigger for daily reminder
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        // Create request
        let request = UNNotificationRequest(
            identifier: "daily-review-reminder",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    func cancelReviewReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["daily-review-reminder"]
        )
    }
}

import UserNotifications
