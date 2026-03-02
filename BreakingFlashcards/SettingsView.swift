import SwiftUI

struct SettingsView: View {

    @Environment(AppSettings.self) private var settings

    @State private var isAddingCategory = false
    @State private var newCategoryName = ""
    @State private var editorTarget: EditorTarget?

    private enum StateToken: String, CaseIterable, Identifiable {
        case new = "NEW"
        case learning = "LEARNING"
        case mastery = "MASTERY"

        var id: String { rawValue }

        var keyPath: ReferenceWritableKeyPath<AppSettings, String> {
            switch self {
            case .new: return \.stateNewHex
            case .learning: return \.stateLearningHex
            case .mastery: return \.stateMasteryHex
            }
        }
    }

    private enum EditorTarget: Identifiable {
        case state(StateToken)
        case category(UUID)

        var id: String {
            switch self {
            case .state(let token): return "state-\(token.id)"
            case .category(let id): return "category-\(id.uuidString)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                quickControlSection
                designTokensSection
                aboutSection
            }
            .listStyle(.plain)
            .navigationTitle("SETTINGS")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $editorTarget) { target in
            switch target {
            case .state(let token):
                stateEditor(for: token)
            case .category(let id):
                categoryEditor(id: id)
            }
        }
        .alert("New Category", isPresented: $isAddingCategory) {
            TextField("Category Name", text: $newCategoryName)
            Button("Cancel", role: .cancel) { newCategoryName = "" }
            Button("Create") {
                let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                if !name.isEmpty {
                    settings.addCategory(name: name, hexColor: Color.accent.toHex())
                }
                newCategoryName = ""
            }
        } message: {
            Text("Enter a name for the new category.")
        }
    }

