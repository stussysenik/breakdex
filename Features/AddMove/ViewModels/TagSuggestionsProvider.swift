import Foundation
import CoreData
import Combine
import OSLog

// MARK: - Tag Suggestions Provider
/// Provides tag suggestions based on existing tags in the database
/// and common breaking move categories

@MainActor
final class TagSuggestionsProvider: ObservableObject {

    // MARK: - Published Properties

    @Published var suggestions: [String] = []
    @Published var isLoading = false

    // MARK: - Properties

    private let viewContext: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🏷️ TAG_SUGGESTIONS")

    // MARK: - Common Breaking Tags

    /// Pre-defined breaking move categories
    static let commonTags: [String] = [
        // Movement types
        "Toprock",
        "Footwork",
        "Power Move",
        "Freeze",
        "Transition",

        // Difficulty levels
        "Foundation",
        "Intermediate",
        "Advanced",
        "Expert",

        // Categories
        "Tutorial",
        "Combo",
        "Battle",
        "Practice",
        "Cypher",

        // Specific moves (commonly used)
        "Six Step",
        "Three Step",
        "Windmill",
        "Flare",
        "Airflare",
        "Headspin",
        "Backspin",
        "1990",
        "2000",
        "Baby Freeze",
        "Chair Freeze",
        "Airchair",
        "Handstand",

        // Style
        "Style",
        "Musicality",
        "Flow",
        "Explosive",
        "Smooth"
    ]

    // MARK: - Initialization

    init(viewContext: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = viewContext
        loadAllTags()
    }

    // MARK: - Public Methods

    /// Fetches suggestions based on query text
    /// - Parameter query: The search query
    func fetchSuggestions(for query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmedQuery.isEmpty else {
            suggestions = []
            return
        }

        // Combine database tags with common tags
        var allTags = Set(Self.commonTags)

        // Add tags from database
        if let databaseTags = fetchTagsFromDatabase() {
            allTags.formUnion(databaseTags)
        }

        // Filter based on query
        suggestions = allTags
            .filter { $0.lowercased().contains(trimmedQuery) }
            .sorted()
            .prefix(10)
            .map { $0 }

        logger.debug("🏷️ Found \(self.suggestions.count) suggestions for query: '\(query)'")
    }

    /// Returns all available tags (database + common)
    func getAllTags() -> [String] {
        var allTags = Set(Self.commonTags)

        if let databaseTags = fetchTagsFromDatabase() {
            allTags.formUnion(databaseTags)
        }

        return allTags.sorted()
    }

    /// Fetches popular tags based on usage frequency
    func getPopularTags(limit: Int = 10) -> [String] {
        guard let databaseTags = fetchTagFrequencies() else {
            // Return common tags if no database tags
            return Array(Self.commonTags.prefix(limit))
        }

        // Sort by frequency and return top tags
        return databaseTags
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }

    // MARK: - Private Methods

    private func loadAllTags() {
        isLoading = true

        Task {
            // Pre-load database tags
            _ = fetchTagsFromDatabase()

            await MainActor.run {
                isLoading = false
            }
        }
    }

    /// Fetches unique tags from all moves in the database
    private func fetchTagsFromDatabase() -> Set<String>? {
        let fetchRequest: NSFetchRequest<Move> = Move.fetchRequest()
        fetchRequest.propertiesToFetch = ["tags"]

        do {
            let moves = try viewContext.fetch(fetchRequest)
            var allTags = Set<String>()

            for move in moves {
                if let tagsString = move.tags {
                    let tags = parseTags(from: tagsString)
                    allTags.formUnion(tags)
                }
            }

            logger.debug("🏷️ Fetched \(allTags.count) unique tags from database")
            return allTags

        } catch {
            logger.error("🏷️ Failed to fetch tags from database: \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetches tag frequencies for popularity ranking
    private func fetchTagFrequencies() -> [String: Int]? {
        let fetchRequest: NSFetchRequest<Move> = Move.fetchRequest()
        fetchRequest.propertiesToFetch = ["tags"]

        do {
            let moves = try viewContext.fetch(fetchRequest)
            var frequencies: [String: Int] = [:]

            for move in moves {
                if let tagsString = move.tags {
                    let tags = parseTags(from: tagsString)
                    for tag in tags {
                        frequencies[tag, default: 0] += 1
                    }
                }
            }

            return frequencies

        } catch {
            logger.error("🏷️ Failed to fetch tag frequencies: \(error.localizedDescription)")
            return nil
        }
    }

    /// Parses a comma-separated tag string into an array
    private func parseTags(from string: String) -> [String] {
        return string
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Tag Validation

extension TagSuggestionsProvider {

    /// Validates a tag name
    /// - Parameter tag: The tag to validate
    /// - Returns: Validation result
    static func validateTag(_ tag: String) -> TagValidationResult {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return .invalid(reason: "Tag cannot be empty")
        }

        if trimmed.count < 2 {
            return .invalid(reason: "Tag must be at least 2 characters")
        }

        if trimmed.count > 30 {
            return .invalid(reason: "Tag must be less than 30 characters")
        }

        // Check for invalid characters
        let validCharacters = CharacterSet.alphanumerics.union(.whitespaces)
        if trimmed.unicodeScalars.contains(where: { !validCharacters.contains($0) }) {
            return .invalid(reason: "Tag can only contain letters, numbers, and spaces")
        }

        return .valid
    }
}

// MARK: - Tag Validation Result

enum TagValidationResult {
    case valid
    case invalid(reason: String)

    var isValid: Bool {
        switch self {
        case .valid: return true
        case .invalid: return false
        }
    }

    var errorMessage: String? {
        switch self {
        case .valid: return nil
        case .invalid(let reason): return reason
        }
    }
}
