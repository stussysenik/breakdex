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
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🏟️ ARSENAL_NAVIGATION")

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Move List Section (Primary content)
                MoveListView(onNavigateToAdd: {
                    logger.info("🏠 ARSENAL_NAVIGATION: Navigate to Add Move tab from MoveListView")
                    logger.info("🔍 ARSENAL_DEBUG: selectedTab changing from \(selectedTab) to 1")
                    selectedTab = 1 // Switch to Add Move tab
                    logger.info("✅ ARSENAL_NAVIGATION: Successfully switched to Add Move tab")
                })

                // Fixed Bottom Section with Combo
                VStack(spacing: 20) {
                    Divider()
                        .background(Color.textPrimary.opacity(0.3))

                    HStack(spacing: 40) {
                        Spacer()

                        // Combo Section (reduced size)
                        NavigationLink(value: "combos") {
                            Text("COMBOS")
                                .font(.ibmPlexMono(size: 24, weight: .semibold))
                                .foregroundColor(.textPrimary)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            logger.info("🔗 ARSENAL_NAVLINK: COMBOS NavigationLink appeared")
                            logger.info("🔗 TARGET_VALUE: String(\"combos\")")
                            logger.info("🔗 TARGET_TYPE: \(type(of: "combos"))")
                        }
                        .onTapGesture {
                            logger.info("🔗 ARSENAL_NAVLINK: User tapped COMBOS button")
                            logger.info("🔗 NAVIGATING_TO: ComboListView via String value \"combos\"")
                        }

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
            .navigationDestination(for: String.self) { destination in
                Group {
                    if destination == "combos" {
                        ComboListView()
                            .onAppear {
                                logger.info("🎯 STRING_DESTINATION: NavigationStack processing String destination")
                                logger.info("🎯 DESTINATION_VALUE: \"\(destination)\"")
                                logger.info("🎯 DESTINATION_TYPE: \(type(of: destination))")
                                logger.info("🎯 MATCH_SUCCESS: String \"combos\" matched → Creating ComboListView()")
                                logger.info("📋 COMBO_LIST_CREATED: ComboListView appeared via String navigation")
                            }
                    } else {
                        Text("No destination found")
                            .onAppear {
                                logger.info("🎯 STRING_DESTINATION: NavigationStack processing String destination")
                                logger.info("🎯 DESTINATION_VALUE: \"\(destination)\"")
                                logger.info("🎯 DESTINATION_TYPE: \(type(of: destination))")
                                logger.warning("🎯 NO_MATCH: No navigation destination found for String value \"\(destination)\"")
                            }
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
