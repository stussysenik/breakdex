// DesignSystemCatalog.swift — Interactive design system preview catalog
//
// This file is NOT part of the shipping app — it's a developer-only reference.
// It provides Xcode Preview (#Preview) screens that showcase every design token
// and component pattern used in the Breakdex app.
//
// Each section is a standalone SwiftUI view with both dark and light previews.
// The catalog has two goals:
// 1. Visual reference — see all colors, fonts, spacing at a glance
// 2. Interactive testing — tap buttons, switch states, verify animations
//
// Sections:
// - ColorCatalogView: All color tokens (primary, secondary, state, action)
// - TypographyCatalogView: IBM Plex Mono type scale (title → caption)
// - TokensCatalogView: Spacing grid, corner radii, shadow levels
// - MoveListRowCatalogView: Real move list row layout with tap feedback
// - ReviewButtonsCatalogView: AGAIN/HARD/GOOD buttons with state changes
// - ComboTimelineCatalogView: Combo builder with add/remove/select
// - MovePickerCatalogView: Search + select move list with checkmarks
// - VideoPlayerCatalogView: Loading/Error/Playing state switcher
// - AnimationCatalogView: Side-by-side animation curve comparison
// - DesignSystemOverviewView: Compact overview of everything on one screen

import SwiftUI

// MARK: - Color Catalog
// Displays every Color token from DesignSystem.swift as labeled swatches.
// Grouped by role: primary, secondary, learning state, and action buttons.

struct ColorCatalogView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                // Primary colors — the foundational palette
                sectionHeader("PRIMARY")
                colorRow("backgroundPrimary", color: .backgroundPrimary, border: true)  // border=true so light BG is visible
                colorRow("textPrimary", color: .textPrimary)
                colorRow("accent", color: .accent)
                colorRow("neutralFill", color: .neutralFill)

                // Secondary colors — supporting fills and text
                sectionHeader("SECONDARY")
                colorRow("textSecondary", color: .textSecondary)
                colorRow("cardBackground", color: .cardBackground)

                // State colors — one per LearningState (NEW/LEARNING/MASTERY)
                sectionHeader("STATE")
                colorRow("stateNew", color: .stateNew)          // Magenta
                colorRow("stateLearning", color: .stateLearning) // Purple
                colorRow("stateMastery", color: .stateMastery)   // Green

                // Action button colors — spaced repetition review ratings
                sectionHeader("ACTION")
                colorRow("buttonAgain", color: .buttonAgain)     // Red
                colorRow("buttonHard", color: .buttonHard)       // Yellow
                colorRow("buttonGood", color: .buttonGood)       // Green
            }
            .padding(Spacing.xl)
        }
        .background(Color.backgroundPrimary)
    }

    /// Section label — small, bold, muted text
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.ibmPlexMono(size: 12, weight: .bold))
            .foregroundColor(.textSecondary)
            .padding(.top, Spacing.sm)
    }

    /// Single color swatch row — 48×48 rounded square + token name
    /// `border` adds a subtle stroke so light colors are visible against light backgrounds
    private func colorRow(_ name: String, color: Color, border: Bool = false) -> some View {
        HStack(spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(color)
                .frame(width: 48, height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .stroke(Color.textSecondary.opacity(border ? 0.5 : 0), lineWidth: 1)
                )
            Text(name)
                .font(.ibmPlexMono(size: 14, weight: .bold))
                .foregroundColor(.textPrimary)
            Spacer()
        }
    }
}

// Both dark and light previews for visual comparison
#Preview("Colors - Dark") { ColorCatalogView().preferredColorScheme(.dark) }
#Preview("Colors - Light") { ColorCatalogView().preferredColorScheme(.light) }

// MARK: - Typography Catalog
// Shows every font preset from the IBM Plex Mono type scale.
// Each row renders the font at its actual size with a label showing the preset name.