    private var quickControlSection: some View {
        Section {
            ForEach(AppSettings.ThemeChoice.allCases) { choice in
                Button {
                    settings.selectedTheme = choice
                } label: {
                    HStack {
                        Text(choice.displayName)
                            .font(.ibmPlexMono(size: 14, weight: .medium))
                            .foregroundColor(.textPrimary)

                        Spacer()

                        if settings.selectedTheme == choice {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.accent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button("Apply IBM Baseline") {
                applyIBMBaseline()
            }
            .font(.ibmPlexMono(size: 13, weight: .bold))
            .foregroundColor(.accent)
        } header: {
            sectionHeader("QUICK CONTROL")
        }
    }

    private var designTokensSection: some View {
        Section {
            ForEach(StateToken.allCases) { token in
                Button {
                    editorTarget = .state(token)
                } label: {
                    settingsRow(
                        title: token.rawValue,
                        detail: settings[keyPath: token.keyPath],
                        accent: false
                    )
                }
                .buttonStyle(.plain)
            }

            Button {
                isAddingCategory = true
            } label: {
                settingsRow(
                    title: "+ NEW CATEGORY",
                    detail: "",
                    accent: true
                )
            }
            .buttonStyle(.plain)

            ForEach(settings.categories) { category in
                Button {
                    editorTarget = .category(category.id)
                } label: {
                    settingsRow(
                        title: category.name,
                        detail: category.hexColor,
                        accent: false
                    )
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                for index in offsets {
                    let category = settings.categories[index]
                    if !category.isDefault {
                        settings.removeCategory(id: category.id)
                    }
                }
            }
        } header: {
            sectionHeader("DESIGN TOKENS")
        }
    }

    private var aboutSection: some View {
        Section {
            infoRow(label: "Version", key: "CFBundleShortVersionString")
            infoRow(label: "Build", key: "CFBundleVersion")
        } header: {
            sectionHeader("ABOUT")
        }
    }

    private func stateEditor(for token: StateToken) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(token.rawValue)
                    .font(.ibmPlexMono(size: 16, weight: .bold))
                    .foregroundColor(.textPrimary)

                Text("Hex: \(settings[keyPath: token.keyPath])")
                    .font(.ibmPlexMono(size: 13))
                    .foregroundColor(.textSecondary)

                ColorPicker("Color", selection: stateColorBinding(for: token))
                    .font(.ibmPlexMono(size: 14))

                Spacer()
            }
            .padding(Spacing.screenEdge)
            .navigationTitle("STATE COLOR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { editorTarget = nil }
                }
            }
        }
    }

    private func categoryEditor(id: UUID) -> some View {
        NavigationStack {
            Group {
                if let idx = settings.categories.firstIndex(where: { $0.id == id }) {
                    let category = settings.categories[idx]

                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        Text(category.name)
                            .font(.ibmPlexMono(size: 16, weight: .bold))
                            .foregroundColor(.textPrimary)

                        Text("Hex: \(category.hexColor)")
                            .font(.ibmPlexMono(size: 13))
                            .foregroundColor(.textSecondary)

                        ColorPicker("Color", selection: categoryColorBinding(for: category.id))
                            .font(.ibmPlexMono(size: 14))

                        if !category.isDefault {
                            Button("Delete Category", role: .destructive) {
                                settings.removeCategory(id: category.id)
                                editorTarget = nil
                            }
                            .font(.ibmPlexMono(size: 13, weight: .bold))
                        }

                        Spacer()
                    }
                    .padding(Spacing.screenEdge)
                } else {
                    Text("Category not found")
                        .font(.ibmPlexMono(size: 14))
                        .foregroundColor(.textSecondary)
                        .padding(Spacing.screenEdge)
                }
            }
            .navigationTitle("CATEGORY")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { editorTarget = nil }
                }
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.ibmPlexMono(size: 11, weight: .bold))
            .foregroundColor(.textSecondary)
            .tracking(0.6)
    }

    private func settingsRow(title: String, detail: String, accent: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(title)
                .font(.ibmPlexMono(size: 14, weight: .medium))
                .foregroundColor(accent ? .accent : .textPrimary)

            Spacer()

            if !detail.isEmpty {
                Text(detail)
                    .font(.ibmPlexMono(size: 12))
                    .foregroundColor(.textSecondary)
            }

            if !accent {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
    }

    private func infoRow(label: String, key: String) -> some View {
        HStack {
            Text(label)
                .font(.ibmPlexMono(size: 13))
                .foregroundColor(.textPrimary)

            Spacer()

            Text(Bundle.main.infoDictionary?[key] as? String ?? "---")
                .font(.ibmPlexMono(size: 13, weight: .medium))
                .foregroundColor(.textSecondary)
        }
        .padding(.vertical, Spacing.xs)
    }

    private func stateColorBinding(for token: StateToken) -> Binding<Color> {
        let hex = stateHexBinding(token.keyPath)
        return hexColorBinding(hex)
    }

    private func stateHexBinding(_ keyPath: ReferenceWritableKeyPath<AppSettings, String>) -> Binding<String> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { settings[keyPath: keyPath] = $0 }
        )
    }

    private func categoryColorBinding(for id: UUID) -> Binding<Color> {
        Binding(
            get: { settings.categories.first(where: { $0.id == id })?.color ?? .accent },
            set: { newColor in
                if let idx = settings.categories.firstIndex(where: { $0.id == id }) {
                    settings.categories[idx].hexColor = newColor.toHex()
                }
            }
        )
    }

    private func hexColorBinding(_ hex: Binding<String>) -> Binding<Color> {
        Binding(
            get: { Color(hex: hex.wrappedValue) ?? .gray },
            set: { hex.wrappedValue = $0.toHex() }
        )
    }

    private func applyIBMBaseline() {
        settings.stateNewHex = "#ff7eb6"
        settings.stateLearningHex = "#33b1ff"
        settings.stateMasteryHex = "#8a3ffc"

        for idx in settings.categories.indices {
            if settings.categories[idx].name.uppercased() == "MOVE" {
                settings.categories[idx].hexColor = Color.accent.toHex()
            } else if settings.categories[idx].name.uppercased() == "COMBO" {
                settings.categories[idx].hexColor = "#8a3ffc"
            }
        }
    }
}

#Preview("Settings - Light") {
    SettingsView()
        .environment(AppSettings())
}

#Preview("Settings - Dark") {
    SettingsView()
        .environment(AppSettings())
        .preferredColorScheme(.dark)
}
