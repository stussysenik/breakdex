import SwiftUI
import Photos

// MARK: - Video Gallery View
struct VideoGalleryView: View {
    @Bindable var viewModel: AddMoveViewModel
    @StateObject private var galleryViewModel = VideoGalleryViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header - Photos.app style
                HStack {
                    Button(action: {
                        viewModel.cancelChangeVideo()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    Text("Select Video")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Color.clear.frame(width: 44, height: 44) // Balance the layout
                }
                .padding(.horizontal, 16)
                .padding(.top: 8)
                .padding(.bottom: 16)

                // Gallery Content
                if galleryViewModel.authorizationStatus == .denied || galleryViewModel.authorizationStatus == .restricted {
                    permissionDeniedView
                } else if galleryViewModel.isLoading {
                    loadingView
                } else if galleryViewModel.videos.isEmpty {
                    emptyView
                } else {
                    galleryGridView
                }
            }

            // Selection Overlay - Photos.app style
            if let selectedVideo = galleryViewModel.selectedVideo {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        selectionButton(for: selectedVideo)
                            .padding(.trailing: 20)
                            .padding(.bottom: 34)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .statusBar(hidden: false)
        .preferredColorScheme(.dark)
        .onAppear {
            galleryViewModel.loadVideos()
        }
        .onDisappear {
            galleryViewModel.stopCaching()
        }
    }

    // MARK: - Subviews

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.5))

            Text("Photos Access Required")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Text("To select videos, allow access to your photo library in Settings.")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Open Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 140, height: 44)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(22)
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.5)
            Text("Loading videos...")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, 16)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "video.slash")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.5))
            Text("No Videos Found")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            Text("Videos you add to your library will appear here.")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var galleryGridView: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2)
                ], spacing: 2) {
                    ForEach(galleryViewModel.videos) { video in
                        VideoThumbnailView(
                            video: video,
                            isSelected: video.id == galleryViewModel.selectedVideoId,
                            cellSize: geometry.size.width / 3 - 1.33 // Account for spacing
                        )
                        .onTapGesture {
                            galleryViewModel.selectVideo(video)
                        }
                        .onAppear {
                            galleryViewModel.startCaching(for: video)
                        }
                        .onDisappear {
                            galleryViewModel.stopCaching(for: video)
                        }
                    }
                }
                .padding(.horizontal: 2)
                .padding(.bottom: 100) // Space for safe area and selection button
            }
        }
    }

    private func selectionButton(for video: VideoAsset) -> some View {
        Button(action: {
            galleryViewModel.confirmSelection()
            // This will trigger the viewModel to handle the selection
            Task {
                do {
                    let asset = try await PhotosClient.shared.resolveAsset(for: video.asset)
                    viewModel.didPickVideo(asset: asset, photosIdentifier: video.asset.localIdentifier)
                } catch {
                    print("Error resolving asset: \(error)")
                    // Handle error - could show alert or fallback
                }
            }
        }) {
            Text("Use Video")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 120, height: 50)
                .background(Color.blue)
                .cornerRadius(25)
        }
    }
}

// MARK: - Video Thumbnail View
struct VideoThumbnailView: View {
    let video: VideoAsset
    let isSelected: Bool
    let cellSize: CGFloat

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Thumbnail
            if let thumbnail = video.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cellSize, height: cellSize)
                    .clipped()
                    .cornerRadius(4)
                    .overlay(
                        // Selection overlay - Photos.app style
                        isSelected ?
                        Color.blue.opacity(0.3)
                            .cornerRadius(4) :
                        Color.clear
                    )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: cellSize, height: cellSize)
                    .cornerRadius(4)
                    .overlay(
                        Image(systemName: "video")
                            .foregroundColor(.white.opacity(0.5))
                            .font(.system(size: 24))
                    )
            }

            // Selection checkmark - Photos.app style
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .background(Color.white.clipShape(Circle()))
                    .font(.system(size: 20))
                    .padding(4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: cellSize, height: cellSize)
        .overlay(alignment: .bottomTrailing) {
            // Duration overlay - Photos.app style
            if video.duration > 0 {
                Text(video.durationFormatted)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white)
                    .padding(.horizontal: 4)
                    .padding(.vertical: 2)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(3)
                    .padding(4)
            }
        }
    }
}

// MARK: - Video Asset Model
struct VideoAsset: Identifiable {
    let id: String
    let asset: PHAsset
    let thumbnail: UIImage?
    let duration: TimeInterval

    var durationFormatted: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Gallery View Model
class VideoGalleryViewModel: ObservableObject {
    @Published var videos: [VideoAsset] = []
    @Published var isLoading = true
    @Published var selectedVideoId: String?
    @Published var selectedVideo: VideoAsset?
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined

    private let cachingImageManager = PHCachingImageManager()
    private var thumbnailSize = CGSize(width: 120 * UIScreen.main.scale, height: 120 * UIScreen.main.scale)
    private var cachedAssets = Set<PHAsset>()
    private var activeRequests = Set<PHImageRequestID>()

