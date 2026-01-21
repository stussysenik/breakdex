//
//  BreadcrumbView.swift
//  breakdex
//
//  Created for Arsenal navigation improvements
//

import SwiftUI
import OSLog

// MARK: - Breadcrumb View
/// Reusable breadcrumb navigation component for hierarchical navigation display
/// Displays path segments separated by ">" with tappable items for navigation
public struct BreadcrumbView: View {
    
    // MARK: - Properties
    let path: [String]
    var onTapSegment: ((Int) -> Void)?
    var onBack: (() -> Void)?
    
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🧭 BREADCRUMB")
    
    // MARK: - Initialization
    public init(
        path: [String],
        onTapSegment: ((Int) -> Void)? = nil,
        onBack: (() -> Void)? = nil
    ) {
        self.path = path
        self.onTapSegment = onTapSegment
        self.onBack = onBack
    }
    
    // MARK: - Body
    public var body: some View {
        HStack(spacing: 4) {
            // Back button (if there's a back action)
            if let onBack = onBack {
                Button(action: {
                    logger.info("🧭 BREADCRUMB: Back button tapped")
                    onBack()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
            
            // Breadcrumb segments
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(path.enumerated()), id: \.offset) { index, segment in
                        HStack(spacing: 6) {
                            // Separator (not for first item)
                            if index > 0 {
                                Text(">")
                                    .font(.ibmPlexMono(size: 12, weight: .regular))
                                    .foregroundColor(.textSecondary)
                            }
                            
                            // Segment text
                            if let onTapSegment = onTapSegment, index < path.count - 1 {
                                // Tappable segment (not the last/current one)
                                Button(action: {
                                    logger.info("🧭 BREADCRUMB: Tapped segment [\(index)]: \(segment)")
                                    onTapSegment(index)
                                }) {
                                    Text(segment.uppercased())
                                        .font(.ibmPlexMono(size: 12, weight: .medium))
                                        .foregroundColor(.textSecondary)
                                }
                                .buttonStyle(.plain)
                            } else {
                                // Current segment (last item, not tappable)
                                Text(segment.uppercased())
                                    .font(.ibmPlexMono(size: 12, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview
#Preview("Breadcrumb - Arsenal") {
    VStack(spacing: 20) {
        BreadcrumbView(path: ["BREAKDEX", "ARSENAL"])
        
        BreadcrumbView(path: ["BREAKDEX", "ARSENAL", "MOVES"])
        
        BreadcrumbView(
            path: ["BREAKDEX", "ARSENAL", "MOVES", "Windmill"],
            onBack: { print("Back tapped") }
        )
        
        BreadcrumbView(
            path: ["BREAKDEX", "ARSENAL", "COMBOS"],
            onTapSegment: { index in print("Tapped segment: \(index)") },
            onBack: { print("Back tapped") }
        )
    }
    .padding()
    .background(Color.backgroundPrimary)
}
