import SwiftUI

struct MoveDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let move: Move

    @State private var isEditingName = false
    @State private var editedName = ""

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                CustomVideoPlayerView(move: move)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    .padding(.horizontal, Spacing.lg)

                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(alignment: .top, spacing: Spacing.md) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            if isEditingName {
                                TextField("Move Name", text: $editedName, onCommit: {
                                    saveName()
                                })
                                .font(.titleSmall)
                                .foregroundColor(.textPrimary)
                                .textFieldStyle(.plain)
                                .padding(Spacing.sm)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                            } else {
                                Text(move.name ?? "Untitled Move")
                                    .font(.titleSmall)
                                    .foregroundColor(.textPrimary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                    .onTapGesture {
                                        editedName = move.name ?? ""
                                        isEditingName = true
                                    }
                            }

                            Text("Added: \(move.createdAt ?? Date(), format: .dateTime.month().day().year())")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        StatePillView(learningState: move.learningState)
                            .fixedSize()
                    }

                    Spacer()
                }
                .padding(.horizontal, Spacing.lg)
            }
            .padding(.top, Spacing.lg)
        }
        .navigationTitle(move.name ?? "Move Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func saveName() {
        guard !editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isEditingName = false
            return
        }
        move.name = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try viewContext.save()
            isEditingName = false
        } catch {
            print("Failed to save move name: \(error)")
        }
    }
}

#Preview {
    let mockMove = Move(context: PersistenceController.preview.container.viewContext)
    mockMove.id = UUID()
    mockMove.name = "Sample Move"
    mockMove.learningState = "NEW"
    mockMove.createdAt = Date()

    return MoveDetailView(move: mockMove)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
