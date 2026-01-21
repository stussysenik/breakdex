import SwiftUI

/// A reusable empty state component that displays a consistent empty state across all screens.
///
/// Usage:
/// ```swift
/// EmptyStateView(
///     icon: "figure.dance",
///     title: "No Moves Yet",
///     description: "Add your first move to start building your arsenal.",
///     ctaTitle: "Add Move",
///     ctaAction: { /* navigate to add move */ }
/// )
/// ```
struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    var ctaTitle: String? = nil
    var ctaAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            // Icon
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(.textSecondary)
                .accessibilityHidden(true)

            // Text content
            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.titleSmall)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            // Optional CTA button
            if let ctaTitle = ctaTitle, let ctaAction = ctaAction {
                Button(action: ctaAction) {
                    Text(ctaTitle)
                        .font(.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .background(Color.accent)
                        .cornerRadius(AppLayout.mediumRadius)
                }
                .accessibilityLabel(ctaTitle)
                .padding(.top, Spacing.sm)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description)")
    }
}

// MARK: - Previews

#Preview("With CTA") {
    EmptyStateView(
        icon: "figure.dance",
        title: "No Moves Yet",
        description: "Add your first move to start building your arsenal.",
        ctaTitle: "Add Move",
        ctaAction: { print("Add move tapped") }
    )
}

#Preview("Without CTA") {
    EmptyStateView(
        icon: "square.stack.3d.up",
        title: "No Combos Yet",
        description: "Create combos by combining moves from your arsenal."
    )
}

#Preview("Dark Mode") {
    EmptyStateView(
        icon: "book.closed",
        title: "Nothing to Review",
        description: "Add some moves to start your practice sessions.",
        ctaTitle: "Browse Arsenal",
        ctaAction: {}
    )
    .preferredColorScheme(.dark)
}
