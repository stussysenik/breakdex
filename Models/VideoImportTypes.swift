import SwiftUI
import PhotosUI

// MARK: - Selection State (PhotosPicker Import)
public enum SelectionState {
    case idle
    case importing
    case ready(URL)
    case error(Error)
}

// MARK: - Movie Transferable Type
public struct Movie: Transferable {
    let url: URL
    
    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).\(received.file.pathExtension)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Movie(url: copy)
        }
    }
}

// MARK: - Import Error
public enum ImportError: Error, LocalizedError {
    case unsupportedType
    case fileOperationFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "Unsupported file type. Please select a video file."
        case .fileOperationFailed(let error):
            return "Failed to process video file: \(error.localizedDescription)"
        }
    }
}