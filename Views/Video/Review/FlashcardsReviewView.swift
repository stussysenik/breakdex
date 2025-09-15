//
//  FlashcardsReviewView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/26/25.
//

import SwiftUI
import CoreData
import AVFoundation

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

    private func getVideoAsset(for move: Move) -> AVAsset? {
        guard let videoData = move.videoReference,
              let path = String(data: videoData, encoding: .utf8) else {
            return nil
        }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        return AVURLAsset(url: url)
    }
    
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
    
    private func getComboLearningState(for combo: Combo) -> String {
        let fetchRequest = NSFetchRequest<ComboMove>(entityName: "ComboMove")
        fetchRequest.predicate = NSPredicate(format: "combo == %@", combo)
        
        do {
            let comboMoves = try viewContext.fetch(fetchRequest)
            let moveStates = comboMoves.compactMap { $0.move?.learningState }
            
            if moveStates.isEmpty {
                return "NEW"
            }
            
            if moveStates.allSatisfy({ $0 == "MASTERY" }) {
                return "MASTERY"
            } else if moveStates.contains(where: { $0 == "NEW" }) {
                return "NEW"
            } else if moveStates.contains(where: { $0 == "LEARNING" }) {
                return "LEARNING"
            } else {
                return "NEW"
            }
        } catch {
            return "NEW"
        }
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
    @State private var showRelink = false
    @State private var isPlayerReady = false

    private func getVideoAsset(for move: Move) -> AVAsset? {
        guard let videoData = move.videoReference,
              let path = String(data: videoData, encoding: .utf8) else {
            return nil
        }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        return AVURLAsset(url: url)
    }
    
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
            
            Group {
                if let asset = getVideoAsset(for: move) {
                    VStack {
                        if isPlayerReady {
                            CustomVideoPlayerView(viewModel: UnifiedVideoPlayerViewModel(asset: asset, rotationQuarterTurns: Int(move.rotationQuarterTurns), mode: .main, appContainer: AppContainer.shared))
                        } else {
                            // Loading placeholder while player is initializing
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.secondary.opacity(0.2))
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                                    .scaleEffect(1.5)
                            }
                        }
                    }
                    .onAppear {
                        // Initialize the player and check when it's ready
                        let viewModel = UnifiedVideoPlayerViewModel(asset: asset, rotationQuarterTurns: Int(move.rotationQuarterTurns), mode: .main, appContainer: AppContainer.shared)
                        
                        // Monitor when the player becomes ready
                        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                            if viewModel.isPlayerReady {
                                isPlayerReady = true
                                timer.invalidate()
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("Video not available", systemImage: "video.slash")
                }
            } // video player with proper audio lifecycle management
            .frame(height: 350)
            .cornerRadius(16)
            .padding(.horizontal, 20)
            
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

    @State private var activeMoveIndex: Int? = 0
    @State private var comboMoves: [Move] = []
    @State private var moveToRelink: Move? = nil
    @State private var isPlayerReady = false

    private func getVideoAsset(for move: Move) -> AVAsset? {
        guard let videoData = move.videoReference,
              let path = String(data: videoData, encoding: .utf8) else {
            return nil
        }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        return AVURLAsset(url: url)
    }
    
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
            
            if let activeMove = activeMove { // video player section
                if let asset = getVideoAsset(for: activeMove) {
                    VStack {
                        if isPlayerReady {
                            CustomVideoPlayerView(viewModel: UnifiedVideoPlayerViewModel(asset: asset, rotationQuarterTurns: Int(activeMove.rotationQuarterTurns), mode: .main, appContainer: AppContainer.shared))
                        } else {
                            // Loading placeholder while player is initializing
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.secondary.opacity(0.2))
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                                    .scaleEffect(1.5)
                            }
                        }
                    }
                    .frame(height: 320)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .id(activeMove.managedObjectID) // Force re-initialization when activeMove changes
                    .onAppear {
                        // Reset player readiness state when move changes
                        isPlayerReady = false
                        
                        // Initialize the player and check when it's ready
                        let viewModel = UnifiedVideoPlayerViewModel(asset: asset, rotationQuarterTurns: Int(activeMove.rotationQuarterTurns), mode: .main, appContainer: AppContainer.shared)
                        
                        // Monitor when the player becomes ready
                        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                            if viewModel.isPlayerReady {
                                isPlayerReady = true
                                timer.invalidate()
                            }
                        }
                    }
                    .onChange(of: activeMoveIndex) { _ in
                        // Reset player readiness state when move changes
                        isPlayerReady = false
                    }
                } else {
                    ContentUnavailableView("Video not available", systemImage: "video.slash")
                        .frame(height: 320)
                        .padding(.horizontal, 20)
                }
            } else {
                ContentUnavailableView("Select a move to see a preview", systemImage: "video.slash")
                    .frame(height: 320)
                    .padding(.horizontal, 20)
            }
            
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
