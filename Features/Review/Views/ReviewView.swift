// //
// //  ReviewView.swift
// //  BreakingFlashcards
// //
// //  Created by Claude on 10/10/25.
// //

// import SwiftUI
// import CoreData
// import OSLog

// /// Clean review view using shared components and clean architecture
// /// Displays learning states and provides navigation to review sessions
// struct ReviewView: View {
//     // MARK: - Environment & Dependencies
//     @Environment(\.managedObjectContext) private var viewContext

//     // MARK: - State
//     @StateObject private var viewModel: ReviewViewModel

//     // MARK: - Initialization
//     init() {
//         _viewModel = StateObject(wrappedValue: ReviewViewModel(viewContext: PersistenceController.shared.container.viewContext))
//     }

//     // MARK: - Body
//     var body: some View {
//         NavigationView {
//             ZStack {
//                 Color(.systemBackground)
//                     .ignoresSafeArea()

//                 if viewModel.isLoading {
//                     loadingView
//                 } else if !viewModel.hasContentToReview {
//                     emptyStateView
//                 } else {
//                     mainContent
//                 }
//             }
//             .navigationTitle("Review")
//             .navigationBarTitleDisplayMode(.inline)
//         }
//         .onAppear {
//             Task {
//                 await viewModel.loadData()
//             }
//         }
//         .refreshable {
//             await viewModel.loadData()
//         }
//         .alert("Error", isPresented: $viewModel.showError) {
//             Button("OK") {
//                 viewModel.dismissError()
//             }
//         } message: {
//             Text(viewModel.errorMessage ?? "An unknown error occurred")
//         }
//     }

//     // MARK: - View Components
//     private var loadingView: some View {
//         VStack(spacing: 20) {
//             SharedLoadingView.withMessage("Loading review data...", style: .circular)

//             Text("Preparing your learning materials")
//                 .font(.ibmPlexMono(size: 16))
//                 .foregroundColor(.secondary)
//         }
//     }

//     private var emptyStateView: some View {
//         VStack(spacing: 24) {
//             Spacer()

//             Image(systemName: "book.closed")
//                 .font(.system(size: 64))
//                 .foregroundColor(.secondary.opacity(0.5))

//             VStack(spacing: 12) {
//                 Text("Nothing to review yet")
//                     .font(.ibmPlexMono(size: 24, weight: .bold))
//                     .foregroundColor(.textPrimary)

//                 Text("Add some moves and create combos to start reviewing your breaking skills!")
//                     .font(.ibmPlexMono(size: 16))
//                     .foregroundColor(.secondary)
//                     .multilineTextAlignment(.center)
//                     .padding(.horizontal, 32)
//             }

//             Spacer()
//         }
//     }

//     private var mainContent: some View {
//         ScrollView {
//             VStack(spacing: 24) {
//                 // MARK: - Moves Section
//                 if viewModel.hasMovesToReview {
//                     movesSection
//                 }

//                 // MARK: - Combos Section
//                 if viewModel.hasCombosToReview {
//                     if viewModel.hasMovesToReview {
//                         Divider()
//                             .padding(.horizontal, 20)
//                     }
//                     combosSection
//                 }
//             }
//             .padding(.vertical, 20)
//         }
//     }

//     private var movesSection: some View {
//         VStack(spacing: 16) {
//             Text("MOVES")
//                 .font(.ibmPlexMono(size: 24, weight: .bold))
//                 .foregroundColor(.textPrimary)
//                 .frame(maxWidth: .infinity, alignment: .leading)
//                 .padding(.horizontal, 20)

//             VStack(spacing: 4) {
//                 reviewNavigationRow(
//                     title: "NEW",
//                     count: viewModel.newMovesCount,
//                     learningState: "NEW",
//                     type: .moves
//                 )

//                 reviewNavigationRow(
//                     title: "LEARNING",
//                     count: viewModel.learningMovesCount,
//                     learningState: "LEARNING",
//                     type: .moves
//                 )

