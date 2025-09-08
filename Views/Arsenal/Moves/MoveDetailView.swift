import SwiftUI

struct MoveDetailView: View {
    let move: Move

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 24) {
                CustomVideoPlayerView(move: move, url: nil)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(move.name ?? "Untitled Move")
                                .font(.ibmPlexMono(size: 20, weight: .bold))
                                .foregroundColor(.textPrimary)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)

                            Text("Added: \(move.createdAt ?? Date(), format: .dateTime.month().day().year().hour().minute())")
                                .font(.ibmPlexMono(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        StatePillView(learningState: move.learningState)
                            .fixedSize()
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 20)
            .onAppear {
                MotionCatalog.Accessibility.selectionHaptic()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let mockMove = Move(context: PersistenceController.shared.container.viewContext)
    mockMove.id = UUID()
    mockMove.name = "Sample Move"
    mockMove.learningState = "NEW"
    mockMove.createdAt = Date()
    
    return MoveDetailView(move: mockMove)
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
