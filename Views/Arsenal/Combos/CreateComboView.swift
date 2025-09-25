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
        // 🎯 FIXED: Use photosIdentifier instead of deprecated videoReference
        guard let photosIdentifier = move.photosIdentifier else {
            return nil
        }

        // Use synchronous check for asset existence first
        guard PhotosAssetLoader.assetExists(with: photosIdentifier) else {
            return nil
        }

        // For UI purposes, we'll create a simple AVAsset placeholder
        // The actual video loading will happen asynchronously in the player
        // This is a temporary solution for UI compatibility
        return AVAsset(url: URL(string: "photos://\(photosIdentifier)")!)
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
                    CustomVideoPlayerView(viewModel: UnifiedVideoPlayerViewModel(player: AVPlayer(playerItem: AVPlayerItem(asset: asset)), mode: .main, appContainer: AppContainer.shared))
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
        // 🎯 FIXED: Use photosIdentifier instead of deprecated videoReference
        // Since we're using Photos library, we can't directly get a file URL
        // Return a placeholder URL or handle this case appropriately
        guard let photosIdentifier = move.photosIdentifier else {
            return URL(fileURLWithPath: "")
        }

        // For now, return a placeholder - this method may need to be redesigned
        // since Photos assets don't have direct file URLs
        return URL(fileURLWithPath: "photos://\(photosIdentifier)")
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
