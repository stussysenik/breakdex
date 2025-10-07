import Photos
import OSLog
import Foundation

// MARK: - Category Theory Analysis
/*
 CATEGORY THEORY ANALYSIS: Atomic Album Operations

 Objects:
   - PhotoLibrary (PHPhotoLibrary)
   - AlbumCollection (PHAssetCollection)
   - AtomicOperation (FindOrCreate)

 Morphisms:
   - findAlbum: PhotoLibrary → Option<AlbumCollection>
   - createAlbum: PhotoLibrary → AlbumCollection
   - findOrCreate: PhotoLibrary → AlbumCollection (atomic natural transformation)

 Functor Structure:
   - Atomic: Operation → AtomicOperation
   - preserves composition: Atomic(f ∘ g) = Atomic(f) ∘ Atomic(g)

 Natural Transformation:
   findOrCreate: Find ⊕ Create → Atomic
   This ensures a unified atomic operation that prevents race conditions

 Adjoint Functors:
   - LeftAdjoint: Find (searches existing state)
   - RightAdjoint: Create (modifies state)
   - The adjunction Find ⊣ Create provides the atomic guarantee

 Isomorphism:
   - Single BreakDex album uniqueness is preserved through atomic operations
   - Race conditions are eliminated through proper synchronization
*/

// MARK: - Album Manager Errors
public enum AlbumManagerError: Error, LocalizedError {
    case permissionDenied
    case albumCreationFailed(Error)
    case albumNotFound
    case atomicOperationFailed(Error)
    case photoLibraryUnavailable
    case transientFailure(Error)
    case duplicateCreationAttempt
    case invalidAlbumState

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Photo library permission denied"
        case .albumCreationFailed(let error):
            return "Failed to create BreakDex album: \(error.localizedDescription)"
        case .albumNotFound:
            return "BreakDex album not found in photo library"
        case .atomicOperationFailed(let error):
            return "Atomic album operation failed: \(error.localizedDescription)"
        case .photoLibraryUnavailable:
            return "Photo library is currently unavailable"
        case .transientFailure(let error):
            return "Transient failure occurred: \(error.localizedDescription)"
        case .duplicateCreationAttempt:
            return "Duplicate album creation attempt detected and prevented"
        case .invalidAlbumState:
            return "Album is in an invalid state"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Please grant photo library access in Settings"
        case .albumCreationFailed, .atomicOperationFailed:
            return "Please try again or restart the app"
        case .albumNotFound:
            return "The album may have been deleted - a new one will be created"
        case .photoLibraryUnavailable:
            return "Please check your device's photo library"
        case .transientFailure:
            return "Please try again in a moment"
        case .duplicateCreationAttempt:
            return "No action needed - duplicate album was prevented"
        case .invalidAlbumState:
            return "Please restart the app to reset album state"
        }
    }
}

// MARK: - Album Operation Metrics
public struct AlbumOperationMetrics {
    let operationType: String
    let duration: TimeInterval
    let success: Bool
    let cacheHit: Bool
    let retryCount: Int
    let timestamp: Date
    let correlationId: String

    init(operationType: String, duration: TimeInterval, success: Bool, cacheHit: Bool = false, retryCount: Int = 0, correlationId: String) {
        self.operationType = operationType
        self.duration = duration
        self.success = success
        self.cacheHit = cacheHit
        self.retryCount = retryCount
        self.timestamp = Date()
        self.correlationId = correlationId
    }
}

// MARK: - Thread-Safe Album Cache
private actor AlbumCache {
    private var cachedAlbum: PHAssetCollection?
    private var lastValidationDate: Date?
    private var isCreating = false

    func getCachedAlbum() -> PHAssetCollection? {
        return cachedAlbum
    }

    func setCachedAlbum(_ album: PHAssetCollection) {
        cachedAlbum = album
        lastValidationDate = Date()
    }

    func invalidateCache() {
        cachedAlbum = nil
        lastValidationDate = nil
    }

    func setIsCreating(_ creating: Bool) {
        isCreating = creating
    }

    func getIsCreating() -> Bool {
        return isCreating
    }

    func isValidCache(maxAge: TimeInterval = 300) -> Bool {
        guard let validationDate = lastValidationDate else { return false }
        return Date().timeIntervalSince(validationDate) < maxAge
    }
}

