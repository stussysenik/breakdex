import SwiftUI
import AVKit
import OSLog
import UIKit

struct NameMoveView: View {
    @ObservedObject var viewModel: AddMoveViewModel
    @State private var isSaving = false
    
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "NameMoveView")
    
    // Haptic feedback generator
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        VStack {
            if case .naming(_, let originalAsset, let trimmedAsset, let trimStartTime, let trimEndTime, let rotation) = viewModel.state {
                let assetToPlay = trimmedAsset ?? originalAsset
                
                // Video preview section
                VStack(spacing: 16) {
                    if let asset = assetToPlay {
                        CustomVideoPlayerView(viewModel: UpdatedVideoPlayerViewModel(asset: asset, rotationQuarterTurns: rotation, appContainer: AppContainer.shared))
                            .frame(height: 300)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                    
                    // Video info
                    if let trimmed = trimmedAsset {
                        Text("Trimmed: \(formatTime(trimStartTime)) - \(formatTime(trimEndTime))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
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
        .onReceive(viewModel.$state) { newState in
            if case .ready = newState {
                isSaving = false
            }
        }
    }
    
    private func formatTime(_ seconds: Double?) -> String {
        guard let seconds = seconds else { return "0:00" }
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(minutes):\(String(format: "%02d", secs))"
    }
}
