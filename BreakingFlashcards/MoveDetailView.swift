import SwiftUI

struct MoveDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    // This view receives a single 'Move' object to display.
    let move: Move

    @State private var isEditingName = false
    @State private var editedName = ""

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
                            if isEditingName {
                                TextField("Move Name", text: $editedName, onCommit: {
                                    saveName()
                                })
                                .font(.ibmPlexMono(size: 20, weight: .bold))
                                .foregroundColor(.textPrimary)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                            } else {
                                Text(move.name ?? "Untitled Move")
                                    .font(.ibmPlexMono(size: 20, weight: .bold))
                                    .foregroundColor(.textPrimary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                    .onTapGesture {
                                        editedName = move.name ?? ""
                                        isEditingName = true
                                    }
                            }
                            
                            Text("ID: \(move.id?.uuidString ?? "Unknown")")
                                .font(.ibmPlexMono(size: 11))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                            
                            Text("Added: \(move.createdAt ?? Date(), format: .dateTime.month().day().year().hour().minute())")
                                .font(.ibmPlexMono(size: 13))
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
    // Create a mock Move for preview
    let mockMove = Move(context: PersistenceController.preview.container.viewContext)
    mockMove.id = UUID()
    mockMove.name = "Sample Move"
    mockMove.learningState = "NEW"
    mockMove.createdAt = Date()
    // Note: videoReference would need actual video data for full preview

    return MoveDetailView(move: mockMove)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