struct TypographyCatalogView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // Title scale — large headings (32/24/20)
                Text("TITLE SCALE")
                    .font(.ibmPlexMono(size: 12, weight: .bold))
                    .foregroundColor(.textSecondary)
                typRow("titleLarge", font: .titleLarge, note: "32 bold")
                typRow("titleMedium", font: .titleMedium, note: "24 semibold")
                typRow("titleSmall", font: .titleSmall, note: "20 medium")
                Divider()

                // Body scale — content text (18/16/14)
                Text("BODY SCALE")
                    .font(.ibmPlexMono(size: 12, weight: .bold))
                    .foregroundColor(.textSecondary)
                typRow("bodyLarge", font: .bodyLarge, note: "18 regular")
                typRow("bodyMedium", font: .bodyMedium, note: "16 regular")
                typRow("bodySmall", font: .bodySmall, note: "14 regular")
                Divider()

                // Caption — smallest text for metadata (12)
                typRow("caption", font: .caption, note: "12 regular")
            }
            .padding(Spacing.xl)
        }
        .background(Color.backgroundPrimary)
    }

    /// Typography sample row — shows the font rendering "IBM Plex Mono" + its preset name
    private func typRow(_ name: String, font: Font, note: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("IBM Plex Mono").font(font).foregroundColor(.textPrimary)
            Text("\(name) — \(note)").font(.ibmPlexMono(size: 11)).foregroundColor(.textSecondary)
        }
    }
}

#Preview("Typography - Dark") { TypographyCatalogView().preferredColorScheme(.dark) }
#Preview("Typography - Light") { TypographyCatalogView().preferredColorScheme(.light) }

// MARK: - Spacing + Radius + Shadows
// Three token categories visualized together:
// 1. Spacing: horizontal bars showing each 4pt-grid step
// 2. Radius: rounded rectangle outlines at each corner radius
// 3. Shadows: cards with each shadow level applied

struct TokensCatalogView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                // --- Spacing ---
                // Each row shows a colored bar whose width = the spacing value.
                // This makes the 4pt grid progression visually obvious.
                Text("SPACING (4pt grid)")
                    .font(.ibmPlexMono(size: 12, weight: .bold))
                    .foregroundColor(.textSecondary)
                ForEach([
                    ("xxs", Spacing.xxs), ("xs", Spacing.xs), ("sm", Spacing.sm),
                    ("md", Spacing.md), ("lg", Spacing.lg), ("xl", Spacing.xl),
                    ("xxl", Spacing.xxl), ("xxxl", Spacing.xxxl)
                ], id: \.0) { name, val in
                    HStack(spacing: Spacing.sm) {
                        // Token name label (right-aligned for clean column)
                        Text(name).font(.ibmPlexMono(size: 11, weight: .bold))
                            .foregroundColor(.textPrimary).frame(width: 40, alignment: .trailing)
                        // Visual bar — width proportional to the spacing value
                        RoundedRectangle(cornerRadius: 2).fill(Color.accent)
                            .frame(width: val, height: 20)
                        // Numeric value
                        Text("\(Int(val))").font(.ibmPlexMono(size: 10))
                            .foregroundColor(.textSecondary)
                        Spacer()
                    }
                }

                Divider()

                // --- Corner Radius ---
                // 48×48 outlined squares at each radius preset, plus a capsule (pill shape).
                Text("CORNER RADIUS")
                    .font(.ibmPlexMono(size: 12, weight: .bold))
                    .foregroundColor(.textSecondary)
                HStack(spacing: Spacing.lg) {
                    ForEach([("sm", Radius.sm), ("md", Radius.md), ("lg", Radius.lg), ("xl", Radius.xl)], id: \.0) { name, r in
                        VStack(spacing: Spacing.xs) {
                            RoundedRectangle(cornerRadius: r).stroke(Color.accent, lineWidth: 2)
                                .frame(width: 48, height: 48)
                            Text(name).font(.ibmPlexMono(size: 10)).foregroundColor(.textSecondary)
                        }
                    }
                    // Capsule (fully rounded) — used for pills, tags, buttons
                    VStack(spacing: Spacing.xs) {
                        Capsule().stroke(Color.accent, lineWidth: 2).frame(width: 64, height: 32)
                        Text("pill").font(.ibmPlexMono(size: 10)).foregroundColor(.textSecondary)
                    }
                }

                Divider()

                // --- Shadows ---
                // Cards with each AppShadow level applied. View on dark background for best effect.
                Text("SHADOWS")
                    .font(.ibmPlexMono(size: 12, weight: .bold))
                    .foregroundColor(.textSecondary)
                HStack(spacing: Spacing.xl) {
                    ForEach([("subtle", AppShadow.subtle), ("medium", AppShadow.medium), ("strong", AppShadow.strong), ("glow", AppShadow.glow)], id: \.0) { name, shadow in
                        VStack(spacing: Spacing.sm) {
                            RoundedRectangle(cornerRadius: Radius.md).fill(Color.cardBackground)
                                .frame(width: 60, height: 60).appShadow(shadow) // Apply the shadow
                            Text(name).font(.ibmPlexMono(size: 10)).foregroundColor(.textSecondary)
                        }
                    }
                }
            }
            .padding(Spacing.xl)
        }
        .background(Color.backgroundPrimary)
    }
}

