//
//  BreakingArsenalView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/25/25.
//

import SwiftUI
import BreakingFlashcards

struct BreakingArsenalView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                // Move Section
                NavigationLink("MOVE") {
                    MoveListView()
                }
                // .foregroundColor(Color(red: 61/255, green: 219/255, blue: 217/255)) // #3ddbd9
                .foregroundColor(Color(red: 237/255, green: 245/255, blue: 255/255))
                // Combo Section
                NavigationLink("COMBO") {
                    ComboListView()
                }
                .foregroundColor(Color(red: 237/255, green: 245/255, blue: 255/255)) // #edf5ff

                // REVIEW moved back to dedicated tab in MainView

                // IMPORT / EXPORT removed from arsenal; moved to AddMoveView subtle link
            }
            .font(.ibmPlexMono(size: 36, weight: .bold))
            // .navigationTitle("BREAKING ARSENAL")
            // .navigationBarTitleDisplayMode(.inline)
        }
    }
}
