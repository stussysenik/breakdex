import SwiftUI

/// A view modifier that applies consistent card styling to any view.
///
/// Usage:
/// ```swift
/// VStack {
///     Text("Card content")
/// }
/// .cardContainer()
///
/// // Or with custom padding:
/// content.cardContainer(padding: Spacing.lg)
/// ```
struct CardContainerModifier: ViewModifier {
    var padding: CGFloat = Spacing.md
    var cornerRadius: CGFloat = AppLayout.mediumRadius

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.backgroundSecondary)
            .cornerRadius(cornerRadius)
    }
}

extension View {
    /// Applies consistent card container styling with background, padding, and corner radius.
    /// - Parameters:
    ///   - padding: Internal padding. Defaults to `Spacing.md` (16pt).
    ///   - cornerRadius: Corner radius. Defaults to `AppLayout.mediumRadius` (12pt).
    /// - Returns: A view with card styling applied.
    func cardContainer(
        padding: CGFloat = Spacing.md,
        cornerRadius: CGFloat = AppLayout.mediumRadius
    ) -> some View {
        modifier(CardContainerModifier(padding: padding, cornerRadius: cornerRadius))
    }
}

/// A standalone card container view that wraps content with consistent styling.
///
/// Usage:
/// ```swift
/// CardContainer {
///     HStack {
///         Text("Card content")
///         Spacer()
///         Image(systemName: "chevron.right")
///     }
/// }
/// ```
struct CardContainer<Content: View>: View {
    var padding: CGFloat = Spacing.md
    var cornerRadius: CGFloat = AppLayout.mediumRadius
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background(Color.backgroundSecondary)
            .cornerRadius(cornerRadius)
    }
}

// MARK: - Previews

#Preview("Card Modifier") {
    VStack(spacing: Spacing.md) {
        HStack {
            Text("NEW")
                .font(.bodyMedium)
            Spacer()
            Text("(5)")
                .font(.bodySmall)
                .foregroundColor(.textSecondary)
        }
        .cardContainer()

        HStack {
            Text("LEARNING")
                .font(.bodyMedium)
            Spacer()
            Text("(3)")
                .font(.bodySmall)
                .foregroundColor(.textSecondary)
        }
        .cardContainer()
    }
    .padding()
}

#Preview("Card Container View") {
    VStack(spacing: Spacing.md) {
        CardContainer {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Move Name")
                        .font(.bodyMedium)
                    Text("Added 2 days ago")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.textSecondary)
            }
        }
    }
    .padding()
}

#Preview("Dark Mode") {
    VStack(spacing: Spacing.md) {
        HStack {
            Text("Card in Dark Mode")
            Spacer()
        }
        .cardContainer()
    }
    .padding()
    .preferredColorScheme(.dark)
}
