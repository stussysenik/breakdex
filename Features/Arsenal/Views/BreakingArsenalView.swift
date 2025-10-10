//
//  BreakingArsenalView.swift
//  BreakingFlashcards
//
//  Created by Claude Code on 10/10/25.
//  Migrated to clean architecture in Features/Arsenal/Views/
//

import SwiftUI
import OSLog

// MARK: - Breaking Arsenal View
/// Clean Arsenal container view that follows single responsibility principle
/// Provides navigation to Moves and Combos sections
struct BreakingArsenalView: View {

    // MARK: - Properties
    @Binding var selectedTab: TabSelection
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🏟️ ARSENAL_VIEW")

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                // MARK: - Move Section
                moveSection

                // MARK: - Combo Section
                comboSection

                Spacer()
            }
            .background(Color.backgroundPrimary.ignoresSafeArea())
            .onAppear {
                logger.info("🏟️ ARSENAL_VIEW: 🚀 Arsenal view appeared with clean architecture")
            }
        }
    }

    // MARK: - Move Section
    @ViewBuilder
    private var moveSection: some View {
        NavigationLink {
            MoveListView(onNavigateToAdd: {
                selectedTab = .add
            })
        } label: {
            VStack(spacing: 12) {
                Text("MOVE")
                    .font(.ibmPlexMono(size: 42, weight: .bold))
                    .foregroundColor(Color(red: 237/255, green: 245/255, blue: 255/255))

                Text("View and manage your breaking moves")
                    .font(.ibmPlexMono(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(SpringButtonStyle())
        .onTapGesture {
            MotionCatalog.Accessibility.selectionHaptic()
            logger.info("🏟️ ARSENAL_VIEW: 👆 Navigate to Moves")
        }
    }

    // MARK: - Combo Section
    @ViewBuilder
    private var comboSection: some View {
        NavigationLink {
            ComboListView()
        } label: {
            VStack(spacing: 12) {
                Text("COMBO")
                    .font(.ibmPlexMono(size: 42, weight: .bold))
                    .foregroundColor(Color(red: 237/255, green: 255/255, blue: 255/255))

                Text("View and manage your breaking combos")
                    .font(.ibmPlexMono(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(SpringButtonStyle())
        .onTapGesture {
            MotionCatalog.Accessibility.selectionHaptic()
            logger.info("🏟️ ARSENAL_VIEW: 👆 Navigate to Combos")
        }
    }
}

// MARK: - Spring Button Style
/// Clean button style for Arsenal navigation with smooth animations
struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    @State var selectedTab: TabSelection = .arsenal

    return BreakingArsenalView(selectedTab: $selectedTab)
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}