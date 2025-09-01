// In CreateComboView.swift
import SwiftUI
import AVKit
import BreakingFlashcards

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

    var body: some View {
        VStack(spacing: 6) {
            // Top Section: Add Move Button
            Button("+ Create Combo") {
                isMovePickerPresented = true
            }
            .font(.ibmPlexMono(size: 20, weight: .thin))
            .padding(.vertical, 40)
            .padding(.horizontal, 20)

            // Middle Section: Video Player or Empty State
            if let activeMove = activeMove {
                CustomVideoPlayerView(move: activeMove, url: nil)
                    .frame(height: 300)
            } else {
                ContentUnavailableView("No preview available", systemImage: "video.slash")
                    .frame(height: 300)
            }

            // Bottom Section: Timeline Group (moved closer to video)
            VStack(spacing: 16) {
                Text("COMBO SEQUENCE")
                    .font(.ibmPlexMono(size: 18, weight: .bold))
                    .foregroundColor(.textPrimary)

                ComboTimelineView(moves: $comboMoves, activeIndex: $activeNodeIndex)
                    .frame(height: 120)

                // Final Action: Save Button - moved closer to timeline
                Button("Save Combo") {
                    isNamingAlertPresented = true
                }
                .font(.ibmPlexMono(size: 18, weight: .regular))
                .buttonStyle(.borderedProminent)
                .tint(.accent)
                // .controlSize(.large)
                .disabled(comboMoves.isEmpty)
                // .padding(.horizontal, 40)
                // .padding(.top, 20)
                
                Spacer(minLength: 20)
            }
            // .padding(.top, 16)
            // .padding(.bottom, 24)
        }
        .sheet(isPresented: $isMovePickerPresented) {
            MovePickerSheet(allMoves: allMoves, selectedMoves: $comboMoves)
        }
        .alert("Name Your Combo", isPresented: $isNamingAlertPresented) {
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
        // This assumes videoReference stores a string path. Adapt if it stores raw bookmark data.
        let path = String(data: move.videoReference ?? Data(), encoding: .utf8) ?? ""
        return URL(filePath: path)
    }

    private func saveCombo(name: String) {
        let newCombo = Combo(context: viewContext)
        newCombo.id = UUID()
        newCombo.name = name

        for (index, move) in comboMoves.enumerated() {
            let comboMove = ComboMove(context: viewContext)
            comboMove.id = UUID()
            comboMove.sequenceIndex = Int64(index)
            comboMove.move = move
            comboMove.combo = newCombo
        }

        do {
            try viewContext.save()
            // Show success message
            successMessage = "Combo '\(name)' created successfully!"
            showSuccessMessage = true
            
            // Reset the combo after saving
            comboMoves.removeAll()
            activeNodeIndex = nil
            
            // Auto-hide success message after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showSuccessMessage = false
            }
        } catch {
            print("Error saving combo: \(error)")
            errorMessage = "Failed to save combo. Please try again."
            showErrorMessage = true
            
            // Auto-hide error message after 3 seconds
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