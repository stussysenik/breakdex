import SwiftUI

// MARK: - Tag Chip View
/// Individual tag chip with remove button
/// Supports accessibility and motion system animations

struct TagChipView: View {

    // MARK: - Properties

    let tag: String
    var isRemovable: Bool = true
    var onRemove: (() -> Void)?
    var onTap: (() -> Void)?

    @State private var isPressed = false
    @ObservedObject private var accessibility = AccessibilityManager.shared

    // MARK: - Body

    var body: some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.ibmPlexMono(size: 13, weight: .medium))
                .foregroundColor(.textPrimary)

            if isRemovable, onRemove != nil {
                Button {
                    onRemove?()
                    HapticFeedback.actionHaptic()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .background(Color.textSecondary.opacity(0.2))
                .clipShape(Circle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tagBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.textSecondary.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(accessibility.effectiveMicroAnimation, value: isPressed)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tag: \(tag)")
        .accessibilityHint(isRemovable ? "Double tap to remove" : "")
        .accessibilityAddTraits(.isButton)
        .contentShape(Capsule())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in
                    isPressed = false
                    onTap?()
                }
        )
    }

    // MARK: - Background

    private var tagBackground: some View {
        Color.backgroundSecondary
    }
}

// MARK: - Suggested Tag Chip
/// Tag chip style for autocomplete suggestions

struct SuggestedTagChipView: View {

    let tag: String
    var onSelect: (() -> Void)?

    @State private var isPressed = false
    @ObservedObject private var accessibility = AccessibilityManager.shared

    var body: some View {
        Button {
            onSelect?()
            HapticFeedback.selectionHaptic()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                Text(tag)
                    .font(.ibmPlexMono(size: 12, weight: .medium))
            }
            .foregroundColor(.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accent.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(accessibility.effectiveMicroAnimation, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel("Add tag: \(tag)")
        .accessibilityHint("Double tap to add this tag")
    }
}

// MARK: - New Tag Chip
/// Chip for creating a new tag that doesn't exist yet

struct NewTagChipView: View {

    let tagName: String
    var onCreateTag: (() -> Void)?

    @State private var isPressed = false

    var body: some View {
        Button {
            onCreateTag?()
            HapticFeedback.actionHaptic()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                Text("Create \"\(tagName)\"")
                    .font(.ibmPlexMono(size: 12, weight: .medium))
            }
            .foregroundColor(.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accent, style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(MotionSystem.micro, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel("Create new tag: \(tagName)")
        .accessibilityHint("Double tap to create this new tag")
    }
}

// MARK: - Preview

#if DEBUG
struct TagChipView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Tag Chips")
                .font(.ibmPlexMono(size: 20, weight: .bold))

            // Regular tags
            HStack(spacing: 8) {
                TagChipView(tag: "Footwork") {
                    print("Remove footwork")
                }

                TagChipView(tag: "Power Move", isRemovable: false)

                TagChipView(tag: "Foundation") {
                    print("Remove foundation")
                }
            }

            Divider()

            Text("Suggested Tags")
                .font(.ibmPlexMono(size: 16, weight: .medium))

            HStack(spacing: 8) {
                SuggestedTagChipView(tag: "Toprock") {
                    print("Add toprock")
                }

                SuggestedTagChipView(tag: "Freeze") {
                    print("Add freeze")
                }
            }

            Divider()

            Text("New Tag")
                .font(.ibmPlexMono(size: 16, weight: .medium))

            NewTagChipView(tagName: "Airflare") {
                print("Create airflare tag")
            }
        }
        .padding()
        .background(Color.backgroundPrimary)
    }
}
#endif
