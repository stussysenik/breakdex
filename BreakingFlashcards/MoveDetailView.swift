import SwiftUI

struct MoveDetailView: View {
    // This view receives a single 'Move' object to display.
    let move: Move

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 24) {
                // Use the CustomVideoPlayerView with constrained sizing
                CustomVideoPlayerView(move: move)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                // Display the move's details below the video.
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
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 20)
        }
        .navigationTitle(move.name ?? "Move Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    // Create a mock Move for preview
    let mockMove = Move(context: PersistenceController.shared.container.viewContext)
    mockMove.id = UUID()
    mockMove.name = "Sample Move"
    mockMove.learningState = "NEW"
    mockMove.createdAt = Date()
    // Note: videoReference would need actual video data for full preview

    return MoveDetailView(move: mockMove)
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
