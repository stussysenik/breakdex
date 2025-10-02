import SwiftUI
import UniformTypeIdentifiers
import CoreData
import Photos

enum ExportError: Error, LocalizedError {
    case albumAccessFailed(String)

    var errorDescription: String? {
        switch self {
        case .albumAccessFailed(let message):
            return message
        }
    }
}

struct ImportExportView: View {
    @State private var exportURL: URL? = nil
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var importStatus: String? = nil
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var importResults: ImportResults? = nil
    
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - Export/Import Data Structures
    
    struct LearningLibraryExport: Codable {
        let moves: [MoveExport]
        let combos: [ComboExport]
        let breakDexAlbumIdentifier: String?
        let exportDate: Date
        let appVersion: String
    }
    
    struct MoveExport: Codable {
        let id: UUID
        let name: String
        let photosIdentifier: String?
        let trimStartTime: Double
        let trimEndTime: Double
        let learningState: String
        let createdAt: Date
        let reviewCount: Int
    }
    
    struct ComboExport: Codable {
        let id: UUID
        let name: String
        let createdAt: Date
        let moveIds: [UUID]
    }
    
    struct ImportResults {
        let successfullyImported: Int
        let needsRelinking: Int
        let totalMoves: Int
        let relinkQueue: [MoveExport]
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Button {
                    Task {
                        await exportLearningLibrary()
                    }
                } label: {
                    if isExporting {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("Export Library JSON").font(.ibmPlexMono(size: 18, weight: .thin))
                    }
                }
                .disabled(isExporting)
                .buttonStyle(.borderedProminent)
                .fileExporter(isPresented: $showingExporter, document: exportURL.map { URLDocument(url: $0) }, contentType: .json, defaultFilename: exportURL?.lastPathComponent ?? "LibraryExport.json") { _ in }
                
                Button {
                    showingImporter = true
                } label: {
                    if isImporting {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("Import Library JSON").font(.ibmPlexMono(size: 18, weight: .thin))
                    }
                }
                .disabled(isImporting)
                .buttonStyle(.bordered)
                .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                    Task {
                        await handleImport(result: result)
                    }
                }
                
                if let importStatus = importStatus {
                    Text(importStatus)
                        .font(.ibmPlexMono(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                if let results = importResults {
                    VStack(spacing: 8) {
                        Text("Import Results")
                            .font(.ibmPlexMono(size: 14, weight: .medium))
                        HStack {
                            VStack(alignment: .leading) {
                                Text("✅ Imported: \(results.successfullyImported)")
                                Text("🔄 Needs re-linking: \(results.needsRelinking)")
                                Text("📊 Total: \(results.totalMoves)")
                            }
                            .font(.ibmPlexMono(size: 12))
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            // .navigationTitle("Library")
        }
    }
    
    // MARK: - Export Implementation
    
    private func exportLearningLibrary() async {
        isExporting = true
        importStatus = "Exporting learning library..."
        
        defer { isExporting = false }
        
        do {
            let exportData = try await createExportData()
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let jsonData = try encoder.encode(exportData)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("BreakDex_Library_\(Date().formatted(.iso8601.dateSeparator(.dash))).json")
            
            try jsonData.write(to: tempURL)
            exportURL = tempURL
            showingExporter = true
            importStatus = "Library exported successfully!"
            
        } catch {
            importStatus = "Export failed: \(error.localizedDescription)"
        }
    }
    
    private func createExportData() async throws -> LearningLibraryExport {
        let context = viewContext
        
        // Get BreakDex album identifier
        let breakDexAlbum: PHAssetCollection
        do {
            breakDexAlbum = try await AlbumManager.shared.getBreakDexAlbum()
        } catch {
            throw ExportError.albumAccessFailed("Failed to access BreakDex album: \(error.localizedDescription)")
        }
        let breakDexAlbumId = breakDexAlbum.localIdentifier
        
        // Fetch all moves synchronously in Core Data context
        let moveExports = try await context.perform {
            let moveRequest = Move.fetchRequest()
            let moves = try context.fetch(moveRequest)
            
            return moves.map { move in
                MoveExport(
                    id: move.id ?? UUID(),
                    name: move.name ?? "Unnamed Move",
                    photosIdentifier: move.photosIdentifier,
                    trimStartTime: move.trimStartTime,
                    trimEndTime: move.trimEndTime,
                    learningState: move.learningState ?? "NEW",
                    createdAt: move.createdAt ?? Date(),
                    reviewCount: move.reviews?.count ?? 0
                )
            }
        }
        
        // Fetch all combos (if they exist)
        let comboExports: [ComboExport] = [] // TODO: Implement combo export if needed
        
        return LearningLibraryExport(
            moves: moveExports,
            combos: comboExports,
            breakDexAlbumIdentifier: breakDexAlbumId,
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
    }
    
    // MARK: - Import Implementation
    
    private func handleImport(result: Result<URL, Error>) async {
        switch result {
        case .success(let url):
            await importLearningLibrary(from: url)
        case .failure(let error):
            importStatus = "Import cancelled: \(error.localizedDescription)"
        }
    }
    
    private func importLearningLibrary(from url: URL) async {
        isImporting = true
        importStatus = "Importing learning library..."
        
        defer { isImporting = false }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let exportData = try decoder.decode(LearningLibraryExport.self, from: data)
            
            let results = try await processImportData(exportData)
            importResults = results
            
            if results.needsRelinking > 0 {
                importStatus = "Import completed with \(results.needsRelinking) moves needing re-linking"
            } else {
                importStatus = "Import completed successfully!"
            }
            
        } catch {
            importStatus = "Import failed: \(error.localizedDescription)"
        }
    }
    
    private func processImportData(_ exportData: LearningLibraryExport) async throws -> ImportResults {
        let context = viewContext
        var successfullyImported = 0
        var needsRelinking: [MoveExport] = []
        
        for moveData in exportData.moves {
            if await videoExistsInBreakDex(moveData.photosIdentifier) {
                // Video exists, create move directly
                try await createMoveFromImport(moveData, context: context)
                successfullyImported += 1
            } else {
                // Video missing, add to relink queue
                needsRelinking.append(moveData)
            }
        }
        
        return ImportResults(
            successfullyImported: successfullyImported,
            needsRelinking: needsRelinking.count,
            totalMoves: exportData.moves.count,
            relinkQueue: needsRelinking
        )
    }
    
    private func videoExistsInBreakDex(_ photosIdentifier: String?) async -> Bool {
        guard let identifier = photosIdentifier else { return false }
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return fetchResult.firstObject != nil
    }
    
    private func createMoveFromImport(_ moveData: MoveExport, context: NSManagedObjectContext) async throws {
        try await context.perform {
            let newMove = Move(context: context)
            // Note: We don't set the managedObjectID as it's read-only and managed by Core Data
            newMove.name = moveData.name
            newMove.photosIdentifier = moveData.photosIdentifier
            newMove.trimStartTime = moveData.trimStartTime
            newMove.trimEndTime = moveData.trimEndTime
            newMove.learningState = moveData.learningState
            newMove.createdAt = moveData.createdAt
            
            try context.save()
        }
    }
}

struct URLDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var url: URL
    init(url: URL) { self.url = url }
    init(configuration: ReadConfiguration) throws { self.url = URL(fileURLWithPath: "") }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return try FileWrapper(url: url, options: .immediate)
    }
}


