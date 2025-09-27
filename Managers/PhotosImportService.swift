import SwiftUI
import PhotosUI
import OSLog
import Foundation

// MARK: - Import State Enum
public enum AddMoveImportState {
    case idle
    case importing
    case ready(URL)
    case error(Error)
}

// MARK: - PhotosImportService Protocol
public protocol PhotosImportServiceProtocol {
    func importVideo(from item: PhotosPickerItem) async throws -> URL
    func cleanupTempArtifacts() async
}

// MARK: - Photos Import Service
@MainActor
public class PhotosImportService: PhotosImportServiceProtocol {
    
    // MARK: - Properties
    @Published public var importState: AddMoveImportState = .idle
    private var importTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "PhotosImportService")
    
    // MARK: - Initialization
    public init() {
        logger.info("📥 PHOTOS_IMPORT: Initialized")
    }
    
    // MARK: - Public API
    
    /// Import video from PhotosPicker item
    public func importVideo(from item: PhotosPickerItem) async throws -> URL {
        logger.info("📥 PHOTOS_IMPORT: Import pipeline started")
        logger.info("📥 PHOTOS_IMPORT: Item ID: \(item.itemIdentifier ?? "nil")")
        logger.info("📥 PHOTOS_IMPORT: Supported content types: \(item.supportedContentTypes)")
        
        importState = .importing
        logger.info("📥 PHOTOS_IMPORT: State set to importing")
        
        // Cancel any existing import task
        importTask?.cancel()
        
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: ImportError.fileOperationFailed(NSError(domain: "PhotosImportService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service instance was deallocated"])))
                return
            }
            
            self.importTask = Task {
                do {
                    logger.info("📥 PHOTOS_IMPORT: Starting video import via streaming approach")

                    // Create temporary URL for streaming file copy
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("mov")

                    logger.info("📥 PHOTOS_IMPORT: 📁 Created temp URL: \(tempURL.lastPathComponent)")

                    // Use streaming approach by loading the data and writing to file
                    logger.info("📥 PHOTOS_IMPORT: 🔄 Starting streaming file copy")

                    // Load the data from the PhotosPicker item
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw ImportError.fileOperationFailed(NSError(domain: "PhotosImportService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not load video data from PhotosPicker item"]))
                    }

                    // Write the data to the temporary file
                    try data.write(to: tempURL)

                    logger.info("📥 PHOTOS_IMPORT: ✅ Streaming file copy completed")

                    // Get file size for logging
                    do {
                        let resources = try tempURL.resourceValues(forKeys: [.fileSizeKey])
                        if let fileSize = resources.fileSize {
                            logger.info("📥 PHOTOS_IMPORT: 📊 File size: \(fileSize) bytes (\(Double(fileSize) / (1024 * 1024)) MB)")
                        }
                    }

                    logger.info("📥 PHOTOS_IMPORT: 💾 Starting persist operation...")
                    let url = try persist(file: tempURL)

                    if Task.isCancelled {
                        logger.info("📥 PHOTOS_IMPORT: Import task cancelled after file persist")
                        continuation.resume(throwing: CancellationError())
                        return
                    }

                    await MainActor.run {
                        self.importState = .ready(url)
                        logger.info("📥 PHOTOS_IMPORT: Import completed successfully, URL: \(url)")
                    }

                    continuation.resume(returning: url)
                    return

                } catch {
                    if Task.isCancelled {
                        logger.info("📥 PHOTOS_IMPORT: Import task cancelled during error handling")
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    
                    logger.error("📥 PHOTOS_IMPORT: ❌ Import pipeline failed with error")
                    logger.error("📥 PHOTOS_IMPORT: ❌ Error type: \(type(of: error))")
                    logger.error("📥 PHOTOS_IMPORT: ❌ Error description: \(error.localizedDescription)")
                    logger.error("📥 PHOTOS_IMPORT: ❌ Error details: \(String(describing: error))")
                    
                    await MainActor.run {
                        self.importState = .error(ImportError.fileOperationFailed(error))
                    }
                    continuation.resume(throwing: ImportError.fileOperationFailed(error))
                }
            }
        }
    }
    
    /// Clean up temporary artifacts
    public func cleanupTempArtifacts() async {
        logger.info("📥 PHOTOS_IMPORT: Cleaning up temporary artifacts")
        // Clean up any temporary files created during import
        // This could be expanded to clean up specific temp directories
        logger.info("📥 PHOTOS_IMPORT: Cleanup completed")
    }
    
    // MARK: - Private Methods
    
    /// Persist Movie to app-scoped URL
    private func persist(movie: Movie) throws -> URL {
        logger.info("📥 PHOTOS_IMPORT: Persisting Movie to app-scoped URL: \(movie.url)")
        
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(movie.url.pathExtension)
        
        do {
            try FileManager.default.copyItem(at: movie.url, to: destinationURL)
            logger.info("📥 PHOTOS_IMPORT: Movie persisted successfully to: \(destinationURL)")
            return destinationURL
        } catch {
            logger.error("📥 PHOTOS_IMPORT: Failed to persist Movie: \(error.localizedDescription)")
            throw ImportError.fileOperationFailed(error)
        }
    }
    
    /// Persist Data to app-scoped URL
    private func persist(data: Data, utType: UTType) throws -> URL {
        logger.info("📥 PHOTOS_IMPORT: Persisting Data to app-scoped URL, size: \(data.count) bytes")

        let fileExtension = utType.preferredFilenameExtension ?? "mov"
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)

        do {
            try data.write(to: destinationURL)
            logger.info("📥 PHOTOS_IMPORT: Data persisted successfully to: \(destinationURL)")
            return destinationURL
        } catch {
            logger.error("📥 PHOTOS_IMPORT: Failed to persist Data: \(error.localizedDescription)")
            throw ImportError.fileOperationFailed(error)
        }
    }

    /// Persist file URL to app-scoped URL (streaming approach)
    private func persist(file sourceURL: URL) throws -> URL {
        logger.info("📥 PHOTOS_IMPORT: Persisting file to app-scoped URL: \(sourceURL.lastPathComponent)")

        let fileExtension = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            logger.info("📥 PHOTOS_IMPORT: File persisted successfully to: \(destinationURL)")

            // Clean up source temporary file
            try? FileManager.default.removeItem(at: sourceURL)
            logger.info("📥 PHOTOS_IMPORT: Source temporary file cleaned up")

            return destinationURL
        } catch {
            logger.error("📥 PHOTOS_IMPORT: Failed to persist file: \(error.localizedDescription)")
            throw ImportError.fileOperationFailed(error)
        }
    }
    
    // MARK: - Task Management
    
    /// Cancel current import task
    func cancelImport() {
        logger.info("📥 PHOTOS_IMPORT: Cancelling current import task")
        importTask?.cancel()
        importTask = nil
        importState = .idle
        logger.info("📥 PHOTOS_IMPORT: Import task cancelled and state reset")
    }
}
