// SettingsView.swift — User preferences and app information
//
// This view provides two settings sections:
//   1. Appearance — theme picker (System / Dark / Light)
//   2. About — app version and build number
//
// ARCHITECTURE ROLE:
// SettingsView reads and writes the app's theme preference through AppSettings,
// which is injected into the SwiftUI environment by BreakingFlashcardsApp.
// When the user changes the theme, AppSettings.selectedTheme fires didSet
// which persists the choice to UserDefaults AND triggers
// .preferredColorScheme() at the app root to update the entire UI.
//
// DATA FLOW:
//   SettingsView reads AppSettings from @Environment
//   -> User picks a theme in the Picker
//   -> $settings.selectedTheme binding writes to AppSettings.selectedTheme
//   -> didSet on selectedTheme saves to UserDefaults (persistence)
//   -> @Observable notifies SwiftUI of the change
//   -> BreakingFlashcardsApp re-evaluates settings.colorScheme
//   -> .preferredColorScheme() applies the new theme globally
//
// SWIFTUI PATTERNS:
// - @Environment(AppSettings.self): Reads the AppSettings instance from the
//   environment. This is the Observation-framework syntax (iOS 17+). Unlike
//   @EnvironmentObject (which requires ObservableObject conformance), this works
//   with @Observable classes directly.
//
// - @Bindable: Required to create two-way bindings ($settings.selectedTheme) from
//   an @Observable object. Without @Bindable, you can only read properties — you
//   can't use $ prefix to get a Binding. The local `@Bindable var settings = settings`
//   inside the body is a workaround because @Environment properties can't be
//   directly marked @Bindable at the property declaration level.
//
// - Bundle.main.infoDictionary: The Info.plist dictionary compiled into the app bundle.
//   CFBundleShortVersionString = marketing version (e.g. "1.0")
//   CFBundleVersion = build number (e.g. "42")

import SwiftUI

/// Settings screen: theme, categories, state colors, and app info.
struct SettingsView: View {

    @Environment(AppSettings.self) private var settings

    @State private var isAddingCategory = false
    @State private var newCatName = ""

    // Color presets from shared CategoryPalette (DesignSystem.swift)

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            List {
                // SECTION: Appearance
                Section("Appearance") {
                    Picker("Theme", selection: $settings.selectedTheme) {
                        ForEach(AppSettings.ThemeChoice.allCases) { choice in
                            Text(choice.displayName).tag(choice)
                        }
                    }
                    .font(.ibmPlexMono(size: 16))
                }

                // SECTION: Categories
                // 18% bigger text: base 16pt * 1.18 ≈ 19pt
                Section("Categories") {
                    ForEach(settings.categories) { cat in
                        HStack(spacing: Spacing.sm) {
                            Circle()
                                .fill(cat.color)
                                .frame(width: 14, height: 14)

                            Text(cat.name)
                                .font(.ibmPlexMono(size: 19, weight: .medium))

                            Spacer()

                            if cat.isDefault {
                                Text("Default")
                                    .font(.ibmPlexMono(size: 13))
                                    .foregroundColor(.textSecondary)
                            }

                            // Color picker — inline for each category
                            ColorPicker("", selection: categoryColorBinding(for: cat.id))
                                .labelsHidden()
                                .frame(width: 30)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let cat = settings.categories[index]
                            if !cat.isDefault {
                                settings.removeCategory(id: cat.id)
                            }
                        }
                    }

                    Button {
                        isAddingCategory = true
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accent)
                            Text("Add Category")
                                .font(.ibmPlexMono(size: 19, weight: .medium))
                        }
                    }
                }

                // SECTION: State Colors
                Section("Learning State Colors") {
                    stateColorRow(label: "NEW", hexBinding: $settings.stateNewHex)
                    stateColorRow(label: "LEARNING", hexBinding: $settings.stateLearningHex)
                    stateColorRow(label: "MASTERED", hexBinding: $settings.stateMasteryHex)
                }

                // SECTION: About
                Section("About") {
                    infoRow(label: "Version", key: "CFBundleShortVersionString")
                    infoRow(label: "Build", key: "CFBundleVersion")
                }
            }
            .navigationTitle("SETTINGS")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("New Category", isPresented: $isAddingCategory) {
            TextField("Category Name", text: $newCatName)
            Button("Cancel", role: .cancel) { newCatName = "" }
            Button("Create") {
                let name = newCatName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                if !name.isEmpty {
                    settings.addCategory(name: name, hexColor: "#2362a2")
                }
                newCatName = ""
            }
        } message: {
            Text("Enter a name for the new category.")
        }
    }

    // MARK: - Helpers

    /// Creates a Color binding that reads/writes a category's hexColor by ID.
    private func categoryColorBinding(for id: UUID) -> Binding<Color> {
        Binding(
            get: {
                settings.categories.first(where: { $0.id == id })?.color ?? .accent
            },
            set: { newColor in
                if let idx = settings.categories.firstIndex(where: { $0.id == id }) {
                    settings.categories[idx].hexColor = newColor.toHex()
                }
            }
        )
    }

    /// A row with a learning state label and color picker.
    private func stateColorRow(label: String, hexBinding: Binding<String>) -> some View {
        HStack {
            Circle()
                .fill(Color(hex: hexBinding.wrappedValue) ?? .gray)
                .frame(width: 14, height: 14)

            Text(label)
                .font(.ibmPlexMono(size: 19, weight: .medium))

            Spacer()

            ColorPicker("", selection: hexColorBinding(hexBinding))
                .labelsHidden()
                .frame(width: 30)
        }
    }

    /// Bridges a hex String binding to a Color binding for ColorPicker.
    private func hexColorBinding(_ hex: Binding<String>) -> Binding<Color> {
        Binding(
            get: { Color(hex: hex.wrappedValue) ?? .gray },
            set: { hex.wrappedValue = $0.toHex() }
        )
    }

    /// A simple info row for the About section.
    private func infoRow(label: String, key: String) -> some View {
        HStack {
            Text(label)
                .font(.ibmPlexMono(size: 16))
            Spacer()
            Text(Bundle.main.infoDictionary?[key] as? String ?? "---")
                .font(.ibmPlexMono(size: 16))
                .foregroundColor(.textSecondary)
        }
    }
}

// Color.toHex() and Color(hex:) live in DesignSystem.swift

#Preview("Settings - Light") {
    SettingsView()
        .environment(AppSettings())
}

#Preview("Settings - Dark") {
    SettingsView()
        .environment(AppSettings())
        .preferredColorScheme(.dark)
}
