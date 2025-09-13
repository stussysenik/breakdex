import SwiftUI
import AVKit
import PhotosUI
import CoreData

struct PreTrimView: View {
    @ObservedObject var viewModel: AddMoveViewModel
    let asset: AVAsset
    let photosIdentifier: String?
    @Binding var selectedTab: TabSelection

    // Video player model for proper lifecycle management
    @StateObject private var videoModel = VideoPlayerViewModel()


    init(viewModel: AddMoveViewModel, asset: AVAsset, photosIdentifier: String?, selectedTab: Binding<TabSelection>) {
        self.viewModel = viewModel
        self.asset = asset
        self.photosIdentifier = photosIdentifier
        self._selectedTab = selectedTab

        print("🎬 PRE-TRIM VIEW CREATED:")
        print("   📹 Asset: \(asset)")
        print("   🆔 Photos ID: \(photosIdentifier ?? "nil")")
        print("   📊 Asset duration: \(String(describing: asset.duration.seconds)) seconds")
        print("   📊 Asset tracks: \(asset.tracks.count)")
    }
    
    var body: some View {
        print("🎬 PRE-TRIM VIEW: body being rendered")
        return VStack {
            HStack {
                Spacer()
                Button("Cancel") {
                    print("🎬 PRE-TRIM VIEW: Cancel button tapped")
                    // Clean teardown of video player to prevent lingering tasks
                    videoModel.teardown()
                    selectedTab = .add
                    viewModel.reset()
                }
                .padding()
                .accessibilityIdentifier("Cancel Button")
            }

            CustomVideoPlayerView(videoModel: videoModel, asset: asset, rotationQuarterTurns: 0)
                .cornerRadius(12)
                .accessibilityIdentifier("CustomVideoPlayerView")
                .onAppear {
                    print("🎬 PRE-TRIM VIDEO PLAYER:")
                    print("   📹 Using asset: \(asset)")
                    print("   🆔 Photos ID: \(photosIdentifier ?? "nil")")
                    print("   🔄 Rotation: 0 (no rotation for preview)")
                }
                .task {
                    print("🎬 PreTrimView: Setting up fresh video source")
                    videoModel.setSource(asset: asset, quarterTurns: 0)
                }

            VStack(spacing: 10) {
                HStack(spacing: 20) {
                    Button("Change Video") {
                        print("🎬 PRE-TRIM: Change Video button tapped")
                        print("   📹 Current asset: \(asset)")
                        print("   🆔 Current photos ID: \(photosIdentifier ?? "nil")")

                        // Use state-driven navigation instead of local state management
                        viewModel.beginChangeVideo()
                        print("   🔄 Initiated state-driven video change")
                    }
                    .buttonStyle(.appSecondary(size: .small))
                    .accessibilityIdentifier("Change Video Button")

                    Button("Trim Video") {
                        viewModel.startTrimming(rotationQuarterTurns: 0)
                    }
                    .buttonStyle(.appSecondary(size: .small))
                    .accessibilityIdentifier("Trim Video Button")

                    Button("Use Original") {
                        viewModel.startNaming()
                    }
                    .buttonStyle(.appPrimary(size: .small))
                    .accessibilityIdentifier("Use Original Button")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 180)
        }
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 12)
        }
        .onDisappear {
            print("🎬 PreTrimView: View disappeared, tearing down video player")
            videoModel.teardown()
        }
    }
}

#Preview {
    PreTrimView(viewModel: AddMoveViewModel(viewContext: PersistenceController.shared.container.viewContext), asset: AVAsset(), photosIdentifier: nil, selectedTab: .constant(.add))
        .preferredColorScheme(.dark)
}
