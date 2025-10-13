// import SwiftUI
// import PhotosUI
// import OSLog
// import UniformTypeIdentifiers

// // MARK: - Movie Transferable Type (iOS 18.0 Optimized)
// // Primary video transfer type for optimal performance
// public struct Movie: Transferable {
//     let url: URL
    
//     // Progress tracking for iCloud downloads
//     public private(set) var downloadProgress: Progress?
    
//     private static let logger = Logger(subsystem: "com.breakingflashcards", category: "MovieTransferable")
    
//     // Initialize with progress tracking
//     public init(url: URL, downloadProgress: Progress? = nil) {
//         self.url = url
//         self.downloadProgress = downloadProgress
//     }
    
//     // Create a Movie with iCloud download progress tracking
//     public static func withICloudDownload(url: URL, progress: Progress) -> Movie {
//         return Movie(url: url, downloadProgress: progress)
//     }
    
//     // Monitor download progress with completion handler
//     public func monitorDownloadProgress(interval: TimeInterval = 0.001, onUpdate: @escaping (Double) -> Void) {
//         guard let progress = downloadProgress else {
//             onUpdate(1.0) // Already downloaded
//             return
//         }
        
//         var timer: Timer?
//         timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
//             let fractionCompleted = progress.fractionCompleted
//             onUpdate(fractionCompleted)
            
//             if fractionCompleted >= 1.0 {
//                 timer?.invalidate()
//             }
//         }
        
//         // Keep timer reference to prevent immediate deallocation
//         timer?.tolerance = interval * 0.1
//     }
    
//     public static var transferRepresentation: some TransferRepresentation {
//         FileRepresentation(contentType: .movie) { movie in
//             logger.info("📤 Movie: Sending file for transfer - URL: \(movie.url.path)")
//             logger.info("📤 Movie: File exists: \(FileManager.default.fileExists(atPath: movie.url.path))")
//             let fileSize: Int64 = (try? FileManager.default.attributesOfItem(atPath: movie.url.path)[.size] as? Int64) ?? 0
//             logger.info("📤 Movie: File size: \(fileSize) bytes")
//             return SentTransferredFile(movie.url)
//         } importing: { received in
//             logger.info("📥 Movie: Starting file import process")
//             logger.info("📥 Movie: Received file - URL: \(received.file.path)")
//             logger.info("📥 Movie: Received file exists: \(FileManager.default.fileExists(atPath: received.file.path))")
//             logger.info("📥 Movie: File path extension: \(received.file.pathExtension)")
//             logger.info("📥 Movie: File content type: movie")
            
//             // Log file attributes
//             do {
//                 let attributes = try FileManager.default.attributesOfItem(atPath: received.file.path)
//                 logger.info("📥 Movie: File size: \(attributes[.size] as? Int64 ?? 0) bytes")
//                 logger.info("📥 Movie: File creation date: \(attributes[.creationDate] as? Date ?? Date.distantPast)")
//             } catch {
//                 logger.error("📥 Movie: Failed to get file attributes: \(error.localizedDescription)")
//             }
            
//             let copy = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).\(received.file.pathExtension)")
//             logger.info("📥 Movie: Creating copy at: \(copy.path)")
            
//             do {
//                 // Log additional debugging information
//                 logger.info("📥 Movie: Starting security scoped resource access")
//                 logger.info("📥 Movie: Source file scheme: \(received.file.scheme ?? "unknown")")
//                 logger.info("📥 Movie: Source file is file URL: \(received.file.isFileURL)")
                
//                 // Check if the resource is reachable before accessing
//                 do {
//                     guard try received.file.checkResourceIsReachable() else {
//                         logger.error("📥 Movie: ❌ Source file is not reachable")
//                         throw NSError(domain: "MovieTransferable", code: -3,
//                                      userInfo: [NSLocalizedDescriptionKey: "Source file is not reachable"])
//                     }
//                 } catch {
//                     logger.error("📥 Movie: ❌ Source file reachability check failed: \(error.localizedDescription)")
//                     throw NSError(domain: "MovieTransferable", code: -3,
//                                  userInfo: [NSLocalizedDescriptionKey: "Source file is not reachable"])
//                 }
                
//                 // Start accessing security scoped resource BEFORE file operations
//                 let needsAccess = received.file.startAccessingSecurityScopedResource()
//                 logger.info("📥 Movie: Security scoped resource access started: \(needsAccess)")
                
//                 if !needsAccess {
//                     logger.info("📥 Movie: ⚠️ Failed to start accessing security scoped resource - trying fallback approaches")
                    
