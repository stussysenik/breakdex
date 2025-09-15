import SwiftUI
import AVKit

struct MoveDetailView: View {
    let move: Move
    @State private var isPlayerReady = false

    private func getVideoAsset(for move: Move) -> AVAsset? {
        guard let videoData = move.videoReference,
              let path = String(data: videoData, encoding: .utf8) else {
            return nil
        }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        return AVURLAsset(url: url)
    }

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 24) {
                if let asset = getVideoAsset(for: move) {
                    VStack {
                        if isPlayerReady {
                            CustomVideoPlayerView(viewModel: UnifiedVideoPlayerViewModel(asset: asset, rotationQuarterTurns: Int(move.rotationQuarterTurns), mode: .main, appContainer: AppContainer.shared))
                                .frame(height: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            // Loading placeholder while player is initializing
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.secondary.opacity(0.2))
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                                    .scaleEffect(1.5)
                            }
                            .frame(height: 300)
                        }
                    }
                    .onAppear {
                        // Initialize the player and check when it's ready
                        let viewModel = UnifiedVideoPlayerViewModel(asset: asset, rotationQuarterTurns: Int(move.rotationQuarterTurns), mode: .main, appContainer: AppContainer.shared)
                        
                        // Monitor when the player becomes ready
                        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                            Task {
                                await MainActor.run {
                                    if viewModel.isPlayerReady {
                                        isPlayerReady = true
                                        timer.invalidate()
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Placeholder for when video is not available
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.secondary.opacity(0.2))
                        Image(systemName: "video.slash.fill")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 300)
                }

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
    // Note: We don't set the managedObjectID as it's read-only and managed by Core Data
    mockMove.name = "Sample Move"
    mockMove.learningState = "NEW"
    mockMove.createdAt = Date()
    
    return MoveDetailView(move: mockMove)
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
