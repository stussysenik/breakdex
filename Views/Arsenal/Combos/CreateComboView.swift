// In CreateComboView.swift
import SwiftUI
import AVKit

struct CreateComboView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Move.createdAt, ascending: true)])
    private var allMoves: FetchedResults<Move>

    @State private var comboMoves: [Move] = []
    @State private var activeNodeIndex: Int? = nil
    @State private var isMovePickerPresented = false
    @State private var isNamingAlertPresented = false
    @State private var comboName = ""
    @State private var showSuccessMessage = false
    @State private var showErrorMessage = false
    @State private var successMessage = ""
    @State private var errorMessage = ""

    private func getVideoAsset(for move: Move) -> AVAsset? {
        guard let videoData = move.videoReference,
              let path = String(data: videoData, encoding: .utf8) else {
            return nil
        }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        return AVURLAsset(url: url)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Button("+ Create Combo") {
                MotionCatalog.Accessibility.buttonTap()
                MotionCatalog.Accessibility.actionHaptic()
                isMovePickerPresented = true
            }
            .font(.ibmPlexMono(size: 20, weight: .regular))
            .padding(.vertical, 40)
            .padding(.horizontal, 20)
            
            if let activeMove = activeMove { // middle section: video player or empty state
                if let asset = getVideoAsset(for: activeMove) {
                    CustomVideoPlayerView(viewModel: MainVideoPlayerViewModel(asset: asset, rotationQuarterTurns: Int(activeMove.rotationQuarterTurns), appContainer: AppContainer.shared))
                        .frame(height: 300)
                        .id(activeMove.managedObjectID) // Force re-initialization when activeMove changes
                } else {
                    ContentUnavailableView("Video not available", systemImage: "video.slash")
                        .frame(height: 300)
                }
            } else {
                ContentUnavailableView("No preview available", systemImage: "video.slash")
                    .frame(height: 300)
            }
            
            VStack(spacing: 16) {   // bottom Section: timeline group
                Text("COMBO SEQUENCE")
                    .font(.ibmPlexMono(size: 18, weight: .bold))
                    .foregroundColor(.textPrimary)
                
                ComboTimelineView(moves: $comboMoves, activeIndex: $activeNodeIndex)
                    .frame(height: 120)
                
                Button("Save Combo") {
                    MotionCatalog.Accessibility.actionHaptic()
                    MotionCatalog.Accessibility.successHaptic()
                    isNamingAlertPresented = true
                }
                .font(.custom("IBMPlexMono-Regular", size: 18)) // IBM Plex Mono font
                .buttonStyle(.appAccent(size: .large))
                .disabled(comboMoves.isEmpty)
                
                Spacer(minLength: 20)
            }
        }
        .sheet(isPresented: $isMovePickerPresented) {
            MovePickerSheet(allMoves: allMoves, selectedMoves: $comboMoves)
        }
        .alert("Name Your Combo", isPresented: $isNamingAlertPresented) { // alert dialog
            TextField("Combo Name", text: $comboName)
            Button("Cancel", role: .cancel) {
                comboName = ""
            }
            Button("Save") {
                saveCombo(name: comboName.isEmpty ? "Combo \(Date().formatted(date: .abbreviated, time: .shortened))" : comboName)
                comboName = ""
            }
        } message: {
            Text("Enter a name for your combo to save it.")
        }
        .alert("Success", isPresented: $showSuccessMessage) {
            Button("OK") { showSuccessMessage = false }
        } message: {
            Text(successMessage)
        }
        .alert("Error", isPresented: $showErrorMessage) {
            Button("OK") { showErrorMessage = false }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var activeMove: Move? {
        guard let activeNodeIndex, !comboMoves.isEmpty, comboMoves.indices.contains(activeNodeIndex) else {
            return nil
        }
        return comboMoves[activeNodeIndex]
    }
    
    private func videoURL(for move: Move) -> URL {
        let path = String(data: move.videoReference ?? Data(), encoding: .utf8) ?? "" // based on model data
        return URL(filePath: path)
    }
    
    private func saveCombo(name: String) {
        let newCombo = Combo(context: viewContext)
        // Note: We don't set the id as it's managed by Core Data
        newCombo.name = name
        
        for (index, move) in comboMoves.enumerated() {
            let comboMove = ComboMove(context: viewContext)
            // Note: We don't set the id as it's managed by Core Data
            comboMove.sequenceIndex = Int64(index)
            comboMove.move = move
            comboMove.combo = newCombo
        }
        
        do {
            try viewContext.save()
            successMessage = "Combo '\(name)' created successfully!" // success message
            showSuccessMessage = true
            
            comboMoves.removeAll() // reset combo after saving
            activeNodeIndex = nil
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { // auto-hide success message after 3 seconds
                showSuccessMessage = false
            }
        } catch {
            print("Error saving combo: \(error)")
            errorMessage = "Failed to save combo. Please try again."
            showErrorMessage = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showErrorMessage = false
            }
        }
    }
}

#Preview {
    CreateComboView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
