//
//  ThemeManager.swift
//  breakdex
//
//  Created for light/dark theme toggle functionality
//

import SwiftUI
import OSLog

// MARK: - Theme Manager
/// Observable object for managing app-wide theme (light/dark mode)
/// Uses @AppStorage for persistence across app launches
@MainActor
public final class ThemeManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = ThemeManager()
    
    // MARK: - Properties
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🎨 THEME")
    
    /// Persisted theme preference - true = dark mode, false = light mode
    @AppStorage("isDarkMode") public var isDarkMode: Bool = true {
        didSet {
            logger.info("🎨 THEME: Mode changed to \(self.isDarkMode ? "DARK" : "LIGHT")")
        }
    }
    
    // MARK: - Computed Properties
    
    /// Returns the ColorScheme for SwiftUI's preferredColorScheme modifier
    public var colorScheme: ColorScheme {
        isDarkMode ? .dark : .light
    }
    
    // MARK: - Initialization
    private init() {
        logger.info("🎨 THEME: ThemeManager initialized with mode: \(self.isDarkMode ? "DARK" : "LIGHT")")
    }
    
    // MARK: - Methods
    
    /// Toggle between light and dark mode
    public func toggleTheme() {
        isDarkMode.toggle()
        
        // Haptic feedback for mode change
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        logger.info("🎨 THEME: Toggled to \(isDarkMode ? "DARK" : "LIGHT") mode")
    }
    
    /// Set theme explicitly
    public func setTheme(isDark: Bool) {
        guard isDarkMode != isDark else { return }
        isDarkMode = isDark
    }
}

// MARK: - Theme Toggle Button
/// A simple button to toggle between light and dark mode
public struct ThemeToggleButton: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    public init() {}
    
    public var body: some View {
        Button(action: {
            themeManager.toggleTheme()
        }) {
            Image(systemName: themeManager.isDarkMode ? "sun.max.fill" : "moon.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.textPrimary)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(themeManager.isDarkMode ? "Switch to light mode" : "Switch to dark mode")
    }
}

// MARK: - Preview
#Preview("Theme Toggle Button") {
    VStack(spacing: 30) {
        ThemeToggleButton()
        
        Text("Toggle the button to switch themes")
            .font(.ibmPlexMono(size: 14))
            .foregroundColor(.textSecondary)
    }
    .padding(40)
    .background(Color.backgroundPrimary)
}
