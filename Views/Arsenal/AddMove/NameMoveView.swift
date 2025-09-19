import SwiftUI
import AVKit
import OSLog
import UIKit

struct NameMoveView: View {
    @Bindable var viewModel: AddMoveViewModel
    
    // 💡 SOLUTION: Player view model is now provided by the state, no async creation needed
    @State private var isSaving = false
    
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "NameMoveView")
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        VStack {
            if case .naming(let photosIdentifier, let originalAsset, let trimStartTime, let trimEndTime, let rotation, let playerViewModel) = viewModel.state {
                // Video preview section
                VStack(spacing: 16) {
                    // 💡 SOLUTION: Player is now provided by the state and already ready to play
                    // The video data (player item) is ALREADY trimmed and rotated by the unified player.
                    // We must tell the UI layer to apply ZERO additional rotation to avoid conflicts.
                    CustomVideoPlayerView(viewModel: playerViewModel, rotationQuarterTurns: .constant(rotation))
                        .frame(height: 300)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    
                    // Video info - use the precise formatTime function
                    Text("Trimmed: \(formatTime(trimStartTime)) - \(formatTime(trimEndTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if rotation > 0 {
                        Text("Rotation: \(rotation * 90)°")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Name input section
                VStack(spacing: 20) {
                    TextField("Enter move name...", text: $viewModel.moveName)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                        .disabled(isSaving)
                    
                    Text("\(viewModel.moveName.count)/50")
                        .font(.caption)
                        .foregroundColor(viewModel.moveName.count > 50 ? .red : .secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 20) {
                    Button("Back") {
                        impactGenerator.impactOccurred()
                        viewModel.backToTrimming()
                    }
                    .buttonStyle(.appSecondary(size: .medium))
                    .disabled(isSaving)
                    
                    Button(action: {
                        impactGenerator.impactOccurred()
                        isSaving = true
                        viewModel.saveMove()
                    }) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark")
                            }
                            Text(isSaving ? "Saving..." : "Save Move")
                        }
                    }
                    .buttonStyle(.appPrimary(size: .medium))
                    .disabled(viewModel.moveName.isEmpty || viewModel.moveName.count > 50 || isSaving)
                }
                .padding()
                .padding(.bottom, 180)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onChange(of: viewModel.state) { _, newState in
            if case .ready = newState {
                isSaving = false
            }
        }
    }
    
    // Use the precise time formatting function
    private func formatTime(_ seconds: Double?) -> String {
        guard let seconds = seconds else { return "00:00.00" }
        let minutes = Int(seconds) / 60
        let secs = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%02d:%05.2f", minutes, secs)
    }
}
