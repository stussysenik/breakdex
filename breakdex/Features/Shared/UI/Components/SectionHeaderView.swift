import SwiftUI

/// A reusable section header component with title, optional count badge, and optional trailing action.
///
/// Usage:
/// ```swift
/// SectionHeaderView(title: "MOVES", count: 12)
///
/// SectionHeaderView(
///     title: "COMBOS",
///     count: 5,
///     trailingAction: { /* action */ },
///     trailingIcon: "plus"
/// )
/// ```
struct SectionHeaderView: View {
    let title: String
    var count: Int? = nil
    var trailingAction: (() -> Void)? = nil
    var trailingIcon: String? = nil

    var body: some View {
        HStack(alignment: .center) {
            // Title
            Text(title)
                .font(.titleSmall)
                .foregroundColor(.textPrimary)

            // Optional count badge
            if let count = count {
                Text("(\(count))")
                    .font(.bodySmall)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            // Optional trailing action
            if let action = trailingAction, let icon = trailingIcon {
                Button(action: action) {
                    Image(systemName: icon)
                        .font(.bodyMedium)
                        .foregroundColor(.accent)
                        .frame(width: 44, height: 44) // Minimum touch target
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("\(title) action")
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(count != nil ? "\(title), \(count!) items" : title)
    }
}

// MARK: - Previews

#Preview("With Count") {
    VStack {
        SectionHeaderView(title: "MOVES", count: 12)
        SectionHeaderView(title: "COMBOS", count: 5)
    }
}

#Preview("With Action") {
    SectionHeaderView(
        title: "MOVES",
        count: 12,
        trailingAction: { print("Action tapped") },
        trailingIcon: "plus.circle"
    )
}

#Preview("Without Count") {
    SectionHeaderView(title: "RECENT")
}

#Preview("Dark Mode") {
    VStack {
        SectionHeaderView(title: "MOVES", count: 12)
        SectionHeaderView(title: "COMBOS", count: 5)
    }
    .preferredColorScheme(.dark)
}
