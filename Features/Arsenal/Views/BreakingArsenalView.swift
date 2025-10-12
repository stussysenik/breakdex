//
//  BreakingArsenalView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/25/25.
//

import SwiftUI
import Foundation

// MARK: - Tab Selection Enum

struct BreakingArsenalView: View {
    @Binding var selectedTab: Int

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                // Move Section
                Button {
                    selectedTab = 1 // Switch to Add Move tab
                } label: {
                    Text("MOVE")
                        .font(.ibmPlexMono(size: 42, weight: .bold))
                        .foregroundColor(.textPrimary)
                }
                .buttonStyle(.plain)

                // Combo Section
                NavigationLink {
                    ComboListView()
                } label: {
                    Text("COMBO")
                        .font(.ibmPlexMono(size: 42, weight: .bold))
                        .foregroundColor(.textPrimary)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            // .toolbarBackground(.visible, for: .navigationBar)
            // .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        }
    }
}
