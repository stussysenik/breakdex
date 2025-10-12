import SwiftUI

// MARK: - State Pill View
/// Simple pill view for displaying learning states or status indicators
/// Essentialist design - minimal and focused
public struct StatePillView: View {

    // MARK: - Properties
    let learningState: String

    // MARK: - Body
    public var body: some View {
        Text(learningState)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .clipShape(Capsule())
    }

    // MARK: - Styling
    private var backgroundColor: Color {
        switch learningState.uppercased() {
        case "NEW", "NEW LEARN":
            return Color.blue.opacity(0.2)
        case "LEARNING", "LEARNING":
            return Color.orange.opacity(0.2)
        case "MASTERY", "MASTERED":
            return Color.green.opacity(0.2)
        default:
            return Color.gray.opacity(0.2)
        }
    }

    private var textColor: Color {
        switch learningState.uppercased() {
        case "NEW", "NEW LEARN":
            return Color.blue
        case "LEARNING", "LEARNING":
            return Color.orange
        case "MASTERY", "MASTERED":
            return Color.green
        default:
            return Color.gray
        }
    }

    // MARK: - Initialization
    public init(learningState: String) {
        self.learningState = learningState
    }
}

// MARK: - Preview
#Preview("State Pill View") {
    VStack(spacing: 10) {
        StatePillView(learningState: "NEW")
        StatePillView(learningState: "LEARNING")
        StatePillView(learningState: "MASTERY")
        StatePillView(learningState: "UNKNOWN")
    }
    .padding()
}