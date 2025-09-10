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
    case capsuleHandles
    case thinVerticalBars

    var displayName: String {
        switch self {
        case .capsuleHandles: return "Capsule Handles"
        case .thinVerticalBars: return "Thin Vertical Bars"
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
        handleStyle: .capsuleHandles,
        backgroundColor: Color.secondary.opacity(0.3),
        accentColor: .blue,
        trackHeight: 8,
        handleSize: CGSize(width: 44, height: 60)
    )

    static let classic = TrimmerConfiguration(
        handleStyle: .thinVerticalBars,
        backgroundColor: Color.secondary.opacity(0.3),
        accentColor: .blue,
        trackHeight: 8,
        handleSize: CGSize(width: 44, height: 60)
    )

    static let minimal = TrimmerConfiguration(
        handleStyle: .capsuleHandles,
        backgroundColor: Color.secondary.opacity(0.3),
        accentColor: .gray,
        trackHeight: 6,
        handleSize: CGSize(width: 40, height: 50)
    )

    static let professionalCapsule = TrimmerConfiguration(
        handleStyle: .capsuleHandles,
        backgroundColor: .clear, // Minimal background
        accentColor: .accentColor, // Single accent color
        trackHeight: 4, // Thin track
        handleSize: CGSize(width: 44, height: 44) // Proper hit target
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
}

// MARK: - Professional Capsule Handle View
struct CapsuleHandle: View {
    let isStartHandle: Bool

    var body: some View {
        HandleView {
            ZStack {
                // Visual capsule (20x32 for more elegant proportions)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.95))
                    .frame(width: 20, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: 2)
                            .shadow(color: Color.accentColor.opacity(0.4), radius: 3, x: 0, y: 1)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
        }
    }
}

// MARK: - Thin Vertical Handle View
struct ThinVerticalHandle: View {
    let isStartHandle: Bool

    var body: some View {
        HandleView {
            ZStack {
                // Thin vertical capsule (8px wide, 44px tall)
                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 8, height: 44)
                    .overlay(
                        Capsule()
                            .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
            }
        }
    }
}

// MARK: - Predefined Handle Styles
extension HandleStyle {
    // Only two handle styles: professional capsule and thin vertical bars
    static let allPresets: [HandleStyle] = [.capsuleHandles, .thinVerticalBars]
}

// MARK: - Trimmer Factory
enum TrimmerFactory {
    static func createTrimmer(
        with configuration: TrimmerConfiguration,
        viewModel: TrimmerViewModel
    ) -> some View {
        switch configuration.handleStyle {
        case .capsuleHandles:
            return AnyView(
                HybridPreciseTrimmerView.custom(
                    viewModel: viewModel,
                    startView: AnyView(CapsuleHandle(isStartHandle: true)),
                    endView: AnyView(CapsuleHandle(isStartHandle: false))
                )
            )
        case .thinVerticalBars:
            return AnyView(
                HybridPreciseTrimmerView.custom(
                    viewModel: viewModel,
                    startView: AnyView(ThinVerticalHandle(isStartHandle: true)),
                    endView: AnyView(ThinVerticalHandle(isStartHandle: false))
                )
            )
        }
    }
}
