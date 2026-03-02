import SwiftUI
import SwiftData

struct BreakingArsenalView: View {

    @Environment(AppSettings.self) private var appSettings

    @Query(sort: \Move.createdAt, order: .reverse) private var moves: [Move]
    @Query private var combos: [Combo]
    @Query(sort: \Review.reviewedAt, order: .reverse) private var reviews: [Review]

    @State private var isCreatingCategory = false
    @State private var newCategoryName = ""
    @State private var newCategoryColorIndex = 0

    private let heatmapDays = 84

    private var customCategoryNames: [String] {
        appSettings.categories
            .map { $0.name.uppercased() }
            .filter { $0 != "MOVE" && $0 != "COMBO" }
            .sorted()
    }

    private var reviewCountsByDay: [Date: Int] {
        let calendar = Calendar.current
        return reviews.reduce(into: [Date: Int]()) { acc, review in
            guard let reviewedAt = review.reviewedAt else { return }
            let day = calendar.startOfDay(for: reviewedAt)
            acc[day, default: 0] += 1
        }
    }

    private var heatmapWeeks: [[HeatmapDay]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDay = calendar.date(byAdding: .day, value: -(heatmapDays - 1), to: today) else {
            return []
        }

        let days = (0..<heatmapDays).compactMap { offset -> HeatmapDay? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDay) else { return nil }
            return HeatmapDay(date: date, count: reviewCountsByDay[date, default: 0])
        }

        return stride(from: 0, to: days.count, by: 7).map { index in
            Array(days[index..<min(index + 7, days.count)])
        }
    }

    private var reviewsInHeatmapRange: Int {
        heatmapWeeks.flatMap { $0 }.reduce(0) { $0 + $1.count }
    }

    private var activePracticeDays: Int {
        heatmapWeeks.flatMap { $0 }.filter { $0.count > 0 }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    categoriesSection
                    consistencySection
                }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
            }
            .navigationTitle("LIBRARY")
            .navigationBarTitleDisplayMode(.inline)
            .alert("New Category", isPresented: $isCreatingCategory) {
                TextField("Category Name", text: $newCategoryName)
                Button("Cancel", role: .cancel) { newCategoryName = "" }
                Button("Create") {
                    let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    if !name.isEmpty {
                        let colorHex = CategoryPalette.hexColors[newCategoryColorIndex % CategoryPalette.hexColors.count]
                        appSettings.addCategory(name: name, hexColor: colorHex)
                        newCategoryColorIndex += 1
                    }
                    newCategoryName = ""
                }
            } message: {
                Text("Add a category for organizing new videos in the save flow.")
            }
        }
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionLabel("CATEGORIES")

            VStack(spacing: 0) {
                NavigationLink {
                    MoveListView(screenTitle: "Moves")
                } label: {
                    categoryRow(name: "MOVES", detail: "\(moves.count)")
                }
                .buttonStyle(.plain)

                Divider()

                NavigationLink {
                    ComboListView()
                } label: {
                    categoryRow(name: "COMBOS", detail: "\(combos.count)")
                }
                .buttonStyle(.plain)

                if !customCategoryNames.isEmpty {
                    Divider()
                }

                ForEach(Array(customCategoryNames.enumerated()), id: \.element) { index, name in
                    NavigationLink {
                        MoveListView(categoryFilter: name, screenTitle: name.capitalized)
                    } label: {
                        categoryRow(name: name, detail: "\(moveCount(in: name))")
                    }
                    .buttonStyle(.plain)

                    if index < customCategoryNames.count - 1 {
                        Divider()
                    }
                }

                Divider()

                Button {
                    isCreatingCategory = true
                } label: {
                    Text("+ NEW CATEGORY")
                        .font(.ibmPlexMono(size: 14, weight: .medium))
                        .foregroundColor(.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Spacing.md)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.xs)
            .glassCard(radius: Radius.md)
        }
    }

    private var consistencySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionLabel("YOUR CONSISTENCY")

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("\(reviewsInHeatmapRange) reviews across \(activePracticeDays) active days")
                    .font(.ibmPlexMono(size: 13))
                    .foregroundColor(.textSecondary)

                HStack(alignment: .top, spacing: Spacing.xs) {
                    ForEach(Array(heatmapWeeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: Spacing.xs) {
                            ForEach(week) { day in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(heatmapColor(for: day.count))
                                    .frame(width: 11, height: 11)
                            }
                        }
                    }
                }

                HStack(spacing: Spacing.xs) {
                    Text("LESS")
                        .font(.ibmPlexMono(size: 11))
                        .foregroundColor(.textSecondary)

                    ForEach(0..<5, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatmapColor(for: heatmapCountThreshold(for: level)))
                            .frame(width: 9, height: 9)
                    }

                    Text("MORE")
                        .font(.ibmPlexMono(size: 11))
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(Spacing.lg)
            .glassCard(radius: Radius.md)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.ibmPlexMono(size: 13, weight: .bold))
            .foregroundColor(.textPrimary)
            .tracking(0.4)
    }

    private func categoryRow(name: String, detail: String) -> some View {
        HStack(spacing: Spacing.md) {
            Text(name)
                .font(.ibmPlexMono(size: 18, weight: .bold))
                .foregroundColor(.textPrimary)

            Spacer(minLength: Spacing.md)

            Text(detail)
                .font(.ibmPlexMono(size: 14, weight: .medium))
                .foregroundColor(.textSecondary)
        }
        .padding(.vertical, Spacing.md)
    }

    private func moveCount(in category: String) -> Int {
        moves.filter { ($0.category ?? "MOVE").uppercased() == category.uppercased() }.count
    }

    private func heatmapColor(for count: Int) -> Color {
        switch count {
        case 0:
            return Color.neutralFill
        case 1:
            return Color.accent.opacity(0.25)
        case 2...3:
            return Color.accent.opacity(0.42)
        case 4...6:
            return Color.accent.opacity(0.65)
        default:
            return Color.accent
        }
    }

    private func heatmapCountThreshold(for level: Int) -> Int {
        switch level {
        case 0: return 0
        case 1: return 1
        case 2: return 2
        case 3: return 4
        default: return 7
        }
    }
}

private struct HeatmapDay: Identifiable {
    let date: Date
    let count: Int

    var id: Date { date }
}

#Preview("Arsenal - Light") {
    BreakingArsenalView()
        .modelContainer(.preview)
        .environment(AppSettings())
}

#Preview("Arsenal - Dark") {
    BreakingArsenalView()
        .modelContainer(.preview)
        .environment(AppSettings())
        .preferredColorScheme(.dark)
}
