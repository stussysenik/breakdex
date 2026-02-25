//
//  BreakingArsenalView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/25/25.
//

import SwiftUI

struct BreakingArsenalView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                NavigationLink(destination: MoveListView()) {
                    arsenalCard(
                        icon: "figure.dance",
                        tint: .stateNew,
                        title: "Moves",
                        subtitle: "Individual techniques"
                    )
                }

                NavigationLink(destination: ComboListView()) {
                    arsenalCard(
                        icon: "square.stack.3d.up",
                        tint: .accent,
                        title: "Combos",
                        subtitle: "Linked sequences"
                    )
                }
            }
            .padding(.horizontal, Spacing.lg)
            .frame(maxHeight: .infinity, alignment: .center)
            .background(Color.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("BREAKING ARSENAL")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func arsenalCard(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(tint)
                .frame(width: 48, height: 48)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.ibmPlexMono(size: 18, weight: .bold))
                    .foregroundColor(.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .padding(Spacing.md)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .elevation(Elevation.low)
    }
}
