//
//  BreakingArsenalView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/25/25.
//

import SwiftUI
import Foundation
import CoreData
import OSLog

// MARK: - Tab Selection Enum

struct BreakingArsenalView: View {
    @Binding var selectedTab: Int
    @State private var navigationPath = NavigationPath()
    @State private var showMoves = false
    @State private var showCombos = false
    @State private var showSettings = false
    @StateObject private var viewModel = ArsenalViewModel(viewContext: PersistenceController.shared.container.viewContext)
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🏟️ ARSENAL_NAVIGATION")

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // MARK: - Breadcrumb Header
                HStack {
                    BreadcrumbView(path: ["BREAKDEX", "ARSENAL"])

                    Spacer()

                    // Settings Button
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundColor(.textPrimary)
                    }
                    .accessibilityLabel("Settings")
                    .padding(.trailing, 12)

                    ThemeToggleButton()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.backgroundPrimary)
                
                Divider()
                    .background(Color.textPrimary.opacity(0.2))
                
                // MARK: - Main Content Area
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Arsenal intro
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "figure.dance")
                                .font(.system(size: 48))
                                .foregroundColor(.accent)

                            Text("Your Breaking Arsenal")
                                .font(.titleMedium)
                                .foregroundColor(.textPrimary)

                            Text("Manage your moves and combos")
                                .font(.bodySmall)
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.top, Spacing.xxl)
                        .padding(.bottom, Spacing.lg)

                        // Navigation Cards
                        VStack(spacing: Spacing.md) {
                            // MOVES Card
                            NavigationLink(value: "moves") {
                                HStack {
                                    VStack(alignment: .leading, spacing: Spacing.xs) {
                                        Text("MOVES")
                                            .font(.titleSmall)
                                            .foregroundColor(.textPrimary)

                                        Text("\(viewModel.moves.count) moves in arsenal")
                                            .font(.bodySmall)
                                            .foregroundColor(.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.bodyMedium)
                                        .foregroundColor(.textSecondary)
                                }
                                .cardContainer()
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Moves, \(viewModel.moves.count) items")

                            // COMBOS Card
                            NavigationLink(value: "combos") {
                                HStack {
                                    VStack(alignment: .leading, spacing: Spacing.xs) {
                                        Text("COMBOS")
                                            .font(.titleSmall)
                                            .foregroundColor(.textPrimary)

                                        Text("\(viewModel.combos.count) combos created")
                                            .font(.bodySmall)
                                            .foregroundColor(.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.bodyMedium)
                                        .foregroundColor(.textSecondary)
                                }
                                .cardContainer()
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Combos, \(viewModel.combos.count) items")
                        }
                        .padding(.horizontal, Spacing.md)

                        Spacer(minLength: Spacing.xxl)
                    }
                }
            }
            .background(Color.backgroundPrimary)
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { destination in
                Group {
                    if destination == "moves" {
                        MoveListView(onNavigateToAdd: {
                            logger.info("🏠 ARSENAL_NAVIGATION: Navigate to Add Move tab from MoveListView")
                            selectedTab = 1
                        })
                        .onAppear {
                            logger.info("🎯 MOVES_DESTINATION: Navigating to MoveListView")
                        }
                    } else if destination == "combos" {
                        ComboListView()
                            .onAppear {
                                logger.info("🎯 COMBOS_DESTINATION: Navigating to ComboListView")
                            }
                    } else {
                        Text("No destination found")
                    }
                }
            }
            .navigationDestination(for: Combo.self) { combo in
                Group {
                    ComboDetailView(combo: combo)
                        .onAppear {
                            logger.info("🎯 COMBO_DESTINATION: NavigationStack processing Combo destination")
                            logger.info("🎯 COMBO_ID: \(combo.objectID)")
                            logger.info("🎯 COMBO_NAME: \(combo.name ?? "Untitled Combo")")
                            logger.info("🎯 COMBO_TYPE: \(type(of: combo))")
                            logger.info("🏠 ARSENAL_NAVIGATION: Navigating to ComboDetailView for combo: \(combo.name ?? "Untitled Combo")")
                            logger.info("🎯 COMBO_DETAIL_VIEW: ComboDetailView successfully appeared for combo \"\(combo.name ?? "Untitled")\"")
                        }
                }
            }
            .navigationDestination(for: Move.self) { move in
                Group {
                    MoveDetailView(move: move)
                        .onAppear {
                            logger.info("🎯 MOVE_DESTINATION: NavigationStack processing Move destination")
                            logger.info("🎯 MOVE_ID: \(move.objectID)")
                            logger.info("🎯 MOVE_NAME: \(move.name ?? "Untitled Move")")
                            logger.info("🎯 MOVE_TYPE: \(type(of: move))")
                            logger.info("🏠 ARSENAL_NAVIGATION: Navigating to MoveDetailView for move: \(move.name ?? "Untitled Move")")
                            logger.info("🎯 MOVE_DETAIL_VIEW: MoveDetailView successfully appeared for move \"\(move.name ?? "Untitled")\"")
                            MotionCatalog.Accessibility.selectionHaptic()
                        }
                }
            }
          .onAppear {
                logger.info("🎯 ARSENAL_APPEARED: BreakingArsenalView appeared - user navigated back to Arsenal tab")
                logger.info("🔍 ARSENAL_DEBUG: Current selectedTab = \(selectedTab)")
                logger.info("🔍 PATH_INITIAL: NavigationStack initial path count = \(navigationPath.count)")
                logger.info("🎯 ARSENAL_EXPECTED: Move list should refresh and show newly saved moves")
                viewModel.loadData()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}
