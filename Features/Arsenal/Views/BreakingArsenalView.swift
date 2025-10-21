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
            VStack(spacing: 0) {
                // Move List Section (Primary content)
                MoveListView(onNavigateToAdd: {
                    Logger.main.info("🏠 ARSENAL_NAVIGATION: Navigate to Add Move tab from MoveListView", emoji: "🏠")
                    Logger.main.info("🔍 ARSENAL_DEBUG: selectedTab changing from \(selectedTab) to 1")
                    selectedTab = 1 // Switch to Add Move tab
                    Logger.main.info("✅ ARSENAL_NAVIGATION: Successfully switched to Add Move tab")
                })

                // Fixed Bottom Section with Combo
                VStack(spacing: 20) {
                    Divider()
                        .background(Color.textSecondary.opacity(0.3))

                    HStack(spacing: 40) {
                        Spacer()

                        // Combo Section (reduced size)
                        NavigationLink {
                            ComboListView()
                        } label: {
                            Text("COMBOS")
                                .font(.ibmPlexMono(size: 24, weight: .semibold))
                                .foregroundColor(.textSecondary)
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.bottom, 20)
                }
                .background(Color.backgroundPrimary)
            }
            .navigationTitle("Moves")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .onAppear {
                Logger.main.info("🎯 ARSENAL_APPEARED: BreakingArsenalView appeared - user navigated back to Arsenal tab", emoji: "🎯")
                Logger.main.info("🔍 ARSENAL_DEBUG: Current selectedTab = \(selectedTab)")
                Logger.main.info("🎯 ARSENAL_EXPECTED: Move list should refresh and show newly saved moves")
            }
        }
    }
}
