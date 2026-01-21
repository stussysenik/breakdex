import SwiftUI
import Combine

// MARK: - Tag Input Field
/// A complete tag input component with:
/// - Flow layout for existing tags
/// - Text field for adding new tags
/// - Autocomplete suggestions from database + common tags
/// - Spring animations for add/remove

struct TagInputField: View {

    // MARK: - Properties

    @Binding var tags: [String]
    var placeholder: String = "Add tags..."
    var maxTags: Int = 10

    @StateObject private var suggestions = TagSuggestionsProvider()
    @State private var inputText = ""
    @State private var isFocused = false
    @FocusState private var textFieldFocused: Bool

    @ObservedObject private var accessibility = AccessibilityManager.shared

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Label
            Text("Tags")
                .font(.ibmPlexMono(size: 14, weight: .medium))
                .foregroundColor(.textSecondary)

            // Existing tags flow layout
            if !tags.isEmpty {
                existingTagsSection
            }

            // Input field
            inputFieldSection

            // Suggestions
            if !inputText.isEmpty || textFieldFocused {
                suggestionsSection
            }
        }
        .onChange(of: inputText) { _, newValue in
            suggestions.fetchSuggestions(for: newValue)
        }
    }

    // MARK: - Existing Tags Section

    @ViewBuilder
    private var existingTagsSection: some View {
        SimpleFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(tags, id: \.self) { tag in
                TagChipView(tag: tag) {
                    removeTag(tag)
                }
                .transition(.springScale)
            }
        }
        .animation(accessibility.effectiveAnimation, value: tags)
    }

    // MARK: - Input Field Section

    @ViewBuilder
    private var inputFieldSection: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "tag")
                .foregroundColor(.textSecondary)
                .font(.system(size: 14))

            TextField(placeholder, text: $inputText)
                .font(.ibmPlexMono(size: 14))
                .foregroundColor(.textPrimary)
                .focused($textFieldFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .onSubmit {
                    addCurrentTag()
                }
                .onChange(of: textFieldFocused) { _, focused in
                    withAnimation(MotionSystem.micro) {
                        isFocused = focused
                    }
                }

            // Clear button
            if !inputText.isEmpty {
                Button {
                    inputText = ""
                    HapticFeedback.selectionHaptic()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textSecondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.smallRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.smallRadius)
                .stroke(isFocused ? Color.accent : Color.clear, lineWidth: 1.5)
        )
        .animation(MotionSystem.micro, value: isFocused)
    }

    // MARK: - Suggestions Section

    @ViewBuilder
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Show "Create new tag" option if query doesn't match existing tags
            if shouldShowCreateOption {
                NewTagChipView(tagName: inputText.capitalized) {
                    addTag(inputText.capitalized)
                }
            }

            // Existing suggestions
            if !suggestions.suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filteredSuggestions, id: \.self) { suggestion in
                            SuggestedTagChipView(tag: suggestion) {
                                addTag(suggestion)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            // Popular tags when no query
            if inputText.isEmpty && textFieldFocused {
                popularTagsSection
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(accessibility.effectiveAnimation, value: inputText)
        .animation(accessibility.effectiveAnimation, value: textFieldFocused)
    }

    // MARK: - Popular Tags Section

    @ViewBuilder
    private var popularTagsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Popular")
                .font(.ibmPlexMono(size: 11, weight: .medium))
                .foregroundColor(.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions.getPopularTags(limit: 8), id: \.self) { tag in
                        if !tags.contains(tag) {
                            SuggestedTagChipView(tag: tag) {
                                addTag(tag)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredSuggestions: [String] {
        // Filter out already selected tags
        suggestions.suggestions.filter { !tags.contains($0) }
    }

    private var shouldShowCreateOption: Bool {
        guard !inputText.isEmpty else { return false }

        let normalizedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Check if input exactly matches any existing suggestion
        let exactMatch = suggestions.suggestions.contains { $0.lowercased() == normalizedInput }

        // Check if input exactly matches any already selected tag
        let alreadySelected = tags.contains { $0.lowercased() == normalizedInput }

        // Validate the tag
        let validation = TagSuggestionsProvider.validateTag(inputText)

        return !exactMatch && !alreadySelected && validation.isValid
    }

    private var canAddMoreTags: Bool {
        tags.count < maxTags
    }

    // MARK: - Actions

    private func addCurrentTag() {
        let tag = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tag.isEmpty {
            addTag(tag.capitalized)
        }
    }

    private func addTag(_ tag: String) {
        guard canAddMoreTags else {
            HapticFeedback.notificationHaptic(.warning)
            return
        }

        let normalizedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedTag.isEmpty else { return }
        guard !tags.contains(normalizedTag) else { return }

        let validation = TagSuggestionsProvider.validateTag(normalizedTag)
        guard validation.isValid else {
            HapticFeedback.notificationHaptic(.error)
            return
        }

        withAnimation(accessibility.effectiveAnimation) {
            tags.append(normalizedTag)
        }

        inputText = ""
        HapticFeedback.actionHaptic()
    }

    private func removeTag(_ tag: String) {
        withAnimation(accessibility.effectiveAnimation) {
            tags.removeAll { $0 == tag }
        }
        HapticFeedback.actionHaptic()
    }
}

// MARK: - Compact Tag Input
/// A more compact version for inline use

struct CompactTagInput: View {

    @Binding var tags: [String]
    var maxTags: Int = 5

    @State private var showFullInput = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Preview of tags
            HStack {
                if tags.isEmpty {
                    Text("No tags")
                        .font(.ibmPlexMono(size: 13))
                        .foregroundColor(.textSecondary)
                } else {
                    Text(tags.joined(separator: " • "))
                        .font(.ibmPlexMono(size: 13))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    showFullInput = true
                    HapticFeedback.selectionHaptic()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(.accent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.smallRadius))
        }
        .sheet(isPresented: $showFullInput) {
            TagInputSheet(tags: $tags, maxTags: maxTags)
        }
    }
}

// MARK: - Tag Input Sheet

struct TagInputSheet: View {

    @Binding var tags: [String]
    var maxTags: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                TagInputField(tags: $tags, maxTags: maxTags)
                    .padding()
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("Edit Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.ibmPlexMono(size: 16, weight: .medium))
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#if DEBUG
struct TagInputField_Previews: PreviewProvider {
    static var previews: some View {
        TagInputDemoView()
    }
}

struct TagInputDemoView: View {
    @State private var tags: [String] = ["Footwork", "Foundation"]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Text("Tag Input Demo")
                    .font(.ibmPlexMono(size: 20, weight: .bold))

                // Full tag input
                TagInputField(tags: $tags)
                    .padding(.horizontal)

                Divider()

                // Compact version
                VStack(alignment: .leading, spacing: 8) {
                    Text("Compact Version")
                        .font(.ibmPlexMono(size: 14, weight: .medium))

                    CompactTagInput(tags: $tags)
                }
                .padding(.horizontal)

                Divider()

                // Current tags display
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Tags: \(tags.count)")
                        .font(.ibmPlexMono(size: 14, weight: .medium))

                    ForEach(tags, id: \.self) { tag in
                        Text("• \(tag)")
                            .font(.ibmPlexMono(size: 12))
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.backgroundPrimary)
    }
}
#endif
