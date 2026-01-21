import Foundation
import SwiftUI

// MARK: - Learning Progress
/// Tracks user's learning progress including XP, streaks, and achievements.
/// Implements game-like progression to encourage consistent practice.

@MainActor
final class LearningProgress: ObservableObject {

    // MARK: - Singleton

    static let shared = LearningProgress()

    // MARK: - Published Properties

    @Published private(set) var totalXP: Int = 0
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var longestStreak: Int = 0
    @Published private(set) var todayReviews: Int = 0
    @Published private(set) var lastReviewDate: Date?
    @Published private(set) var level: Int = 1
    @Published private(set) var achievements: [Achievement] = []

    // MARK: - Persistence Keys

    private let totalXPKey = "learningProgress.totalXP"
    private let currentStreakKey = "learningProgress.currentStreak"
    private let longestStreakKey = "learningProgress.longestStreak"
    private let todayReviewsKey = "learningProgress.todayReviews"
    private let lastReviewDateKey = "learningProgress.lastReviewDate"
    private let achievementsKey = "learningProgress.achievements"

    // MARK: - XP Rewards

    enum XPReward {
        case reviewCard           // +10 XP
        case rateEasy            // +25 XP (bonus for easy)
        case dailyGoalComplete   // +50 XP
        case streakBonus(Int)    // +10 XP × day
        case masterMove          // +100 XP
        case perfectSession      // +75 XP (100% accuracy)

        var amount: Int {
            switch self {
            case .reviewCard: return 10
            case .rateEasy: return 25
            case .dailyGoalComplete: return 50
            case .streakBonus(let days): return 10 * days
            case .masterMove: return 100
            case .perfectSession: return 75
            }
        }

        var description: String {
            switch self {
            case .reviewCard: return "Card Reviewed"
            case .rateEasy: return "Perfect Recall"
            case .dailyGoalComplete: return "Daily Goal"
            case .streakBonus(let days): return "\(days) Day Streak"
            case .masterMove: return "Move Mastered"
            case .perfectSession: return "Perfect Session"
            }
        }
    }

    // MARK: - Daily Goal

    static let dailyGoal: Int = 10 // Cards per day

    var dailyGoalProgress: Double {
        Double(todayReviews) / Double(Self.dailyGoal)
    }

    var isDailyGoalComplete: Bool {
        todayReviews >= Self.dailyGoal
    }

    // MARK: - Level System

    /// XP required for each level
    static func xpForLevel(_ level: Int) -> Int {
        // Exponential growth: Level 1 = 0, Level 2 = 100, Level 3 = 300, etc.
        return level <= 1 ? 0 : (level - 1) * 100 + xpForLevel(level - 1)
    }

    /// Current progress toward next level (0.0 - 1.0)
    var levelProgress: Double {
        let currentLevelXP = Self.xpForLevel(level)
        let nextLevelXP = Self.xpForLevel(level + 1)
        let xpIntoLevel = totalXP - currentLevelXP
        let xpNeeded = nextLevelXP - currentLevelXP
        return Double(xpIntoLevel) / Double(xpNeeded)
    }

    /// XP needed to reach next level
    var xpToNextLevel: Int {
        Self.xpForLevel(level + 1) - totalXP
    }

    // MARK: - Initialization

    private init() {
        loadFromStorage()
        checkAndResetDailyProgress()
    }

    // MARK: - XP Methods

    /// Award XP to the user
    func awardXP(_ reward: XPReward) {
        let amount = reward.amount
        totalXP += amount
        updateLevel()
        saveToStorage()

        // Haptic feedback
        HapticFeedback.notificationHaptic(.success)
    }

    /// Award XP for a review action
    func recordReview(rating: RecallRating) {
        todayReviews += 1

        // Base XP for reviewing
        awardXP(.reviewCard)

        // Bonus for Easy rating
        if rating == .easy {
            awardXP(.rateEasy)
        }

        // Check daily goal
        if todayReviews == Self.dailyGoal {
            awardXP(.dailyGoalComplete)
            checkDailyStreak()
        }

        lastReviewDate = Date()
        saveToStorage()
    }

    /// Award XP for mastering a move
    func recordMastery() {
        awardXP(.masterMove)
    }

    /// Award XP for a perfect session
    func recordPerfectSession() {
        awardXP(.perfectSession)
    }

    // MARK: - Streak Methods

