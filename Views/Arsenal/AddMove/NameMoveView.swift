import SwiftUI
import AVKit
import UIKit

struct NameMoveView: View {
    @ObservedObject var viewModel: AddMoveViewModel

    @State private var isTextFieldFocused = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var isSavePressed = false

    // Keyboard notification handling
    private let keyboardWillShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
    private let keyboardWillHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)

    var body: some View {
        VStack {
            if case .naming(let photosIdentifier, let originalAsset, let trimmedAsset, _, _, let rotationQuarterTurns) = viewModel.state {

                if let trimmedAsset = trimmedAsset {
                    // For trimmed assets, rotation is already baked into the exported file
                    // so we don't apply additional rotation to avoid double-rotation
                    let effectiveRotation = 0 // Rotation already baked into trimmed asset
                    CustomVideoPlayerView(AVPlayer(playerItem: AVPlayerItem(asset: trimmedAsset)), asset: trimmedAsset, rotationQuarterTurns: effectiveRotation)
                        .cornerRadius(12)
                        .padding()
                        .accessibilityIdentifier("NameMoveVideoPlayer")
                        .onAppear {
                            print("🔍 NAMING STATE: trimmedAsset=\(trimmedAsset != nil), originalAsset=\(originalAsset != nil), photosIdentifier=\(photosIdentifier)")
                            print("🎬 USING TRIMMED ASSET: \(trimmedAsset)")
                            print("🎬 TRIMMED ASSET: Using rotationQuarterTurns=\(effectiveRotation) (already baked into exported file)")
                        }
                } else if let originalAsset = originalAsset {
                    CustomVideoPlayerView(AVPlayer(playerItem: AVPlayerItem(asset: originalAsset)), asset: originalAsset, rotationQuarterTurns: rotationQuarterTurns)
                        .cornerRadius(12)
                        .padding()
                        .accessibilityIdentifier("NameMoveVideoPlayer")
                        .onAppear {
                            print("🔍 NAMING STATE: trimmedAsset=\(trimmedAsset != nil), originalAsset=\(originalAsset != nil), photosIdentifier=\(photosIdentifier)")
                            print("🎬 USING ORIGINAL ASSET: \(originalAsset)")
                            print("🎬 ORIGINAL ASSET: Using rotationQuarterTurns=\(rotationQuarterTurns) (original untrimmed video)")
                        }
                } else {
                    CustomVideoPlayerView(move: nil, photosIdentifier: photosIdentifier, rotationQuarterTurns: rotationQuarterTurns)
                        .cornerRadius(12)
                        .padding()
                        .accessibilityIdentifier("NameMoveVideoPlayer")
                        .onAppear {
                            print("🔍 NAMING STATE: trimmedAsset=\(trimmedAsset != nil), originalAsset=\(originalAsset != nil), photosIdentifier=\(photosIdentifier)")
                            print("🎬 USING PHOTOS IDENTIFIER: \(photosIdentifier)")
                            print("🎬 PHOTOS ASSET: Using rotationQuarterTurns=\(rotationQuarterTurns) (Photos library asset)")
                        }
                }
                VStack(spacing: 8) {
                    ZStack {
                        // Background with smooth animation
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(isTextFieldFocused ? 0.4 : 0.2))

                        // TextField with focus animations
                        TextField("Enter move name...", text: $viewModel.moveName)
                            .font(.custom("IBMPlexMono-Regular", size: 24))
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                            .background(Color.clear)
                            .onTapGesture {
                                isTextFieldFocused = true
                            }
                            .accessibilityIdentifier("Enter move name")
                    }
                    .frame(height: 60)
                    .padding(.horizontal, 8)

                    // Character counter with smooth transitions
                    HStack {
                        Spacer()
                        Text("\(viewModel.moveName.count)/50")
                            .font(.custom("IBMPlexMono-Regular", size: 12))
                            .foregroundColor(.textSecondary)
                            .opacity(viewModel.moveName.isEmpty ? 0.3 : 0.8)
                        Spacer()
                    }
                }
                .padding(.horizontal)

                Spacer()

                HStack(spacing: 15) {
                    Button("Back") {
                        MotionCatalog.Accessibility.tabNavigationHaptic()
                        if let asset = trimmedAsset ?? originalAsset {
                            // For back navigation, we need to go back to trimming state to preserve rotation
                            viewModel.state = .trimming(asset: asset, photosIdentifier: photosIdentifier, rotationQuarterTurns: rotationQuarterTurns)
                        } else {
                            viewModel.reset()
                        }
                    }
                    .buttonStyle(.appSecondary(size: .medium))
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("Back Button")

                    Button("Save") {
                        isSavePressed = true
                        MotionCatalog.Accessibility.actionHaptic()
                        viewModel.saveMove()
                        // Reset animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            isSavePressed = false
                        }
                    }
                    .disabled(viewModel.moveName.isEmpty)
                    .buttonStyle(.appPrimary(size: .medium))
                    .frame(maxWidth: .infinity)
                    .scaleEffect(isSavePressed ? 1.02 : 1.0)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityIdentifier("Save Button")
                }
                .padding(.horizontal)
                .padding(.bottom, 150)
            }
        }
        // Keyboard and focus management with smooth animations
        .onReceive(keyboardWillShow) { notification in
            let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
            keyboardHeight = keyboardFrame.height
            isTextFieldFocused = true
        }
        .onReceive(keyboardWillHide) { _ in
            keyboardHeight = 0
            isTextFieldFocused = false
        }
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    isTextFieldFocused = false
                }
        )
    }
}

#Preview {
    NameMoveView(viewModel: AddMoveViewModel(viewContext: PersistenceController.shared.container.viewContext))
        .preferredColorScheme(.dark)
}
