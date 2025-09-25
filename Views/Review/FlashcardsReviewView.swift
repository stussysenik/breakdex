//
//  FlashcardsReviewView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/26/25.
//

import SwiftUI
import CoreData
import AVFoundation
import OSLog

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct ReviewButtonStyle: ButtonStyle { // motion-library inspired button style for review buttons
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0.0)
    }
}

enum ReviewType {
    case moves
    case combos
}

struct FlashcardReviewView: View {
    let learningState: String
    let reviewType: ReviewType

    @FetchRequest private var moves: FetchedResults<Move>
    @FetchRequest private var combos: FetchedResults<Combo>

    @Environment(\.managedObjectContext) private var viewContext
    @State private var currentIndex = 0
    @State private var reviewedIndices: Set<Int> = []

    private let logger = Logger(subsystem: "com.breakingflashcards", category: "FlashcardReviewView")

    // 🗑️ DEPRECATED: Old getVideoAsset method removed - replaced by PhotosAssetService
    
    init(learningState: String, reviewType: ReviewType = .moves) {
        self.learningState = learningState
        self.reviewType = reviewType
        
        self._moves = FetchRequest<Move>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Move.createdAt, ascending: true)],
            predicate: NSPredicate(format: "learningState == %@", learningState)
        )
        
        self._combos = FetchRequest<Combo>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Combo.name, ascending: true)],
            predicate: NSPredicate(value: true)
        )
    }
    
    /// Optimized combo learning state calculation using in-memory relationship data
    /// 🚀 PERFORMANCE: Eliminates database queries by using existing relationship data
    /// 📊 LOGS: Provides detailed logging for debugging combo state logic
    private func getComboLearningState(for combo: Combo) -> String {
        logger.info("🎮 FLASHCARD_REVIEW: 🔄 Calculating state for combo: \(combo.name ?? "Unknown")")

        // ✅ RELATIONSHIPS: Use existing relationship data instead of additional database queries
        guard let comboMoves = combo.comboMoves as? Set<ComboMove> else {
            logger.warning("🎮 FLASHCARD_REVIEW: ⚠️ No combo moves relationship found for combo: \(combo.name ?? "Unknown")")
            return "NEW"
        }

        let moveStates = comboMoves.compactMap { $0.move?.learningState }
        logger.info("🎮 FLASHCARD_REVIEW: 📊 Found \(moveStates.count) move states: \(moveStates)")

        // Business logic for determining combo learning state
        let calculatedState: String

        if moveStates.isEmpty {
            calculatedState = "NEW"
        } else if moveStates.allSatisfy({ $0 == "MASTERY" }) {
            calculatedState = "MASTERY"
        } else if moveStates.contains("NEW") {
            calculatedState = "NEW"
        } else if moveStates.contains("LEARNING") {
            calculatedState = "LEARNING"
        } else {
            calculatedState = "NEW" // Fallback for edge cases
        }

        logger.info("🎮 FLASHCARD_REVIEW: ✅ Combo '\(combo.name ?? "Unknown")' calculated state: \(calculatedState)")

        return calculatedState
    }
    
    private var filteredCombos: [Combo] {
        combos.filter { getComboLearningState(for: $0) == learningState }
    }
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()
            
            if reviewType == .moves {
                if moves.indices.contains(currentIndex) {
                    let move = moves[currentIndex]
                    MoveReviewView(
                        move: move,
                        learningState: learningState,
                        onReviewComplete: { moveToNext() }
                    )
                    .id("move-\(currentIndex)") // maintain view identity
                }
                else if moves.isEmpty {
                    EmptyReviewView(type: "moves", learningState: learningState)
                } else {
                    CompletedReviewView(type: "moves", learningState: learningState)
                }
            } else {
                if filteredCombos.indices.contains(currentIndex) {
                    let combo = filteredCombos[currentIndex]
                    ComboReviewView(
                        combo: combo,
                        learningState: learningState,
                        onReviewComplete: { moveToNext() }
                    )
                    .id("combo-\(currentIndex)") // maintain view identity
                }
                else if filteredCombos.isEmpty {
                    EmptyReviewView(type: "combos", learningState: learningState)
                } else {
                    CompletedReviewView(type: "combos", learningState: learningState)
                }
            }
        }
    }
    
    private func moveToNext() {
        reviewedIndices.insert(currentIndex) // mark current item as reviewed
        
        let totalItems = reviewType == .moves ? moves.count : filteredCombos.count
        if currentIndex < totalItems - 1 {
            currentIndex += 1
        } else {
            if reviewedIndices.count >= totalItems { // only show completion if all items have been reviewed at least once
                currentIndex = totalItems // show CompletedReviewView
            } else {
                currentIndex = 0 // continue cycling through unreviewed items
            }
        }
    }
}

