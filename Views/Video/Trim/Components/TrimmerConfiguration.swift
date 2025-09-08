//
//  TrimmerConfiguration.swift
//  BreakingFlashcards
//
//  Created by AI Assistant
//  Configuration system for flexible handle styling
//

import SwiftUI

// MARK: - Handle Style Enum
enum HandleStyle {
    case emoji(start: String, end: String)
    case symbols(start: String, end: String)
    case custom(start: AnyView, end: AnyView)

    var displayName: String {
        switch self {
        case .emoji(let start, let end): return "\(start) → \(end)"
        case .symbols(let start, let end): return "\(start) → \(end)"
        case .custom: return "Custom Views"
        }
    }
}

// MARK: - Trimmer Configuration
struct TrimmerConfiguration {
    let handleStyle: HandleStyle
    let backgroundColor: Color
    let accentColor: Color
    let trackHeight: CGFloat
    let handleSize: CGSize

    static let `default` = TrimmerConfiguration(
        handleStyle: .emoji(start: "👟", end: "🔥"),
        backgroundColor: Color.secondary.opacity(0.3),
        accentColor: .blue,
        trackHeight: 8,
        handleSize: CGSize(width: 44, height: 60)
    )

    static let classic = TrimmerConfiguration(
        handleStyle: .symbols(start: "scissors", end: "scissors"),
        backgroundColor: Color.secondary.opacity(0.3),
        accentColor: .blue,
        trackHeight: 8,
        handleSize: CGSize(width: 44, height: 60)
    )

    static let playful = TrimmerConfiguration(
        handleStyle: .emoji(start: "🎯", end: "🎪"),
        backgroundColor: Color.secondary.opacity(0.3),
        accentColor: .purple,
        trackHeight: 8,
        handleSize: CGSize(width: 44, height: 60)
    )

    static let minimal = TrimmerConfiguration(
        handleStyle: .custom(
            start: AnyView(Capsule().fill(Color.blue.opacity(0.8))),
            end: AnyView(Capsule().fill(Color.red.opacity(0.8)))
        ),
        backgroundColor: Color.secondary.opacity(0.3),
        accentColor: .gray,
        trackHeight: 6,
        handleSize: CGSize(width: 40, height: 50)
    )

    // MARK: - Factory Methods
    static func createWithStyle(_ style: HandleStyle) -> TrimmerConfiguration {
        TrimmerConfiguration(
            handleStyle: style,
            backgroundColor: Color.secondary.opacity(0.3),
            accentColor: .blue,
            trackHeight: 8,
            handleSize: CGSize(width: 44, height: 60)
        )
    }

    static func emoji(start: String, end: String) -> TrimmerConfiguration {
        createWithStyle(.emoji(start: start, end: end))
    }

    static func symbols(start: String, end: String) -> TrimmerConfiguration {
        createWithStyle(.symbols(start: start, end: end))
    }

    static func custom(startView: some View, endView: some View) -> TrimmerConfiguration {
        createWithStyle(.custom(
            start: AnyView(startView),
            end: AnyView(endView)
        ))
    }
}

// MARK: - Predefined Handle Styles
extension HandleStyle {
    static let sneakers = HandleStyle.emoji(start: "👟", end: "🔥")
    static let scissors = HandleStyle.symbols(start: "scissors", end: "scissors")
    static let arrows = HandleStyle.symbols(start: "arrow.left", end: "arrow.right")
    static let circles = HandleStyle.symbols(start: "circle.fill", end: "circle")
    static let stars = HandleStyle.emoji(start: "⭐", end: "🌟")
    static let hearts = HandleStyle.emoji(start: "💙", end: "❤️")
    static let animals = HandleStyle.emoji(start: "🐱", end: "🐶")
    static let food = HandleStyle.emoji(start: "🍎", end: "🍊")

    static let allPresets: [HandleStyle] = [
        .sneakers, .scissors, .arrows, .circles,
        .stars, .hearts, .animals, .food
    ]
}

// MARK: - Trimmer Factory
enum TrimmerFactory {
    static func createTrimmer(
        with configuration: TrimmerConfiguration,
        viewModel: TrimmerViewModel
    ) -> some View {
        switch configuration.handleStyle {
        case .emoji(let start, let end):
            return AnyView(
                HybridPreciseTrimmerView.emoji(
                    viewModel: viewModel,
                    startEmoji: start,
                    endEmoji: end
                )
            )
        case .symbols(let start, let end):
            return AnyView(
                HybridPreciseTrimmerView.symbols(
                    viewModel: viewModel,
                    startSymbol: start,
                    endSymbol: end
                )
            )
        case .custom(let start, let end):
            return AnyView(
                HybridPreciseTrimmerView.custom(
                    viewModel: viewModel,
                    startView: start,
                    endView: end
                )
            )
        }
    }
}
