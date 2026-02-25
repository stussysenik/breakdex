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

    var body: some View {
        VStack(spacing: 0) {
            // Add Move button at top
            Button(action: { isMovePickerPresented = true }) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                    Text("ADD MOVE TO COMBO")
                        .font(.ibmPlexMono(size: 14, weight: .bold))
                }
                .foregroundColor(.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)

            // Video Player or Empty State
            if let activeMove = activeMove {
                CustomVideoPlayerView(move: activeMove)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
            } else {
                ContentUnavailableView("Select a move to see a preview", systemImage: "video.slash")
                    .frame(height: 220)
                    .padding(.top, Spacing.md)
            }

            // Timeline Group
            VStack(spacing: Spacing.md) {
                // Section label
                Text("SEQUENCE")
                    .font(.caption)
                    .tracking(2)
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.lg)

                ComboTimelineView(moves: $comboMoves, activeIndex: $activeNodeIndex)
                    .frame(height: 120)

                // Save Button — full-width styled
                Button(action: { isNamingAlertPresented = true }) {
                    Text("SAVE COMBO")
                        .font(.ibmPlexMono(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(comboMoves.isEmpty ? Color.neutralFill : Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .disabled(comboMoves.isEmpty)
                .padding(.horizontal, Spacing.lg)

                Spacer(minLength: Spacing.lg)
            }
            .padding(.top, Spacing.md)
        }
        .appMotion(comboMoves.count)
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
            successMessage = "Combo '\(name)' created successfully!"
            showSuccessMessage = true
            comboMoves.removeAll()
            activeNodeIndex = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
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
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