//                     // Approach 1: Check if the file is already in our container
//                     let appContainerURLs = [
//                         FileManager.default.temporaryDirectory,
//                         FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: "/"),
//                         FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: "/")
//                     ]
                    
//                     let isInAppContainer = appContainerURLs.contains { received.file.path.hasPrefix($0.path) }
                    
//                     if isInAppContainer {
//                         logger.info("📥 Movie: ✅ File is in app container, proceeding without security scope")
//                     } else {
//                         // Approach 2: Try to access without security scope (some iOS versions allow this)
//                         logger.info("📥 Movie: 🔄 Attempting direct file access without security scope")
                        
//                         // Try to read file attributes to test accessibility
//                         do {
//                             let _ = try FileManager.default.attributesOfItem(atPath: received.file.path)
//                             logger.info("📥 Movie: ✅ Direct file access successful, proceeding")
//                         } catch {
//                             logger.error("📥 Movie: ❌ Direct file access failed: \(error.localizedDescription)")
//                             throw NSError(domain: "MovieTransferable", code: -1, 
//                                          userInfo: [NSLocalizedDescriptionKey: "Failed to access security scoped resource and direct access also failed"])
//                         }
//                     }
//                 }
                
//                 // Ensure we stop accessing when done
//                 defer {
//                     if needsAccess {
//                         received.file.stopAccessingSecurityScopedResource()
//                         logger.info("📥 Movie: ✅ Security scoped resource access stopped")
//                     }
//                 }
                
//                 logger.info("📥 Movie: ✅ Security scoped resource access started, beginning file copy")
                
//                 // Use FileManager with better error handling
//                 do {
//                     try FileManager.default.copyItem(at: received.file, to: copy)
//                 } catch {
//                     logger.error("📥 Movie: ❌ Standard copy failed: \(error.localizedDescription)")
                    
//                     // Fallback: Try using NSData reading for more robust file access
//                     do {
//                         let fileData = try Data(contentsOf: received.file)
//                         try fileData.write(to: copy)
//                         logger.info("📥 Movie: ✅ Fallback copy using Data succeeded")
//                     } catch {
//                         logger.error("📥 Movie: ❌ Fallback copy also failed: \(error.localizedDescription)")
//                         throw NSError(domain: "MovieTransferable", code: -5,
//                                      userInfo: [NSLocalizedDescriptionKey: "All file copy methods failed"])
//                     }
//                 }
//                 logger.info("📥 Movie: ✅ File copied successfully")
//                 logger.info("📥 Movie: Copy exists: \(FileManager.default.fileExists(atPath: copy.path))")
                
//                 let copyAttributes = try FileManager.default.attributesOfItem(atPath: copy.path)
//                 logger.info("📥 Movie: Copy file size: \(copyAttributes[.size] as? Int64 ?? 0) bytes")
                
//                 // Verify the copied file is accessible and readable
//                 guard FileManager.default.isReadableFile(atPath: copy.path) else {
//                     logger.error("📥 Movie: ❌ Copied file is not readable")
//                     throw NSError(domain: "MovieTransferable", code: -2,
//                                  userInfo: [NSLocalizedDescriptionKey: "Copied file is not accessible"])
//                 }
                
//                 // Verify the copied file has content
//                 let fileSize = copyAttributes[.size] as? Int64 ?? 0
//                 guard fileSize > 0 else {
//                     logger.error("📥 Movie: ❌ Copied file is empty")
//                     throw NSError(domain: "MovieTransferable", code: -4,
//                                  userInfo: [NSLocalizedDescriptionKey: "Copied file is empty"])
//                 }
                
//                 logger.info("📥 Movie: ✅ File validation completed successfully")
//                 return Movie(url: copy, downloadProgress: nil)
//             } catch {
//                 logger.error("📥 Movie: ❌ Failed to copy file: \(error.localizedDescription)")
//                 logger.error("📥 Movie: Error domain: \((error as NSError).domain), code: \((error as NSError).code)")
//                 throw error
//             }
//         }
//     }
// }

// // MARK: - Import Error
// public enum ImportError: Error, LocalizedError {
//     case unsupportedType
//     case fileOperationFailed(Error)
    
//     public var errorDescription: String? {
//         switch self {
//         case .unsupportedType:
//             return "Unsupported file type. Please select a video file."
//         case .fileOperationFailed(let error):
//             return "Failed to process video file: \(error.localizedDescription)"
//         }
//     }
// }