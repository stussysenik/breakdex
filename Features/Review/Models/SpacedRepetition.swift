import Foundation

// MARK: - SM-2 Spaced Repetition Algorithm
/// Implementation of the SuperMemo SM-2 algorithm for optimal learning intervals.
/// This algorithm adjusts review intervals based on how well you remembered the item.
///
/// Reference: https://www.supermemo.com/en/archives1990-2015/english/ol/sm2

// MARK: - Rating

/// User's self-assessed quality of recall
enum RecallRating: Int, CaseIterable, Identifiable {
    case again = 0      // Complete blackout - restart from beginning
    case hard = 1       // Significant difficulty - shorter interval
    case good = 2       // Correct with some hesitation
    case easy = 3       // Perfect recall - extend interval

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .again: return "Again"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }

    var description: String {
        switch self {
        case .again: return "I forgot completely"
        case .hard: return "Recalled with difficulty"
        case .good: return "Recalled correctly"
        case .easy: return "Perfect, too easy!"
        }
    }

    var sfSymbol: String {
        switch self {
        case .again: return "xmark.circle.fill"
        case .hard: return "exclamationmark.circle.fill"
        case .good: return "checkmark.circle.fill"
        case .easy: return "star.circle.fill"
        }
    }

    /// SM-2 quality rating (0-5 scale internally)
    var sm2Quality: Int {
        switch self {
        case .again: return 0
        case .hard: return 2
        case .good: return 3
        case .easy: return 5
        }
    }
}

// MARK: - Spaced Repetition State

/// Represents the learning state of an item
struct SpacedRepetitionState: Codable, Equatable {
    /// Number of consecutive correct responses
    var repetitionCount: Int = 0

    /// Ease factor (multiplier for interval calculation)
    /// Default is 2.5, minimum is 1.3
    var easeFactor: Double = 2.5

    /// Current interval in days
    var intervalDays: Int = 0

    /// Next scheduled review date
    var nextReviewDate: Date?

    /// Last review date
    var lastReviewDate: Date?

    /// Total number of reviews
    var totalReviews: Int = 0

    /// Number of times rated "Again"
    var lapses: Int = 0

    /// Current learning phase
    var phase: LearningPhase = .new

    // MARK: - Initialization

    init() {}

    init(
        repetitionCount: Int = 0,
        easeFactor: Double = 2.5,
        intervalDays: Int = 0,
        nextReviewDate: Date? = nil,
        lastReviewDate: Date? = nil,
        totalReviews: Int = 0,
        lapses: Int = 0,
        phase: LearningPhase = .new
    ) {
        self.repetitionCount = repetitionCount
        self.easeFactor = max(1.3, easeFactor)
        self.intervalDays = intervalDays
        self.nextReviewDate = nextReviewDate
        self.lastReviewDate = lastReviewDate
        self.totalReviews = totalReviews
        self.lapses = lapses
        self.phase = phase
    }

    /// Whether this item is due for review
    var isDue: Bool {
        guard let nextDate = nextReviewDate else { return true }
        return Date() >= nextDate
    }

    /// How overdue the item is (negative = not yet due)
    var daysOverdue: Int {
        guard let nextDate = nextReviewDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: nextDate, to: Date()).day ?? 0
    }
}

// MARK: - Learning Phase

enum LearningPhase: String, Codable {
    case new = "NEW"           // Never reviewed
    case learning = "LEARNING" // In initial learning (intervals < 1 day)
    case review = "REVIEW"     // Regular spaced repetition
    case mastered = "MASTERY"  // Well known (ease > 2.7, interval > 30 days)

    /// Maps to the app's learning state
    var learningState: String {
        rawValue
    }
}

// MARK: - SM-2 Algorithm

struct SM2Algorithm {

    /// Minimum ease factor
    static let minimumEaseFactor: Double = 1.3

    /// Maximum ease factor
    static let maximumEaseFactor: Double = 3.0

    /// Default ease factor for new items
    static let defaultEaseFactor: Double = 2.5