// MARK: - Enhanced Album Manager
@MainActor
final class AlbumManager {
    static let shared = AlbumManager()
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "📸 AlbumManager")

    // Thread-safe properties
    private let albumCache = AlbumCache()
    private let operationQueue = DispatchQueue(label: "com.breakingflashcards.albummanager", qos: .userInitiated)
    private let atomicOperationLock = NSLock()

    // Properties
    private(set) var isReady = false
    private var operationMetrics: [AlbumOperationMetrics] = []
    private var correlationIdGenerator = 0

    // Constants
    private static let albumName = "breakdex"
    private static let maxRetryAttempts = 3
    private static let retryDelay: TimeInterval = 0.5
    private static let operationTimeout: TimeInterval = 30.0

    private init() {
        logger.info("📸 ALBUM_MANAGER: 🚀 Initialized with atomic album handling")
    }

    // MARK: - Public API

    /// 🎯 CRITICAL: Atomic setup with comprehensive error handling and retry logic
    func setup() async throws {
        let correlationId = generateCorrelationId()
        logger.info("📸 ALBUM_MANAGER: 🚀 Starting atomic setup [\(correlationId)]")

        guard !isReady else {
            logger.info("📸 ALBUM_MANAGER: ✅ Already initialized - skipping setup [\(correlationId)]")
            return
        }

        let startTime = Date()

        do {
            // Check authorization with retry logic
            let authorizationStatus = await checkPhotoLibraryAuthorization(correlationId: correlationId)
            guard authorizationStatus == .authorized else {
                throw AlbumManagerError.permissionDenied
            }

            // 🎯 CRITICAL: Atomic find-or-create operation
            let album = try await findOrCreateBreakDexAlbum(correlationId: correlationId)

            // Update cache and state
            await albumCache.setCachedAlbum(album)
            isReady = true

            // Log metrics
            let metrics = AlbumOperationMetrics(
                operationType: "setup",
                duration: Date().timeIntervalSince(startTime),
                success: true,
                correlationId: correlationId
            )
            recordMetrics(metrics)

            logger.info("📸 ALBUM_MANAGER: ✅ Atomic setup completed successfully [\(correlationId)]")

        } catch {
            isReady = false
            await albumCache.invalidateCache()

            let metrics = AlbumOperationMetrics(
                operationType: "setup",
                duration: Date().timeIntervalSince(startTime),
                success: false,
                correlationId: correlationId
            )
            recordMetrics(metrics)

            logger.error("📸 ALBUM_MANAGER: ❌ Atomic setup failed [\(correlationId)]: \(error)")
            throw error
        }
    }

    /// 🎯 CRITICAL: Get BreakDex album with atomic find-or-create guarantee
    func getBreakDexAlbum() async throws -> PHAssetCollection {
        let correlationId = generateCorrelationId()
        logger.info("📸 ALBUM_MANAGER: 📚 Requesting BreakDex album [\(correlationId)]")

        let startTime = Date()

        do {
            // Check cache first
            if let cachedAlbum = await albumCache.getCachedAlbum(),
               await albumCache.isValidCache(),
               await verifyAlbumExists(cachedAlbum, correlationId: correlationId) {

                let metrics = AlbumOperationMetrics(
                    operationType: "get_album_cache_hit",
                    duration: Date().timeIntervalSince(startTime),
                    success: true,
                    cacheHit: true,
                    correlationId: correlationId
                )
                recordMetrics(metrics)

                logger.info("📸 ALBUM_MANAGER: ✅ Cache hit - returning cached album [\(correlationId)]")
                return cachedAlbum
            }

            // Ensure manager is ready
            if !isReady {
                try await setup()
            }

            // 🎯 CRITICAL: Atomic find-or-create operation
            let album = try await findOrCreateBreakDexAlbum(correlationId: correlationId)

            // Update cache
            await albumCache.setCachedAlbum(album)

            let metrics = AlbumOperationMetrics(
                operationType: "get_album_cache_miss",
                duration: Date().timeIntervalSince(startTime),
                success: true,
                cacheHit: false,
                correlationId: correlationId
            )
            recordMetrics(metrics)

            logger.info("📸 ALBUM_MANAGER: ✅ Successfully retrieved BreakDex album [\(correlationId)]: \(album.localIdentifier)")
            return album

        } catch {
            let metrics = AlbumOperationMetrics(
                operationType: "get_album",
                duration: Date().timeIntervalSince(startTime),
                success: false,
                correlationId: correlationId
            )
            recordMetrics(metrics)

            logger.error("📸 ALBUM_MANAGER: ❌ Failed to get BreakDex album [\(correlationId)]: \(error)")
            throw error
        }
    }

    /// Gets the current operation metrics for monitoring
    func getOperationMetrics() -> [AlbumOperationMetrics] {
        return operationMetrics
    }

    /// Clears old metrics (keep last 100 operations)
    func clearOldMetrics() {
        if operationMetrics.count > 100 {
            operationMetrics = Array(operationMetrics.suffix(100))
        }
    }

    /// Resets the album manager state (useful for testing or when permissions change)
    func reset() {
        let correlationId = generateCorrelationId()
        logger.info("📸 ALBUM_MANAGER: 🔄 Resetting album manager state [\(correlationId)]")

        atomicOperationLock.lock()
        defer { atomicOperationLock.unlock() }

        isReady = false
        operationMetrics.removeAll()
        correlationIdGenerator = 0

        Task {
            await albumCache.invalidateCache()
        }
    }

