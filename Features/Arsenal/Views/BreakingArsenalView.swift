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
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🏟️ ARSENAL_NAVIGATION")

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // MARK: - Breadcrumb Header
                HStack {
                    BreadcrumbView(path: ["BREAKDEX", "ARSENAL"])
                    
                    Spacer()
                    
                    ThemeToggleButton()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.backgroundPrimary)
                
                Divider()
                    .background(Color.textPrimary.opacity(0.2))
                
                // MARK: - Main Content Area
                Spacer()
                
                VStack(spacing: 40) {
                    // MOVES Navigation
                    NavigationLink(value: "moves") {
                        Text("MOVES")
                            .font(.ibmPlexMono(size: 28, weight: .medium))
                            .foregroundColor(.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .onTapGesture {
                        logger.info("🏟️ ARSENAL: User tapped MOVES")
                    }
                    
                    // COMBOS Navigation
                    NavigationLink(value: "combos") {
                        Text("COMBOS")
                            .font(.ibmPlexMono(size: 28, weight: .medium))
                            .foregroundColor(.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .onTapGesture {
                        logger.info("🏟️ ARSENAL: User tapped COMBOS")
                    }
                }
                
                Spacer()
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
            }
        }
    }
}
