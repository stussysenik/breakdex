import Photos
import OSLog

@MainActor
final class AlbumManager {
    static let shared = AlbumManager()
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "📸 AlbumManager")

    private(set) var breakdexAlbum: PHAssetCollection?
    private(set) var isReady = false

    private init() {}

    /// Sets up the AlbumManager by finding or creating the BreakDex album
    /// This method is idempotent and can be called multiple times safely
    func setup() async {
        guard !isReady else {
            logger.info("✅ AlbumManager already initialized - skipping setup")
            return
        }

        logger.info("🚀 AlbumManager setup started")

        // Check photo library authorization status
        let authorizationStatus = await checkPhotoLibraryAuthorization()
        guard authorizationStatus == .authorized else {
            logger.error("❌ Photo library authorization denied - status: \(String(describing: authorizationStatus))")
            isReady = false
            return
        }

        // Find or create the BreakDex album
        self.breakdexAlbum = await getOrCreateBreakDexAlbum()
        self.isReady = self.breakdexAlbum != nil

        if isReady {
            logger.info("✅ AlbumManager setup successful - BreakDex album is ready")
        } else {
            logger.error("❌ AlbumManager setup failed - could not find or create album")
        }
    }

    /// Returns the BreakDex album, ensuring it's ready
    /// - Returns: The BreakDex album or nil if not available
    func getBreakDexAlbum() async -> PHAssetCollection? {
        // Ensure the manager is ready
        if !isReady {
            await setup()
        }

        guard let album = breakdexAlbum else {
            logger.warning("⚠️ BreakDex album not available - attempting to setup again")
            await setup()
            return breakdexAlbum
        }

        // Verify the album still exists in the photo library
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "localIdentifier = %@", album.localIdentifier)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        if collections.firstObject != nil {
            return album
        } else {
            logger.warning("⚠️ BreakDex album no longer exists - recreating")
            self.breakdexAlbum = await getOrCreateBreakDexAlbum()
            self.isReady = self.breakdexAlbum != nil
            return breakdexAlbum
        }
    }

    /// Checks photo library authorization status
    private func checkPhotoLibraryAuthorization() async -> PHAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// Finds or creates the BreakDex album with atomic operations
    private func getOrCreateBreakDexAlbum() async -> PHAssetCollection? {
        logger.info("📸 Searching for BreakDex album")

        // First, try to find existing album
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", "BreakDex")
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        if let existingAlbum = collections.firstObject {
            logger.info("📸 Found existing BreakDex album: \(existingAlbum.localIdentifier)")
            return existingAlbum
        }

        logger.info("📸 BreakDex album not found - creating new album")
        return await createBreakDexAlbum()
    }

    /// Creates a new BreakDex album with proper error handling
    private func createBreakDexAlbum() async -> PHAssetCollection? {
        do {
            var albumPlaceholder: PHObjectPlaceholder?

            try await PHPhotoLibrary.shared().performChanges { [self] in
                self.logger.info("📸 Creating BreakDex album in PhotoLibrary")
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: "BreakDex")
                albumPlaceholder = request.placeholderForCreatedAssetCollection
            }

            guard let albumId = albumPlaceholder?.localIdentifier else {
                logger.error("❌ Failed to get placeholder for created BreakDex album")
                return nil
            }

            // Fetch the newly created album
            let newCollections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumId], options: nil)
            let createdAlbum = newCollections.firstObject

            if let album = createdAlbum {
                logger.info("✅ Successfully created BreakDex album: \(album.localIdentifier)")
            } else {
                logger.error("❌ Could not fetch newly created BreakDex album")
            }

            return createdAlbum

        } catch {
            logger.error("❌ Error creating BreakDex album: \(error.localizedDescription)")
            return nil
        }
    }

    /// Resets the album manager state (useful for testing or when permissions change)
    func reset() {
        logger.info("🔄 Resetting AlbumManager state")
        breakdexAlbum = nil
        isReady = false
    }
}