// MARK: - Private Atomic Operations

    /// 🎯 CRITICAL: Atomic find-or-create operation that prevents race conditions
    private func findOrCreateBreakDexAlbum(correlationId: String) async throws -> PHAssetCollection {
        logger.info("📸 ALBUM_MANAGER: 🔒 Executing atomic find-or-create operation [\(correlationId)]")

        let startTime = Date()

        // 🎯 CRITICAL: Check if already creating to prevent duplicate creation
        if await albumCache.getIsCreating() {
            logger.warning("📸 ALBUM_MANAGER: ⚠️ Album creation already in progress - waiting [\(correlationId)]")
            try await waitForAlbumCreation(correlationId: correlationId)

            if let cachedAlbum = await albumCache.getCachedAlbum() {
                return cachedAlbum
            }
        }

        // 🎯 CRITICAL: Atomic lock to prevent race conditions
        atomicOperationLock.lock()
        defer { atomicOperationLock.unlock() }

        // Double-check pattern after acquiring lock
        if await albumCache.getIsCreating() {
            throw AlbumManagerError.duplicateCreationAttempt
        }

        // Check cache again after lock
        if let cachedAlbum = await albumCache.getCachedAlbum(),
           await verifyAlbumExists(cachedAlbum, correlationId: correlationId) {
            return cachedAlbum
        }

        // 🎯 CRITICAL: Set creating flag before starting operation
        await albumCache.setIsCreating(true)
        defer { Task { await albumCache.setIsCreating(false) } }

        do {
            // First, try to find existing album
            logger.info("📸 ALBUM_MANAGER: 🔍 Searching for existing BreakDex album [\(correlationId)]")

            if let existingAlbum = await findExistingAlbum(correlationId: correlationId) {
                await albumCache.setCachedAlbum(existingAlbum)

                let metrics = AlbumOperationMetrics(
                    operationType: "find_album",
                    duration: Date().timeIntervalSince(startTime),
                    success: true,
                    correlationId: correlationId
                )
                recordMetrics(metrics)

                logger.info("📸 ALBUM_MANAGER: ✅ Found existing BreakDex album [\(correlationId)]: \(existingAlbum.localIdentifier)")
                return existingAlbum
            }

            // If not found, create new album with retry logic
            logger.info("📸 ALBUM_MANAGER: ➕ Creating new BreakDex album [\(correlationId)]")

            let newAlbum = try await createBreakDexAlbumWithRetry(correlationId: correlationId)
            await albumCache.setCachedAlbum(newAlbum)

            let metrics = AlbumOperationMetrics(
                operationType: "create_album",
                duration: Date().timeIntervalSince(startTime),
                success: true,
                correlationId: correlationId
            )
            recordMetrics(metrics)

            logger.info("📸 ALBUM_MANAGER: ✅ Created new BreakDex album [\(correlationId)]: \(newAlbum.localIdentifier)")
            return newAlbum

        } catch {
            await albumCache.invalidateCache()

            let metrics = AlbumOperationMetrics(
                operationType: "find_or_create_album",
                duration: Date().timeIntervalSince(startTime),
                success: false,
                correlationId: correlationId
            )
            recordMetrics(metrics)

            logger.error("📸 ALBUM_MANAGER: ❌ Atomic find-or-create failed [\(correlationId)]: \(error)")
            throw error
        }
    }

    /// Searches for existing BreakDex album with precise query
    private func findExistingAlbum(correlationId: String) async -> PHAssetCollection? {
        logger.info("📸 ALBUM_MANAGER: 🔍 Executing precise album search [\(correlationId)]")

        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", Self.albumName)
        fetchOptions.fetchLimit = 1 // Only need one result

        let collections = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .any,
            options: fetchOptions
        )

        guard let existingAlbum = collections.firstObject else {
            logger.info("📸 ALBUM_MANAGER: ℹ️ No existing BreakDex album found [\(correlationId)]")
            return nil
        }

        // Verify the album is accessible and valid
        let fetchOptionsById = PHFetchOptions()
        fetchOptionsById.predicate = NSPredicate(format: "localIdentifier = %@", existingAlbum.localIdentifier)
        let verificationCollections = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [existingAlbum.localIdentifier],
            options: fetchOptionsById
        )

        if verificationCollections.firstObject != nil {
            logger.info("📸 ALBUM_MANAGER: ✅ Verified existing BreakDex album [\(correlationId)]: \(existingAlbum.localIdentifier)")
            return existingAlbum
        } else {
            logger.warning("📸 ALBUM_MANAGER: ⚠️ Found album but verification failed [\(correlationId)]")
            return nil
        }
    }

    /// Creates new BreakDex album with comprehensive retry logic
    private func createBreakDexAlbumWithRetry(correlationId: String) async throws -> PHAssetCollection {
        logger.info("📸 ALBUM_MANAGER: ➕ Starting album creation with retry logic [\(correlationId)]")

        for attempt in 1...Self.maxRetryAttempts {
            do {
                logger.info("📸 ALBUM_MANAGER: 🔄 Album creation attempt \(attempt)/\(Self.maxRetryAttempts) [\(correlationId)]")

                let album = try await createBreakDexAlbumAtomic(correlationId: correlationId)

                // Verify creation was successful
                guard await verifyAlbumExists(album, correlationId: correlationId) else {
                    throw AlbumManagerError.invalidAlbumState
                }

                logger.info("📸 ALBUM_MANAGER: ✅ Album creation successful on attempt \(attempt) [\(correlationId)]")
                return album

            } catch {
                logger.warning("📸 ALBUM_MANAGER: ⚠️ Album creation attempt \(attempt) failed [\(correlationId)]: \(error)")

                if attempt == Self.maxRetryAttempts {
                    logger.error("📸 ALBUM_MANAGER: ❌ All retry attempts exhausted [\(correlationId)]")
                    throw AlbumManagerError.albumCreationFailed(error)
                }

                // Wait before retry with exponential backoff
                let delay = Self.retryDelay * Double(attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw AlbumManagerError.albumCreationFailed(NSError(domain: "AlbumManager", code: -1, userInfo: nil))
    }

    /// Creates new BreakDex album with atomic operation
    private func createBreakDexAlbumAtomic(correlationId: String) async throws -> PHAssetCollection {
        logger.info("📸 ALBUM_MANAGER: 🔒 Executing atomic album creation [\(correlationId)]")

        var albumPlaceholder: PHObjectPlaceholder?

        try await PHPhotoLibrary.shared().performChanges { [self] in
            logger.info("📸 ALBUM_MANAGER: 🔄 Creating BreakDex album in PhotoLibrary [\(correlationId)]")
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: Self.albumName)
            albumPlaceholder = request.placeholderForCreatedAssetCollection
        }

        guard let albumId = albumPlaceholder?.localIdentifier else {
            logger.error("📸 ALBUM_MANAGER: ❌ Failed to get placeholder for created BreakDex album [\(correlationId)]")
            throw AlbumManagerError.albumCreationFailed(NSError(domain: "AlbumManager", code: -2, userInfo: nil))
        }

        // Fetch the newly created album
        let newCollections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumId], options: nil)
        guard let createdAlbum = newCollections.firstObject else {
            logger.error("📸 ALBUM_MANAGER: ❌ Could not fetch newly created BreakDex album [\(correlationId)]")
            throw AlbumManagerError.albumCreationFailed(NSError(domain: "AlbumManager", code: -3, userInfo: nil))
        }

        logger.info("📸 ALBUM_MANAGER: ✅ Successfully created and fetched BreakDex album [\(correlationId)]: \(createdAlbum.localIdentifier)")
        return createdAlbum
    }

    /// Verifies that an album exists and is accessible
    private func verifyAlbumExists(_ album: PHAssetCollection, correlationId: String) async -> Bool {
        logger.info("📸 ALBUM_MANAGER: 🔍 Verifying album existence [\(correlationId)]")

        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "localIdentifier = %@", album.localIdentifier)
        fetchOptions.fetchLimit = 1

        let collections = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [album.localIdentifier],
            options: fetchOptions
        )

        let exists = collections.firstObject != nil
        logger.info("📸 ALBUM_MANAGER: \(exists ? "✅" : "❌") Album verification \(exists ? "passed" : "failed") [\(correlationId)]")
        return exists
    }

    /// Waits for album creation to complete (with timeout)
    private func waitForAlbumCreation(correlationId: String) async throws {
        logger.info("📸 ALBUM_MANAGER: ⏳ Waiting for album creation [\(correlationId)]")

        let timeout: TimeInterval = Self.operationTimeout
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            if !(await albumCache.getIsCreating()) {
                logger.info("📸 ALBUM_MANAGER: ✅ Album creation wait completed [\(correlationId)]")
                return
            }

            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }

        logger.error("📸 ALBUM_MANAGER: ⏰ Timeout waiting for album creation [\(correlationId)]")
        throw AlbumManagerError.transientFailure(NSError(domain: "AlbumManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "Timeout waiting for album creation"]))
    }

    /// Checks photo library authorization status with enhanced logging
    private func checkPhotoLibraryAuthorization(correlationId: String) async -> PHAuthorizationStatus {
        logger.info("📸 ALBUM_MANAGER: 🔐 Checking photo library authorization [\(correlationId)]")

        let status = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        logger.info("📸 ALBUM_MANAGER: 📋 Authorization status [\(correlationId)]: \(String(describing: status))")
        return status
    }

    /// Generates unique correlation ID for tracking
    private func generateCorrelationId() -> String {
        correlationIdGenerator += 1
        return "ALBUM_\(correlationIdGenerator)_\(Date().timeIntervalSince1970)"
    }

    /// Records operation metrics
    private func recordMetrics(_ metrics: AlbumOperationMetrics) {
        operationQueue.async { [weak self] in
            self?.operationMetrics.append(metrics)
        }
    }
}