#Preview("Tokens - Dark") { TokensCatalogView().preferredColorScheme(.dark) }
#Preview("Tokens - Light") { TokensCatalogView().preferredColorScheme(.light) }

// MARK: - Interactive: Move List Row (Real Layout)
// Simulates the actual MoveListView row layout with mock data.
// Tapping a row triggers a spring animation and shows a toast-style confirmation.
// Tests: SpringButtonStyle, StatePillView, typography hierarchy, list styling.

struct MoveListRowCatalogView: View {
    @State private var tappedMove: String?  // Tracks which move was last tapped (for toast)

    // Mock move data — name, learning state raw value, and formatted date
    private let moves: [(name: String, state: String, date: String)] = [
        ("Windmill", "NEW", "Jan 15, 2026, 3:42 PM"),
        ("Headspin", "LEARNING", "Jan 12, 2026, 11:20 AM"),
        ("Six Step", "MASTERY", "Dec 28, 2025, 9:05 AM"),
        ("Toprock", "NEW", "Jan 18, 2026, 6:30 PM"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                // Plain-style list matches the real MoveListView layout
                List(moves, id: \.name) { move in
                    Button {
                        // Spring animation on tap — same as real app
                        withAnimation(AppAnimation.springSmooth) {
                            tappedMove = move.name
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                // Move name — bold, primary text
                                Text(move.name)
                                    .font(.ibmPlexMono(size: 16, weight: .bold))
                                    .foregroundColor(.textPrimary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                // Date added — small, secondary text
                                Text("Added: \(move.date)")
                                    .font(.ibmPlexMono(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // Learning state pill (NEW/LEARNING/MASTERY) — right-aligned
                            StatePillView(learningState: move.state)
                                .fixedSize()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(SpringButtonStyle())  // Scale-down effect on press
                    .listRowBackground(Color.backgroundPrimary)
                }
                .listStyle(.plain)
                .searchable(text: .constant(""), prompt: "Search Moves...")
            }
            .navigationTitle("Move Arsenal")
            .navigationBarTitleDisplayMode(.inline)
            // Toast overlay — slides up from bottom when a move is tapped
            .overlay(alignment: .bottom) {
                if let name = tappedMove {
                    Text("Tapped: \(name)")
                        .font(.ibmPlexMono(size: 14, weight: .bold))
                        .foregroundColor(.backgroundPrimary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.accent)
                        .clipShape(Capsule())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, Spacing.xl)
                        .onAppear {
                            // Auto-dismiss the toast after 1.5 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { tappedMove = nil }
                            }
                        }
                }
            }
        }
    }
}

#Preview("Move List Row - Dark") { MoveListRowCatalogView().preferredColorScheme(.dark) }
#Preview("Move List Row - Light") { MoveListRowCatalogView().preferredColorScheme(.light) }

// MARK: - Interactive: Review Buttons (Real Layout)
// Simulates the FlashcardsReviewView rating buttons.
// Each tap updates the displayed learning state and increments a counter.
// Tests: button colors, ReviewButtonStyle, state transitions, spring animations.

struct ReviewButtonsCatalogView: View {
    @State private var lastRating: String?                                        // Most recent button pressed
    @State private var ratingCounts: [String: Int] = ["AGAIN": 0, "HARD": 0, "GOOD": 0]  // Tap counters

    var body: some View {
        VStack(spacing: 0) {
            // --- Card Preview Area ---
            // Shows a mock move card that updates its state pill based on the last rating.
            VStack(spacing: Spacing.md) {
                Image(systemName: "figure.dance")
                    .font(.system(size: 60))
                    .foregroundColor(.accent)

                Text("Windmill")
                    .font(.ibmPlexMono(size: 24, weight: .bold))
                    .foregroundColor(.textPrimary)

                // State pill reacts to the last rating:
                // GOOD → MASTERY, HARD → LEARNING, anything else → NEW
                StatePillView(learningState: lastRating == "GOOD" ? "MASTERY" : lastRating == "HARD" ? "LEARNING" : "NEW")

                // Shows which button was last pressed
                if let rating = lastRating {
                    Text("Rated: \(rating)")
                        .font(.ibmPlexMono(size: 14))
                        .foregroundColor(.textSecondary)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .background(Color.neutralFill.opacity(0.3))
            .cornerRadius(Radius.xl)
            .padding(Spacing.xl)

            Spacer()

            // --- Rating Buttons ---
            // Three full-width buttons matching the real FlashcardsReviewView layout.
            VStack(spacing: 16) {
                catalogReviewButton("AGAIN", color: .buttonAgain, count: ratingCounts["AGAIN"] ?? 0)
                catalogReviewButton("HARD", color: .buttonHard, count: ratingCounts["HARD"] ?? 0)
                catalogReviewButton("GOOD", color: .buttonGood, count: ratingCounts["GOOD"] ?? 0)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Color.backgroundPrimary)
    }

    /// Creates a single review button with label, color, and tap counter badge.
    /// Uses ReviewButtonStyle for the press animation (scale-down on tap).
    private func catalogReviewButton(_ label: String, color: Color, count: Int) -> some View {
        Button {
            withAnimation(AppAnimation.springSmooth) {
                lastRating = label
                ratingCounts[label, default: 0] += 1  // Increment tap counter
            }
        } label: {
            HStack {
                Text(label)
                    .font(.ibmPlexMono(size: 16, weight: .bold))
                Spacer()
                // Show count badge only after first tap
                if count > 0 {
                    Text("\(count)")
                        .font(.ibmPlexMono(size: 14))
                        .opacity(0.7)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .padding(.horizontal, Spacing.lg)
        }
        .background(color)
        .foregroundColor(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .buttonStyle(ReviewButtonStyle())
    }
}

#Preview("Review Buttons - Dark") { ReviewButtonsCatalogView().preferredColorScheme(.dark) }
#Preview("Review Buttons - Light") { ReviewButtonsCatalogView().preferredColorScheme(.light) }

// MARK: - Interactive: Combo Timeline Builder (Real Layout)
// Simulates the CreateComboView workflow: adding moves to a combo timeline,
// selecting individual nodes, and removing them.
// Tests: TimelineNodeView, ComboTimelineView patterns, sheet presentation, spring animations.

struct ComboTimelineCatalogView: View {
    // Mutable list of moves in the combo — starts with 3 sample moves
    @State private var moves: [(name: String, state: String)] = [
        ("Toprock", "MASTERY"),
        ("Windmill", "LEARNING"),
        ("Headspin", "NEW"),
    ]
    @State private var activeIndex: Int? = 0   // Currently selected node in the timeline
    @State private var showPicker = false       // Controls the "add move" sheet

    // Mock moves available to add from the picker sheet
    private let availableMoves = ["Flare", "Swipe", "Air Chair", "Backspin", "Freeze"]

    var body: some View {
        VStack(spacing: 0) {
            // --- Add Move Button ---
            Button("+ Add Move to Combo") {
                showPicker = true
            }
            .font(.ibmPlexMono(size: 16, weight: .bold))
            .foregroundColor(.accent)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)

            // --- Preview Area ---
            // Shows details of the currently selected timeline node.
            VStack(spacing: 12) {
                if let idx = activeIndex, idx < moves.count {
                    // Active node selected — show its icon, name, and learning state
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.accent)
                    Text(moves[idx].name)
                        .font(.ibmPlexMono(size: 20, weight: .bold))
                        .foregroundColor(.textPrimary)
                    StatePillView(learningState: moves[idx].state)
                } else {
                    // No node selected — empty state
                    Image(systemName: "video.slash")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("Select a move to preview")
                        .font(.ibmPlexMono(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .background(Color.neutralFill.opacity(0.3))
            .animation(AppAnimation.springSmooth, value: activeIndex)  // Animate preview transitions

            // --- Timeline Strip ---
            // Horizontal scrollable row of numbered nodes connected by lines.
            VStack(spacing: 16) {
                Text("Your Combo")
                    .font(.ibmPlexMono(size: 18, weight: .bold))
                    .foregroundColor(.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(moves.enumerated()), id: \.offset) { index, move in
                            HStack(spacing: 0) {
                                VStack(spacing: 6) {
                                    // Numbered circle node — active node is highlighted
                                    TimelineNodeView(
                                        sequenceNumber: index + 1,
                                        isActive: activeIndex == index,
                                        onDelete: {
                                            // Remove this move from the combo
                                            withAnimation(AppAnimation.springSmooth) {
                                                moves.remove(at: index)
                                                // Adjust selection after removal
                                                if moves.isEmpty {
                                                    activeIndex = nil
                                                } else if index <= (activeIndex ?? 0) {
                                                    activeIndex = max(0, (activeIndex ?? 1) - 1)
                                                }
                                            }
                                        },
                                        showDelete: activeIndex == index  // Only show X on the active node
                                    )
                                    .onTapGesture {
                                        // Select this node
                                        withAnimation(AppAnimation.springSmooth) {
                                            activeIndex = index
                                        }
                                    }

                                    // Move name label below the node
                                    Text(move.name)
                                        .font(.ibmPlexMono(size: 10))
                                        .foregroundColor(.textPrimary)
                                        .frame(width: 50)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }

                                // Connector line between nodes (not after the last one)
                                if index < moves.count - 1 {
                                    Rectangle()
                                        .frame(width: 20, height: 2)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 100)

                // Save button — disabled when combo is empty
                Button("Save Combo") {}
                    .font(.ibmPlexMono(size: 16, weight: .bold))
                    .buttonStyle(.borderedProminent)
                    .tint(.accent)
                    .controlSize(.large)
                    .disabled(moves.isEmpty)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 16)
        }
        .background(Color.backgroundPrimary)
        // --- Move Picker Sheet ---
        // Presented modally when "Add Move" is tapped.
        // Selecting a move appends it to the combo with a random learning state.
        .sheet(isPresented: $showPicker) {
            NavigationView {
                List(availableMoves, id: \.self) { name in
                    Button {
                        withAnimation(AppAnimation.springSmooth) {
                            // Add move with random state for demo purposes
                            moves.append((name: name, state: ["NEW", "LEARNING", "MASTERY"].randomElement()!))
                            activeIndex = moves.count - 1  // Select the newly added node
                        }
                        showPicker = false
                    } label: {
                        HStack {
                            // Color indicator bar (always stateNew for simplicity)
                            Capsule().fill(Color.stateNew).frame(width: 5, height: 30)
                            Text(name)
                                .font(.headline)
                                .padding(.leading, 8)
                            Spacer()
                        }
                    }
                }
                .listStyle(.plain)
                .navigationTitle("Add Move to Combo")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showPicker = false }
                    }
                }
            }
        }
    }
}

#Preview("Combo Builder - Dark") { ComboTimelineCatalogView().preferredColorScheme(.dark) }
#Preview("Combo Builder - Light") { ComboTimelineCatalogView().preferredColorScheme(.light) }

// MARK: - Interactive: Move Picker Row (Real Layout)
// Simulates the MovePickerSheet — a searchable list of moves.
// Selecting a move shows a checkmark. Typing in search filters the list.
// Tests: searchable modifier, state-colored indicators, animation transitions.

struct MovePickerCatalogView: View {
    @State private var searchText = ""       // Bound to .searchable
    @State private var selectedMove: String?  // Currently selected move (shows checkmark)

    // Mock move data with learning states
    private let moves: [(name: String, state: String)] = [
        ("Windmill", "NEW"), ("Headspin", "LEARNING"), ("Toprock", "MASTERY"),
        ("Six Step", "MASTERY"), ("Flare", "NEW"), ("Swipe", "LEARNING"),
    ]

    /// Filters the move list by search text (case-insensitive)
    var filtered: [(name: String, state: String)] {
        if searchText.isEmpty { return moves }
        return moves.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationView {
            List(filtered, id: \.name) { move in
                Button {
                    withAnimation(AppAnimation.springSmooth) {
                        selectedMove = move.name
                    }
                } label: {
                    HStack {
                        // Vertical color indicator bar — colored by learning state
                        Capsule()
                            .fill(stateColor(move.state))
                            .frame(width: 5, height: 30)
                        Text(move.name)
                            .font(.headline)
                            .padding(.leading, 8)
                        Spacer()
                        // Checkmark appears with scale+opacity transition when selected
                        if selectedMove == move.name {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accent)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Add Move to Combo")
            .searchable(text: $searchText, prompt: "Search Moves...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {}
                }
            }
        }
    }

    /// Maps learning state raw string to its design system color
    private func stateColor(_ state: String) -> Color {
        switch state {
        case "LEARNING": return .stateLearning
        case "MASTERY": return .stateMastery
        default: return .stateNew
        }
    }
}

#Preview("Move Picker - Dark") { MovePickerCatalogView().preferredColorScheme(.dark) }
#Preview("Move Picker - Light") { MovePickerCatalogView().preferredColorScheme(.light) }

// MARK: - Interactive: Video Player States (Real Layout)
// Simulates the three states of CustomVideoPlayerView:
// 0 = Loading (spinner), 1 = Error (unavailable), 2 = Playing (gradient placeholder).
// Also tests mute toggle and fullscreen presentation.

struct VideoPlayerCatalogView: View {
    @State private var currentState = 0    // 0=Loading, 1=Error, 2=Playing
    @State private var isMuted = false
    @State private var isFullscreen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                Text("VIDEO PLAYER STATES")
                    .font(.ibmPlexMono(size: 12, weight: .bold))
                    .foregroundColor(.textSecondary)

                // --- State Switcher Tabs ---
                // Three buttons to switch between Loading/Error/Playing states.
                HStack(spacing: Spacing.sm) {
                    ForEach(Array(["Loading", "Error", "Playing"].enumerated()), id: \.offset) { idx, label in
                        Button {
                            withAnimation(AppAnimation.springSmooth) { currentState = idx }
                        } label: {
                            Text(label)
                                .font(.ibmPlexMono(size: 12, weight: currentState == idx ? .bold : .regular))
                                .foregroundColor(currentState == idx ? .accent : .textSecondary)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.sm)
                                .background(currentState == idx ? Color.accent.opacity(0.15) : Color.clear)
                                .cornerRadius(Radius.md)
                        }
                    }
                }

                // --- Player Content ---
                // Switches between three states based on currentState.
                ZStack {
                    switch currentState {
                    case 0:
                        // LOADING — spinner + "Loading video..." text
                        VStack(spacing: 12) {
                            ProgressView().tint(.accent)
                            Text("Loading video...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.neutralFill)
                        .cornerRadius(10)

                    case 1:
                        // ERROR — "Video Unavailable" with icon and message
                        VStack(spacing: 12) {
                            Image(systemName: "video.slash")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("Video Unavailable")
                                .font(.headline)
                                .foregroundColor(.textPrimary)
                            Text("No video file found for this move")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.neutralFill)
                        .cornerRadius(10)

                    default:
                        // PLAYING — gradient placeholder with mute + fullscreen controls
                        ZStack(alignment: .topTrailing) {
                            // Gradient simulates video content
                            LinearGradient(
                                colors: [.accent.opacity(0.3), .stateLearning.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .overlay(
                                Image(systemName: "figure.dance")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.3))
                            )

                            // Overlay controls — mute toggle + fullscreen button
                            HStack(spacing: 12) {
                                Button {
                                    isMuted.toggle()
                                } label: {
                                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }

                                Button {
                                    isFullscreen = true
                                } label: {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                            }
                            .padding(16)
                        }
                        .cornerRadius(10)
                    }
                }
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Mute indicator text
                if isMuted {
                    Text("Muted")
                        .font(.ibmPlexMono(size: 12))
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(Spacing.xl)
        }
        .background(Color.backgroundPrimary)
        // Fullscreen cover — presented when the expand button is tapped
        .fullScreenCover(isPresented: $isFullscreen) {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    HStack {
                        Spacer()
                        // Close button
                        Button {
                            isFullscreen = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    Spacer()
                    // Placeholder content
                    Image(systemName: "figure.dance")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.3))
                    Text("Fullscreen Preview")
                        .font(.ibmPlexMono(size: 16))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
            }
        }
    }
}

#Preview("Video Player - Dark") { VideoPlayerCatalogView().preferredColorScheme(.dark) }
#Preview("Video Player - Light") { VideoPlayerCatalogView().preferredColorScheme(.light) }

// MARK: - Interactive: Animation Playground
// Visualizes all AppAnimation presets side by side.
// A "Trigger" button moves accent circles horizontally using each animation curve.
// This lets you directly compare spring response, damping, and feel.

struct AnimationCatalogView: View {
    @State private var trigger = false  // Toggles all animations simultaneously

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                Text("ANIMATION PRESETS")
                    .font(.ibmPlexMono(size: 12, weight: .bold))
                    .foregroundColor(.textSecondary)

                // Master trigger button — toggles all animations at once
                Button {
                    trigger.toggle()
                } label: {
                    Text(trigger ? "Reset" : "Trigger All")
                        .font(.ibmPlexMono(size: 14, weight: .bold))
                        .foregroundColor(.backgroundPrimary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.accent)
                        .clipShape(Capsule())
                }

                // Each row: a circle that slides 120pt right using its animation curve.
                // The desc shows "response / dampingFraction" values for spring curves.
                ForEach([
                    ("buttonPress", AppAnimation.buttonPress, "0.2 / 0.7"),
                    ("springInteractive", AppAnimation.springInteractive, "0.3 / 0.6"),
                    ("springSmooth", AppAnimation.springSmooth, "0.4 / 0.8"),
                    ("springBouncy", AppAnimation.springBouncy, "0.5 / 0.7"),
                    ("springGentle", AppAnimation.springGentle, "0.6 / 0.8"),
                ], id: \.0) { name, anim, desc in
                    HStack(spacing: Spacing.md) {
                        // Animated circle — slides right when triggered
                        Circle().fill(Color.accent).frame(width: 24, height: 24)
                            .offset(x: trigger ? 120 : 0)
                            .animation(anim, value: trigger)
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(name).font(.ibmPlexMono(size: 13, weight: .bold)).foregroundColor(.textPrimary)
                            Text(desc).font(.ibmPlexMono(size: 10)).foregroundColor(.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, Spacing.sm)
                }
            }
            .padding(Spacing.xl)
        }
        .background(Color.backgroundPrimary)
    }
}

#Preview("Animations - Dark") { AnimationCatalogView().preferredColorScheme(.dark) }
#Preview("Animations - Light") { AnimationCatalogView().preferredColorScheme(.light) }

// MARK: - Full Design System Overview (Interactive)
// A compact "cheat sheet" that puts every design token category on a single scrollable screen.
// Interactive elements: tappable state pills, timeline nodes, review buttons.
// This is the go-to preview for verifying the entire design system works together.

struct DesignSystemOverviewView: View {
    @State private var selectedState = "NEW"  // Currently selected state pill
    @State private var activeNode = 0         // Currently selected timeline node
    @State private var reviewCount = 0        // Total reviews across all buttons
    @State private var lastReview: String?    // Most recent review rating

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxxl) {

                    // --- Colors ---
                    // Three rows of color swatches: backgrounds, states, actions
                    sectionTitle("COLORS")
                    colorStrip([("BG", Color.backgroundPrimary), ("Text", Color.textPrimary), ("Accent", Color.accent), ("Fill", Color.neutralFill)])
                    colorStrip([("New", Color.stateNew), ("Learn", Color.stateLearning), ("Master", Color.stateMastery)])
                    colorStrip([("Again", Color.buttonAgain), ("Hard", Color.buttonHard), ("Good", Color.buttonGood)])

                    // --- Typography ---
                    // Three sample lines at different scale levels
                    sectionTitle("TYPOGRAPHY")
                    Text("titleLarge 32").font(.titleLarge).foregroundColor(.textPrimary)
                    Text("bodyMedium 16").font(.bodyMedium).foregroundColor(.textPrimary)
                    Text("caption 12").font(.caption).foregroundColor(.textSecondary)

                    // --- State Pills ---
                    // Tappable pills — the selected one scales up with a bouncy animation
                    sectionTitle("STATE PILL")
                    HStack(spacing: Spacing.sm) {
                        ForEach(["NEW", "LEARNING", "MASTERY"], id: \.self) { state in
                            Button { withAnimation(AppAnimation.springBouncy) { selectedState = state } } label: {
                                StatePillView(learningState: state)
                            }
                            .scaleEffect(selectedState == state ? 1.15 : 1.0)
                            .animation(AppAnimation.springBouncy, value: selectedState)
                        }
                    }

                    // --- Timeline Nodes ---
                    // Three tappable numbered circles connected by lines
                    sectionTitle("TIMELINE")
                    HStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { i in
                            HStack(spacing: 0) {
                                TimelineNodeView(sequenceNumber: i + 1, isActive: activeNode == i, onDelete: {}, showDelete: false)
                                    .onTapGesture { withAnimation(AppAnimation.springSmooth) { activeNode = i } }
                                if i < 2 { Rectangle().frame(width: 24, height: 2).foregroundColor(.gray) }
                            }
                        }
                    }

                    // --- Review Buttons ---
                    // Three colored buttons with a tap counter
                    sectionTitle("REVIEW (\(reviewCount))")
                    HStack(spacing: Spacing.sm) {
                        ForEach([("AGAIN", Color.buttonAgain), ("HARD", Color.buttonHard), ("GOOD", Color.buttonGood)], id: \.0) { label, color in
                            Button {
                                withAnimation(AppAnimation.springSmooth) { reviewCount += 1; lastReview = label }
                            } label: {
                                Text(label)
                                    .font(.ibmPlexMono(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity).frame(height: 44)
                                    .background(color)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(ReviewButtonStyle())
                        }
                    }

                    // Shows the last rating pressed
                    if let r = lastReview {
                        Text("Last: \(r)")
                            .font(.ibmPlexMono(size: 11))
                            .foregroundColor(.textSecondary)
                    }
                }
                .padding(Spacing.xl)
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("BREAKDEX DS")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// Small bold section label in muted color
    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.ibmPlexMono(size: 12, weight: .bold)).foregroundColor(.textSecondary).padding(.top, Spacing.sm)
    }

    /// Horizontal row of small color swatches with labels underneath
    private func colorStrip(_ colors: [(String, Color)]) -> some View {
        HStack(spacing: Spacing.sm) {
            ForEach(colors, id: \.0) { name, color in
                VStack(spacing: Spacing.xs) {
                    RoundedRectangle(cornerRadius: Radius.sm).fill(color).frame(height: 36)
                        .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(Color.textSecondary.opacity(0.3), lineWidth: 1))
                    Text(name).font(.ibmPlexMono(size: 9)).foregroundColor(.textSecondary)
                }
            }
        }
    }
}

#Preview("Design System - Dark") { DesignSystemOverviewView().preferredColorScheme(.dark) }
#Preview("Design System - Light") { DesignSystemOverviewView().preferredColorScheme(.light) }