    func loadVideos() {
        isLoading = true

        // Check authorization status first
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch authorizationStatus {
        case .authorized, .limited:
            fetchVideos()
        case .denied, .restricted:
            isLoading = false
        case .notDetermined:
            requestAuthorization()
        @unknown default:
            isLoading = false
        }
    }

    private func requestAuthorization() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.authorizationStatus = status
                switch status {
                case .authorized, .limited:
                    self.fetchVideos()
                case .denied, .restricted, .notDetermined:
                    self.isLoading = false
                @unknown default:
                    self.isLoading = false
                }
            }
        }
    }

    private func fetchVideos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)

        let assets = PHAsset.fetchAssets(with: .video, options: fetchOptions)

        // Handle empty case
        if assets.count == 0 {
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }

        // Create video assets without thumbnails first (for immediate display)
        var videoAssets: [VideoAsset] = []
        assets.enumerateObjects { (asset, _, _) in
            let videoAsset = VideoAsset(
                id: asset.localIdentifier,
                asset: asset,
                thumbnail: nil, // Will be loaded progressively
                duration: asset.duration
            )
            videoAssets.append(videoAsset)
        }

        // Sort by creation date
        videoAssets.sort { ($0.asset.creationDate ?? Date()) > ($1.asset.creationDate ?? Date()) }

        DispatchQueue.main.async {
            self.videos = videoAssets
            self.startCachingThumbnails()
            self.loadThumbnailsProgressively()
        }
    }

    private func startCachingThumbnails() {
        let visibleAssets = videos.prefix(20).map { $0.asset } // Cache first 20 thumbnails
        cachedAssets.formUnion(visibleAssets)

        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .opportunistic
        requestOptions.resizeMode = .fast
        requestOptions.isSynchronous = false

        cachingImageManager.startCachingImages(for: Array(visibleAssets),
                                              targetSize: thumbnailSize,
                                              contentMode: .aspectFill,
                                              options: requestOptions)
    }

    private func loadThumbnailsProgressively() {
        let batchSize = 10
        var currentIndex = 0

        func loadNextBatch() {
            guard currentIndex < videos.count else {
                isLoading = false
                return
            }

            let endIndex = min(currentIndex + batchSize, videos.count)
            let batchAssets = videos[currentIndex..<endIndex]

            for (index, videoAsset) in batchAssets.enumerated() {
                let requestOptions = PHImageRequestOptions()
                requestOptions.deliveryMode = .opportunistic
                requestOptions.resizeMode = .fast
                requestOptions.isSynchronous = false

                let requestId = cachingImageManager.requestImage(
                    for: videoAsset.asset,
                    targetSize: thumbnailSize,
                    contentMode: .aspectFill,
                    options: requestOptions
                ) { [weak self] (image, info) in
                    guard let self = self else { return }

                    DispatchQueue.main.async {
                        if let image = image {
                            // Update the thumbnail for this asset
                            if let videoIndex = self.videos.firstIndex(where: { $0.id == videoAsset.id }) {
                                self.videos[videoIndex] = VideoAsset(
                                    id: videoAsset.id,
                                    asset: videoAsset.asset,
                                    thumbnail: image,
                                    duration: videoAsset.duration
                                )
                            }
                        }

                        // Mark loading as complete when we've processed enough assets
                        if currentIndex >= min(20, self.videos.count) {
                            self.isLoading = false
                        }
                    }
                }

                activeRequests.insert(requestId)
            }

            currentIndex = endIndex

            // Load next batch after a small delay to prevent overwhelming the system
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                loadNextBatch()
            }
        }

        loadNextBatch()
    }

    func startCaching(for video: VideoAsset) {
        guard !cachedAssets.contains(video.asset) else { return }
        cachedAssets.insert(video.asset)

        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .opportunistic
        requestOptions.resizeMode = .fast

        cachingImageManager.startCachingImages(for: [video.asset],
                                              targetSize: thumbnailSize,
                                              contentMode: .aspectFill,
                                              options: requestOptions)
    }

    func stopCaching(for video: VideoAsset) {
        cachedAssets.remove(video.asset)
        cachingImageManager.stopCachingImages(for: [video.asset],
                                             targetSize: thumbnailSize,
                                             contentMode: .aspectFill,
                                             options: nil)
    }

    func stopCaching() {
        cachingImageManager.stopCachingImagesForAllAssets()
        activeRequests.forEach { cachingImageManager.cancelImageRequest($0) }
        activeRequests.removeAll()
        cachedAssets.removeAll()
    }

    func selectVideo(_ video: VideoAsset) {
        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedVideoId == video.id {
                // Deselect if tapping the same video
                selectedVideoId = nil
                selectedVideo = nil
            } else {
                selectedVideoId = video.id
                selectedVideo = video
            }
        }
    }

    func confirmSelection() {
        // The actual selection handling is done in the view
        // This just provides the interface
    }

    deinit {
        stopCaching()
    }
}
