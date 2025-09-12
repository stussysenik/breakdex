import SwiftUI

struct ComboDetailHeaderView: View {
    let combo: Combo
    var comboMovesCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(combo.name ?? "Untitled Combo")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)

            if comboMovesCount > 0 {
                Text("\(comboMovesCount) moves")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}