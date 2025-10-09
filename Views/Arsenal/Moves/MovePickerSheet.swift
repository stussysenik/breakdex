// In MovePickerSheet.swift
import SwiftUI

// MovePickerSheet.swift

struct MovePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    let allMoves: FetchedResults<Move>
    @Binding var selectedMoves: [Move]
    @State private var searchText = ""
    
    var searchResults: [Move] {
        if searchText.isEmpty {
            return Array(allMoves)
        } else {
            return allMoves.filter { $0.name?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
    }
    
    var body: some View {
        NavigationView {
            List(searchResults) { move in
                Button(action: {
                    MotionCatalog.Accessibility.selectionHaptic()
                    MotionCatalog.Accessibility.buttonTap()
                    selectedMoves.append(move)
                    dismiss()
                }) {
                    AvailableMoveRowView(move: move)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Add Move to Combo")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search Moves...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