struct MoveReviewView: View {
    let move: Move
    let learningState: String
    let onReviewComplete: () -> Void

    // MARK: - State
    @State private var showRelink = false
    @State private var isPlayerReady = false
    @State private var videoAsset: AVAsset? = nil
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var playerViewModel: UnifiedVideoPlayerViewModel?

    private let logger = Logger(subsystem: "com.breakingflashcards", category: "MoveReviewView")

    // MARK: - Video Loading

    /// Load video asset asynchronously using PhotosAssetService
    /// 🎯 ASYNC: Modern async/await pattern with proper error handling
    /// 📊 LOGS: Comprehensive logging for debugging
    private func loadVideoAsset() async {
        logger.info("🎮 MOVE_REVIEW: 🔄 Starting video asset load")

        // Reset state
        isLoading = true
        videoAsset = nil
        errorMessage = nil
        isPlayerReady = false

        guard let photosIdentifier = move.photosIdentifier, !photosIdentifier.isEmpty else {
            let error = "Move has no photos identifier"
            logger.error("🎮 MOVE_REVIEW: ❌ \(error) for move: \(move.name ?? "Unknown")")
            errorMessage = error
            isLoading = false
            return
        }

        logger.info("🎮 MOVE_REVIEW: 📝 Photos identifier: \(photosIdentifier.prefix(8))...")

        do {
            // 🎯 PHOTOS_SERVICE: Use centralized asset loading
            let asset = try await PhotosAssetService.shared.fetchAVAsset(with: photosIdentifier)
            logger.info("🎮 MOVE_REVIEW: ✅ Video asset loaded successfully")
            logger.info("🎮 MOVE_REVIEW: 📊 Asset duration: \(CMTimeGetSeconds(asset.duration))s")

            await MainActor.run {
                self.videoAsset = asset
                self.isLoading = false
                self.errorMessage = nil

                // Prefetch for better performance next time
                Task.detached {
                    await PhotosAssetService.shared.prefetchAssetMetadata(for: photosIdentifier)
                }
            }
        } catch let error as AssetError {
            // Handle specific AssetError cases
            if error == .assetNotFound {
                await MainActor.run {
                    let errorDescription = error.localizedDescription
                    logger.error("🎮 MOVE_REVIEW: ❌ Asset not found, triggering relink flow: \(errorDescription)")
                    self.errorMessage = errorDescription
                    self.videoAsset = nil
                    self.isLoading = false
                    self.showRelink = true // Trigger navigation to VideoRelinkView
                }
            } else {
                await MainActor.run {
                    let errorDescription = error.localizedDescription
                    logger.error("🎮 MOVE_REVIEW: ❌ Other AssetError: \(errorDescription)")
                    self.errorMessage = errorDescription
                    self.videoAsset = nil
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                let errorDescription = error.localizedDescription
                logger.error("🎮 MOVE_REVIEW: ❌ Failed to load video asset: \(errorDescription)")
                self.errorMessage = errorDescription
                self.videoAsset = nil
                self.isLoading = false
            }
        }
    }

    // 🗑️ DEPRECATED: Old getVideoAsset method removed - replaced by PhotosAssetService
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with move name and learning state
            ZStack(alignment: .top) {
                // Move name and date centered
                VStack(spacing: 8) {
                    Text(move.name ?? "Unknown Move")
                        .font(.ibmPlexMono(size: 18, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(move.createdAt ?? Date(), style: .date)
                        .font(.ibmPlexMono(size: 12))
                        .foregroundColor(.secondary)
                }

                // Learning state pill aligned to right (matches GOOD button edge)
                HStack {
                    Spacer()
                    StatePillView(learningState: move.learningState)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // MARK: - Video Player Section
            Group {
                if isLoading {
                    // Loading state with progress indicator
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 350)

                            VStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                                    .scaleEffect(1.5)

                                Text("Loading video...")
                                    .font(.ibmPlexMono(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } else if let asset = videoAsset {
                    // Video loaded successfully
                    VStack {
                        if isPlayerReady {
                            CustomVideoPlayerView(
                                viewModel: playerViewModel!
                            )
                        } else {
                            // Player initializing
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 350)

                                VStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                                        .scaleEffect(1.2)

                                    Text("Preparing player...")
                                        .font(.ibmPlexMono(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .onAppear {
                        // Initialize the player and monitor readiness
                        let viewModel = UnifiedVideoPlayerViewModel(
                            player: AVPlayer(playerItem: AVPlayerItem(asset: asset)),
                            mode: .main,
                            appContainer: AppContainer.shared
                        )
                        self.playerViewModel = viewModel // Store reference for teardown

                        logger.info("🎮 MOVE_REVIEW: 🔄 Monitoring player readiness for move: \(move.name ?? "Unknown")")

                        // Monitor when the player becomes ready
                        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                            if viewModel.isPlayerReady {
                                logger.info("🎮 MOVE_REVIEW: ✅ Player ready for move: \(move.name ?? "Unknown")")
                                isPlayerReady = true
                                timer.invalidate()
                            }
                        }
                    }
                    .onDisappear {
                        // 🎯 CRITICAL: Teardown player to prevent audio overlap when navigating away
                        logger.info("🎮 MOVE_REVIEW: 🔄 View disappearing, tearing down player for move: \(move.name ?? "Unknown")")
                        playerViewModel?.teardown()
                        playerViewModel = nil
                        isPlayerReady = false
                    }
                } else {
                    // Error state with actionable feedback
                    VStack(spacing: 12) {
                        ContentUnavailableView(
                            "Video Unavailable",
                            systemImage: "video.slash",
                            description: Text(errorMessage ?? "This move's video could not be loaded from your photo library.")
                        )

                        Button(action: {
                            logger.info("🎮 MOVE_REVIEW: 🔄 Retry requested for move: \(move.name ?? "Unknown")")
                            Task {
                                await loadVideoAsset()
                            }
                        }) {
                            Text("Retry")
                                .font(.ibmPlexMono(size: 14, weight: .bold))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(ReviewButtonStyle())
                    }
                    .frame(height: 350)
                }
            }
            .padding(.horizontal, 20)
            .task(id: move.objectID) { // 🔄 Reload when move changes
                logger.info("🎮 MOVE_REVIEW: 🔄 Loading video for move: \(move.name ?? "Unknown")")
                await loadVideoAsset()
            }
            
            Spacer(minLength: 40)
            
            ReviewButtons( // review action buttons
                learningState: learningState, 
                move: move, 
                reviewType: .moves,
                onReviewComplete: onReviewComplete
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 150)
        }
        .navigationDestination(isPresented: $showRelink) {
            VideoRelinkView(move: move) { _ in
                showRelink = false
            }
        }
    }
}

struct ComboReviewView: View {
    @Environment(\.managedObjectContext) private var viewContext

    let combo: Combo
    let learningState: String
    let onReviewComplete: () -> Void

    // MARK: - State
    @State private var activeMoveIndex: Int? = 0
    @State private var comboMoves: [Move] = []
    @State private var moveToRelink: Move? = nil
    @State private var isPlayerReady = false
    @State private var videoAsset: AVAsset? = nil
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var playerViewModel: UnifiedVideoPlayerViewModel?

    private let logger = Logger(subsystem: "com.breakingflashcards", category: "ComboReviewView")

    // MARK: - Video Loading

    /// Load video asset asynchronously for a specific move in combo
    /// 🎯 ASYNC: Modern async/await pattern with proper error handling
    /// 📊 LOGS: Comprehensive logging for debugging combo moves
    private func loadVideoAsset(for move: Move) async {
        logger.info("🎮 COMBO_REVIEW: 🔄 Starting video asset load for combo move: \(move.name ?? "Unknown")")

        // Reset state
        isLoading = true
        videoAsset = nil
        errorMessage = nil
        isPlayerReady = false

        guard let photosIdentifier = move.photosIdentifier, !photosIdentifier.isEmpty else {
            let error = "Move has no photos identifier"
            logger.error("🎮 COMBO_REVIEW: ❌ \(error) for move: \(move.name ?? "Unknown")")
            errorMessage = error
            isLoading = false
            return
        }

        logger.info("🎮 COMBO_REVIEW: 📝 Photos identifier: \(photosIdentifier.prefix(8))...")

        do {
            // 🎯 PHOTOS_SERVICE: Use centralized asset loading
            let asset = try await PhotosAssetService.shared.fetchAVAsset(with: photosIdentifier)
            logger.info("🎮 COMBO_REVIEW: ✅ Video asset loaded successfully")
            logger.info("🎮 COMBO_REVIEW: 📊 Asset duration: \(CMTimeGetSeconds(asset.duration))s")

            await MainActor.run {
                self.videoAsset = asset
                self.isLoading = false
                self.errorMessage = nil

                // Prefetch for better performance next time
                Task.detached {
                    await PhotosAssetService.shared.prefetchAssetMetadata(for: photosIdentifier)
                }
            }
        } catch {
            await MainActor.run {
                let errorDescription = error.localizedDescription
                logger.error("🎮 COMBO_REVIEW: ❌ Failed to load video asset: \(errorDescription)")
                self.errorMessage = errorDescription
                self.videoAsset = nil
                self.isLoading = false
            }
        }
    }

    // 🗑️ DEPRECATED: Old getVideoAsset method removed - replaced by PhotosAssetService
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) { // display the combo's name
                Text(combo.name ?? "Unknown Combo")
                    .font(.ibmPlexMono(size: 20, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text("\(comboMoves.count) moves")
                    .font(.ibmPlexMono(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
            
            // MARK: - Video Player Section
            Group {
                if let activeMove = activeMove {
                VStack(spacing: 8) {
                    Text(activeMove.name ?? "Unknown Move")
                        .font(.ibmPlexMono(size: 16, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                }

                if isLoading {
                    // Loading state
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 320)

                        VStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                                .scaleEffect(1.5)

                            Text("Loading video...")
                                .font(.ibmPlexMono(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(height: 320)
                    .padding(.horizontal, 20)
                } else if let asset = videoAsset {
                    // Video loaded successfully
                    VStack {
                        if isPlayerReady {
                            CustomVideoPlayerView(
                                viewModel: playerViewModel!
                            )
                        } else {
                            // Player initializing
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 320)

                                VStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                                        .scaleEffect(1.2)

                                    Text("Preparing player...")
                                        .font(.ibmPlexMono(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(height: 320)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .id(activeMove.objectID) // Force re-initialization when activeMove changes
                    .onAppear {
                        let viewModel = UnifiedVideoPlayerViewModel(
                            player: AVPlayer(playerItem: AVPlayerItem(asset: asset)),
                            mode: .main,
                            appContainer: AppContainer.shared
                        )
                        self.playerViewModel = viewModel // Store reference for teardown

                        logger.info("🎮 COMBO_REVIEW: 🔄 Monitoring player readiness for move: \(activeMove.name ?? "Unknown")")

                        // Monitor when the player becomes ready
                        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                            if viewModel.isPlayerReady {
                                logger.info("🎮 COMBO_REVIEW: ✅ Player ready for move: \(activeMove.name ?? "Unknown")")
                                isPlayerReady = true
                                timer.invalidate()
                            }
                        }
                    }
                    .onDisappear {
                        // 🎯 CRITICAL: Teardown player to prevent audio overlap when navigating away or switching moves
                        logger.info("🎮 COMBO_REVIEW: 🔄 View disappearing, tearing down player for move: \(activeMove.name ?? "Unknown")")
                        playerViewModel?.teardown()
                        playerViewModel = nil
                        isPlayerReady = false
                    }
                } else {
                    // Error state
                    ContentUnavailableView(
                        "Video Unavailable",
                        systemImage: "video.slash",
                        description: Text(errorMessage ?? "This move's video could not be loaded from your photo library.")
                    )
                    .frame(height: 320)
                    .padding(.horizontal, 20)
                }
            } else {
                // No move selected
                ContentUnavailableView(
                    "Select a move to see a preview",
                    systemImage: "video.slash"
                )
                .frame(height: 320)
                .padding(.horizontal, 20)
            }
            }
            .task(id: activeMove?.objectID) { // 🔄 Reload when active move changes
                if let move = activeMove {
                    logger.info("🎮 COMBO_REVIEW: 🔄 Loading video for move: \(move.name ?? "Unknown")")
                    await loadVideoAsset(for: move)
                } else {
                    // Reset state when no move is selected
                    await MainActor.run {
                        self.videoAsset = nil
                        self.isLoading = false
                        self.errorMessage = nil
                        self.isPlayerReady = false
                    }
                }
            } // End Group

            if !comboMoves.isEmpty { // timeline section
                VStack(spacing: 12) {
                    Text("COMBO SEQUENCE")
                        .font(.ibmPlexMono(size: 14, weight: .bold))
                        .foregroundColor(.textPrimary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(comboMoves.enumerated()), id: \.element.managedObjectID) { index, move in
                                VStack(spacing: 6) {
                                    TimelineNodeView(
                                        sequenceNumber: index + 1,
                                        isActive: activeMoveIndex == index,
                                        onDelete: {},
                                        move: move,
                                        showDelete: false
                                    )
                                    .onTapGesture {
                                        activeMoveIndex = index
                                    }
                                    
                                    Text(move.name ?? "Move")
                                        .font(.ibmPlexMono(size: 10))
                                        .foregroundColor(.textPrimary)
                                        .frame(width: 50)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                
                                if index < comboMoves.count - 1 {
                                    Rectangle()
                                        .frame(width: 20, height: 2)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(height: 80)
                }
            }
            
            Spacer(minLength: 40)
            
            ReviewButtons( // review action buttons for combo
                learningState: learningState,
                combo: combo,
                reviewType: .combos,
                onReviewComplete: onReviewComplete
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .navigationTitle("Combo Review")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $moveToRelink) { move in
            VideoRelinkView(move: move) { _ in
                moveToRelink = nil
            }
        }
        .onAppear {
            loadComboMoves()
        }
    }
    
    private var activeMove: Move? {
        guard let activeMoveIndex, comboMoves.indices.contains(activeMoveIndex) else {
            return nil
        }
        return comboMoves[activeMoveIndex]
    }
    
    private func loadComboMoves() {
        let fetchRequest = NSFetchRequest<ComboMove>(entityName: "ComboMove")
        fetchRequest.predicate = NSPredicate(format: "combo == %@", combo)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ComboMove.sequenceIndex, ascending: true)]
        
        do {
            let comboMoveEntities = try viewContext.fetch(fetchRequest)
            self.comboMoves = comboMoveEntities.compactMap { $0.move }
        } catch {
            print("Error loading combo moves: \(error)")
            self.comboMoves = []
        }
    }
}

struct EmptyReviewView: View {
    let type: String
    let learningState: String
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: type == "moves" ? "figure.martial.arts" : "square.stack.3d.up")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary.opacity(0.5))
                
                VStack(spacing: 12) {
                    Text("No \(type) to review")
                        .font(.ibmPlexMono(size: 24, weight: .bold))
                        .foregroundColor(.textPrimary)
                    
                    Text("No \(type) in the \(learningState.lowercased()) category yet. Add some \(type) and they'll appear here!")
                        .font(.ibmPlexMono(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
            }
        }
        .navigationTitle("\(learningState.capitalized) \(type.capitalized)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CompletedReviewView: View {
    let type: String
    let learningState: String
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
                
                VStack(spacing: 12) {
                    Text("Great work!")
                        .font(.ibmPlexMono(size: 24, weight: .bold))
                        .foregroundColor(.textPrimary)
                    
                    Text("You've completed all \(type) in the \(learningState.lowercased()) category.")
                        .font(.ibmPlexMono(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
            }
        }
        .navigationTitle("\(learningState.capitalized) \(type.capitalized)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ReviewButtons: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    let learningState: String
    let move: Move?
    let combo: Combo?
    let reviewType: ReviewType
    let onReviewComplete: () -> Void
    
    @State private var pressedButton: String?
    
    init(learningState: String, move: Move? = nil, combo: Combo? = nil, reviewType: ReviewType, onReviewComplete: @escaping () -> Void) {
        self.learningState = learningState
        self.move = move
        self.combo = combo
        self.reviewType = reviewType
        self.onReviewComplete = onReviewComplete
    }
    
    func handleReview(difficulty: String) {
        // Haptic feedback
        MotionCatalog.Accessibility.actionHaptic()
        
        pressedButton = difficulty
        
        // Reset button state after animation (snappier timing)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            pressedButton = nil
        }
        
        if reviewType == .moves {
            handleMoveReview(difficulty: difficulty)
        } else {
            handleComboReview(difficulty: difficulty)
        }
    }
    
    func handleMoveReview(difficulty: String) {
        guard let move = move else { return }
        
        switch difficulty { // update the learning state based on difficulty
        case "AGAIN":
            move.learningState = "NEW"
        case "HARD":
            move.learningState = "LEARNING"
        case "GOOD":
            if move.learningState == "LEARNING" {
                move.learningState = "MASTERY"
            } else if move.learningState == "NEW" {
                move.learningState = "LEARNING"
            }
        default:
            break
        }
        
        do { // save the changes
            try viewContext.save()
            onReviewComplete() // move to next item
        } catch {
            print("Error updating move: \(error)")
        }
    }
    
    func handleComboReview(difficulty: String) {
        guard let combo = combo else {
            return
        }
        
        let fetchRequest = NSFetchRequest<ComboMove>(entityName: "ComboMove") // get all moves in the combo
        fetchRequest.predicate = NSPredicate(format: "combo == %@", combo)
        
        do {
            let comboMoves = try viewContext.fetch(fetchRequest)
            
            for comboMove in comboMoves { // update all moves in the combo based on difficulty
                guard let move = comboMove.move else { continue }
                
                switch difficulty {
                case "AGAIN":
                    move.learningState = "NEW"
                case "HARD":
                    move.learningState = "LEARNING"
                case "GOOD":
                    if move.learningState == "LEARNING" {
                        move.learningState = "MASTERY"
                    } else if move.learningState == "NEW" {
                        move.learningState = "LEARNING"
                    }
                default:
                    break
                }
            }
            
            try viewContext.save()
            onReviewComplete() // move to next item
        } catch {
            print("Error updating combo moves: \(error)")
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            
            HStack(spacing: 12) {
                Button(action: {
                    handleReview(difficulty: "AGAIN")
                }) {
                    Text("AGAIN")
                        .font(.ibmPlexMono(size: 28, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(pressedButton == "AGAIN" ? Color.buttonAgain.opacity(0.8) : Color.buttonAgain)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .scaleEffect(pressedButton == "AGAIN" ? 0.96 : 1.0)
                }
                
                Button(action: {
                    handleReview(difficulty: "HARD")
                }) {
                    Text("HARD")
                        .font(.ibmPlexMono(size: 28, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(pressedButton == "HARD" ? Color.buttonHard.opacity(0.8) : Color.buttonHard)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .scaleEffect(pressedButton == "HARD" ? 0.96 : 1.0)
                }
                
                Button(action: {
                    handleReview(difficulty: "GOOD")
                }) {
                    Text("GOOD")
                        .font(.ibmPlexMono(size: 28, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(pressedButton == "GOOD" ? Color.buttonGood.opacity(0.8) : Color.buttonGood)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .scaleEffect(pressedButton == "GOOD" ? 0.96 : 1.0)
                }
            }
        }
    }
}

#Preview {
    FlashcardReviewView(learningState: "NEW", reviewType: .moves)
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