    /// Interval threshold for mastery (in days)
    static let masteryIntervalThreshold: Int = 30

    /// Ease threshold for mastery
    static let masteryEaseThreshold: Double = 2.7

    /// Calculate the next review state based on the user's rating
    /// - Parameters:
    ///   - currentState: The current spaced repetition state
    ///   - rating: The user's recall rating
    /// - Returns: Updated spaced repetition state
    static func calculateNextState(
        current: SpacedRepetitionState,
        rating: RecallRating
    ) -> SpacedRepetitionState {

        var newState = current
        newState.lastReviewDate = Date()
        newState.totalReviews += 1

        let quality = rating.sm2Quality

        // Handle failed reviews (Again)
        if quality < 3 {
            // Reset repetition count but keep ease factor
            newState.repetitionCount = 0
            newState.intervalDays = 1
            newState.lapses += 1
            newState.phase = .learning
        } else {
            // Successful review
            newState.repetitionCount += 1

            // Calculate new interval
            switch newState.repetitionCount {
            case 1:
                newState.intervalDays = 1
            case 2:
                newState.intervalDays = 6
            default:
                let newInterval = Double(current.intervalDays) * newState.easeFactor
                newState.intervalDays = Int(ceil(newInterval))
            }

            // Update ease factor using SM-2 formula
            let easeDelta = 0.1 - Double(5 - quality) * (0.08 + Double(5 - quality) * 0.02)
            newState.easeFactor = max(minimumEaseFactor, min(maximumEaseFactor, newState.easeFactor + easeDelta))

            // Determine phase
            if newState.intervalDays >= masteryIntervalThreshold &&
               newState.easeFactor >= masteryEaseThreshold {
                newState.phase = .mastered
            } else if newState.repetitionCount >= 2 {
                newState.phase = .review
            } else {
                newState.phase = .learning
            }
        }

        // Apply bonus/penalty for Easy/Hard
        switch rating {
        case .easy:
            // Easy bonus: increase interval by 50%
            newState.intervalDays = Int(Double(newState.intervalDays) * 1.5)
        case .hard:
            // Hard penalty: reduce interval by 20%
            newState.intervalDays = max(1, Int(Double(newState.intervalDays) * 0.8))
        default:
            break
        }

        // Calculate next review date
        newState.nextReviewDate = Calendar.current.date(
            byAdding: .day,
            value: newState.intervalDays,
            to: Date()
        )

        return newState
    }

    /// Get the preview of what the next interval would be for each rating
    /// - Parameter currentState: The current state
    /// - Returns: Dictionary mapping rating to interval description
    static func previewNextIntervals(for currentState: SpacedRepetitionState) -> [RecallRating: String] {
        var previews: [RecallRating: String] = [:]

        for rating in RecallRating.allCases {
            let nextState = calculateNextState(current: currentState, rating: rating)
            previews[rating] = formatInterval(nextState.intervalDays)
        }

        return previews
    }

    /// Format interval days into a human-readable string
    static func formatInterval(_ days: Int) -> String {
        switch days {
        case 0:
            return "Now"
        case 1:
            return "1 day"
        case 2...6:
            return "\(days) days"
        case 7...13:
            return "1 week"
        case 14...27:
            return "\(days / 7) weeks"
        case 28...59:
            return "1 month"
        case 60...89:
            return "2 months"
        default:
            return "\(days / 30) months"
        }
    }
}

// MARK: - Review Session Statistics

struct ReviewSessionStats {
    var totalCards: Int = 0
    var cardsReviewed: Int = 0
    var correctCount: Int = 0
    var incorrectCount: Int = 0
    var startTime: Date = Date()
    var endTime: Date?

    var accuracy: Double {
        guard cardsReviewed > 0 else { return 0 }
        return Double(correctCount) / Double(cardsReviewed) * 100
    }

    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var averageTimePerCard: TimeInterval {
        guard cardsReviewed > 0 else { return 0 }
        return duration / Double(cardsReviewed)
    }
}