//                 reviewNavigationRow(
//                     title: "MASTERY",
//                     count: viewModel.masteryMovesCount,
//                     learningState: "MASTERY",
//                     type: .moves
//                 )
//             }
//         }
//     }

//     private var combosSection: some View {
//         VStack(spacing: 16) {
//             Text("COMBOS")
//                 .font(.ibmPlexMono(size: 24, weight: .bold))
//                 .foregroundColor(.textPrimary)
//                 .frame(maxWidth: .infinity, alignment: .leading)
//                 .padding(.horizontal, 20)

//             VStack(spacing: 4) {
//                 reviewNavigationRow(
//                     title: "NEW",
//                     count: viewModel.newCombosCount,
//                     learningState: "NEW",
//                     type: .combos
//                 )

//                 reviewNavigationRow(
//                     title: "LEARNING",
//                     count: viewModel.learningCombosCount,
//                     learningState: "LEARNING",
//                     type: .combos
//                 )

//                 reviewNavigationRow(
//                     title: "MASTERY",
//                     count: viewModel.masteryCombosCount,
//                     learningState: "MASTERY",
//                     type: .combos
//                 )
//             }
//         }
//     }

//     private func reviewNavigationRow(title: String, count: Int, learningState: String, type: ReviewType) -> some View {
//         NavigationLink {
//             // TODO: Implement FlashcardReviewView
//             // FlashcardReviewView(learningState: learningState, reviewType: type)
//             VStack {
//                 Text("Review: \(title)")
//                     .font(.largeTitle)
//                 Text("Learning State: \(learningState)")
//                 Text("Type: \(type)")
//                 Text("FlashcardReviewView - To be implemented")
//             }
//         } label: {
//             HStack {
//                 Text(title)
//                     .font(.ibmPlexMono(size: 20, weight: .thin))
//                     .foregroundColor(.textPrimary)

//                 Spacer()

//                 Text("(\(count))")
//                     .font(.ibmPlexMono(size: 20))
//                     .foregroundColor(.secondary)
//             }
//             .padding(.horizontal, 20)
//             .padding(.vertical, 12)
//             .background(
//                 RoundedRectangle(cornerRadius: 8)
//                     .fill(Color(.systemGray6).opacity(0.5))
//             )
//         }
//         .disabled(count == 0)
//         .opacity(count == 0 ? 0.6 : 1.0)
//         .buttonStyle(PlainButtonStyle())
//     }
// }

// // MARK: - Review Statistics View
// extension ReviewView {
//     /// Optional statistics view for debugging or advanced users
//     private var statisticsView: some View {
//         VStack(spacing: 12) {
//             Text("Review Statistics")
//                 .font(.ibmPlexMono(size: 18, weight: .bold))
//                 .foregroundColor(.textPrimary)

//             let stats = viewModel.reviewStatistics

//             VStack(spacing: 8) {
//                 HStack {
//                     Text("Total Moves:")
//                         .font(.ibmPlexMono(size: 14))
//                     Spacer()
//                     Text("\(stats.totalMoves)")
//                         .font(.ibmPlexMono(size: 14, weight: .medium))
//                 }

//                 HStack {
//                     Text("Total Combos:")
//                         .font(.ibmPlexMono(size: 14))
//                     Spacer()
//                     Text("\(stats.totalCombos)")
//                         .font(.ibmPlexMono(size: 14, weight: .medium))
//                 }

//                 HStack {
//                     Text("Total Items:")
//                         .font(.ibmPlexMono(size: 14, weight: .bold))
//                     Spacer()
//                     Text("\(stats.totalItems)")
//                         .font(.ibmPlexMono(size: 14, weight: .bold))
//                 }
//             }
//             .padding()
//             .background(Color(.systemGray6))
//             .cornerRadius(8)
//         }
//         .padding(.horizontal, 20)
//     }
// }

// // MARK: - Preview
// #Preview("Review View") {
//     ReviewView()
//         .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
// }