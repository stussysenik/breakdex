// Theme.swift — App-wide theme/appearance management
//
// Uses the @Observable macro (Observation framework, iOS 17+) instead of
// ObservableObject/Published. This gives automatic fine-grained tracking —
// SwiftUI only re-renders views that read the specific property that changed.
//
// The theme choice persists across app launches via UserDefaults.
// The app entry point injects this as an environment value via .environment(settings).

import SwiftUI

// MARK: - CategoryDefinition
// A user-definable category with a name and hex color.
// Stored as JSON in UserDefaults via AppSettings.
// Defaults: "MOVE" and "COMBO" — users can create custom ones.

struct CategoryDefinition: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String      // Display name (e.g. "MOVE", "COMBO", "POWER")
    var hexColor: String  // Hex color string (e.g. "#ff7eb6", "#2362a2")
    var isDefault: Bool   // Default categories can't be deleted (MOVE, COMBO)

    init(name: String, hexColor: String, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.hexColor = hexColor
        self.isDefault = isDefault
    }

    /// Resolved SwiftUI Color from the hex string.
    var color: Color {
        Color(hex: hexColor) ?? .accent
    }

    /// Default categories shipped with the app.
    static let defaults: [CategoryDefinition] = [
        CategoryDefinition(name: "MOVE", hexColor: "#2362a2", isDefault: true),
        CategoryDefinition(name: "COMBO", hexColor: "#8a3ffc", isDefault: true),
    ]
}

// Color hex conversion (init?(hex:) and toHex()) lives in DesignSystem.swift

@Observable
class AppSettings {
    // MARK: - Theme Options
    // CaseIterable: allows ForEach iteration in the settings picker.
    // Identifiable: required for SwiftUI List/Picker identification.
    // rawValue String: stored directly in UserDefaults for persistence.
    enum ThemeChoice: String, CaseIterable, Identifiable {
        case system, dark, light

        var id: String { rawValue }

        // Human-readable label shown in the Settings picker
        var displayName: String {
            switch self {
            case .system: "System"   // Follows iOS system dark/light mode
            case .dark: "Dark"       // Force dark mode
            case .light: "Light"     // Force light mode
            }
        }
    }

    // When the user picks a theme, didSet immediately writes to UserDefaults.
    // This means the preference survives app restarts without any extra save logic.
    var selectedTheme: ThemeChoice {
        didSet { UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme") }
    }

    // MARK: - Categories
    // User-definable categories with colors. Persisted as JSON in UserDefaults.
    // Default categories: MOVE (accent blue) and COMBO (purple).
    var categories: [CategoryDefinition] {
        didSet { saveCategories() }
    }

    // MARK: - State Colors
    // Customizable colors for learning state pills (NEW, LEARNING, MASTERED).
    // Stored as hex strings in UserDefaults. The actual Color resolution happens
    // in DesignSystem.swift (Color.stateNew etc.) which reads these keys directly.
    var stateNewHex: String {
        didSet { UserDefaults.standard.set(stateNewHex, forKey: "stateNewHex") }
    }
    var stateLearningHex: String {
        didSet { UserDefaults.standard.set(stateLearningHex, forKey: "stateLearningHex") }
    }
    var stateMasteryHex: String {
        didSet { UserDefaults.standard.set(stateMasteryHex, forKey: "stateMasteryHex") }
    }

    // Computed property that the app entry point uses with .preferredColorScheme().
    // Returns nil for .system (which means "don't override — use whatever iOS says").
    var colorScheme: ColorScheme? {
        switch selectedTheme {
        case .system: nil       // nil = respect system setting
        case .dark: .dark
        case .light: .light
        }
    }

    // On init, read stored preferences from UserDefaults.
    init() {
        let stored = UserDefaults.standard.string(forKey: "selectedTheme") ?? "system"
        self.selectedTheme = ThemeChoice(rawValue: stored) ?? .system

        // Load categories from UserDefaults, falling back to defaults
        if let data = UserDefaults.standard.data(forKey: "categories"),
           let decoded = try? JSONDecoder().decode([CategoryDefinition].self, from: data) {
            self.categories = decoded
        } else {
            self.categories = CategoryDefinition.defaults
        }

        // Load state colors — defaults: pink, IBM cyan (#33b1ff), purple
        self.stateNewHex = UserDefaults.standard.string(forKey: "stateNewHex") ?? "#ff7eb6"
        self.stateLearningHex = UserDefaults.standard.string(forKey: "stateLearningHex") ?? "#33b1ff"
        self.stateMasteryHex = UserDefaults.standard.string(forKey: "stateMasteryHex") ?? "#8a3ffc"
    }

    // MARK: - Category Helpers

    /// Look up a category by name (case-insensitive).
    func category(named name: String) -> CategoryDefinition? {
        categories.first { $0.name.uppercased() == name.uppercased() }
    }

    /// Get the color for a category name, falling back to accent.
    func categoryColor(for name: String?) -> Color {
        guard let name else { return .accent }
        return category(named: name)?.color ?? .accent
    }

    /// Add a new custom category.
    func addCategory(name: String, hexColor: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return }
        // Don't add duplicates
        guard !categories.contains(where: { $0.name.uppercased() == trimmed }) else { return }
        categories.append(CategoryDefinition(name: trimmed, hexColor: hexColor))
    }

    /// Remove a category by ID (only non-default categories).
    func removeCategory(id: UUID) {
        categories.removeAll { $0.id == id && !$0.isDefault }
    }

    private func saveCategories() {
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: "categories")
        }
    }
}