    private func checkDailyStreak() {
        let calendar = Calendar.current

        if let lastDate = lastReviewDate {
            let daysSinceLastReview = calendar.dateComponents([.day], from: lastDate, to: Date()).day ?? 0

            if daysSinceLastReview <= 1 {
                // Continuing streak
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)

                // Award streak bonus
                awardXP(.streakBonus(currentStreak))
            } else if daysSinceLastReview > 1 {
                // Streak broken
                currentStreak = 1
            }
        } else {
            // First day
            currentStreak = 1
        }

        saveToStorage()
    }

    private func checkAndResetDailyProgress() {
        let calendar = Calendar.current

        if let lastDate = lastReviewDate {
            if !calendar.isDateInToday(lastDate) {
                // Reset daily reviews for new day
                todayReviews = 0

                // Check if streak should be reset
                let daysSinceLastReview = calendar.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
                if daysSinceLastReview > 1 {
                    currentStreak = 0
                }

                saveToStorage()
            }
        }
    }

    // MARK: - Level Methods

    private func updateLevel() {
        var newLevel = 1
        while totalXP >= Self.xpForLevel(newLevel + 1) {
            newLevel += 1
        }

        if newLevel > level {
            level = newLevel
            // Could trigger level up celebration here
            HapticFeedback.notificationHaptic(.success)
        }
    }

    // MARK: - Persistence

    private func saveToStorage() {
        UserDefaults.standard.set(totalXP, forKey: totalXPKey)
        UserDefaults.standard.set(currentStreak, forKey: currentStreakKey)
        UserDefaults.standard.set(longestStreak, forKey: longestStreakKey)
        UserDefaults.standard.set(todayReviews, forKey: todayReviewsKey)
        UserDefaults.standard.set(lastReviewDate, forKey: lastReviewDateKey)
    }

    private func loadFromStorage() {
        totalXP = UserDefaults.standard.integer(forKey: totalXPKey)
        currentStreak = UserDefaults.standard.integer(forKey: currentStreakKey)
        longestStreak = UserDefaults.standard.integer(forKey: longestStreakKey)
        todayReviews = UserDefaults.standard.integer(forKey: todayReviewsKey)
        lastReviewDate = UserDefaults.standard.object(forKey: lastReviewDateKey) as? Date

        updateLevel()
    }

    /// Reset all progress (for debugging/testing)
    func resetProgress() {
        totalXP = 0
        currentStreak = 0
        longestStreak = 0
        todayReviews = 0
        lastReviewDate = nil
        level = 1
        achievements = []
        saveToStorage()
    }
}

// MARK: - Achievement

struct Achievement: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    var isUnlocked: Bool
    var unlockedDate: Date?

    static let allAchievements: [Achievement] = [
        Achievement(
            id: "first_review",
            name: "First Steps",
            description: "Complete your first review",
            icon: "star.fill",
            isUnlocked: false
        ),
        Achievement(
            id: "streak_7",
            name: "Week Warrior",
            description: "Maintain a 7-day streak",
            icon: "flame.fill",
            isUnlocked: false
        ),
        Achievement(
            id: "streak_30",
            name: "Monthly Master",
            description: "Maintain a 30-day streak",
            icon: "crown.fill",
            isUnlocked: false
        ),
        Achievement(
            id: "mastery_5",
            name: "Move Master",
            description: "Master 5 moves",
            icon: "medal.fill",
            isUnlocked: false
        ),
        Achievement(
            id: "perfect_10",
            name: "Perfectionist",
            description: "Get 10 perfect sessions",
            icon: "sparkles",
            isUnlocked: false
        ),
        Achievement(
            id: "xp_1000",
            name: "XP Hunter",
            description: "Earn 1,000 XP",
            icon: "bolt.fill",
            isUnlocked: false
        ),
        Achievement(
            id: "level_10",
            name: "Dedicated Learner",
            description: "Reach level 10",
            icon: "graduationcap.fill",
            isUnlocked: false
        )
    ]
}

// MARK: - Progress Stats View Model

struct ProgressStats {
    let totalXP: Int
    let level: Int
    let levelProgress: Double
    let currentStreak: Int
    let longestStreak: Int
    let todayReviews: Int
    let dailyGoal: Int

    var dailyProgress: Double {
        min(1.0, Double(todayReviews) / Double(dailyGoal))
    }
}
