//
//  StatePillView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/27/25.
//

import SwiftUI

struct StatePillView: View {
    let learningState: String?

    private var resolvedState: LearningState {
        LearningState.resolve(from: learningState)
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(resolvedState.color)
                .frame(width: 9, height: 9)
                .scaleEffect(1.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0).delay(0.1), value: resolvedState)
            Text(resolvedState.displayText)
                .font(.ibmPlexMono(size: 12, weight: .bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(resolvedState.color.opacity(0.2))
        .foregroundColor(resolvedState.color)
        .clipShape(Capsule())
        .scaleEffect(1.0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0), value: resolvedState)
    }
}

#Preview {
    HStack {
        StatePillView(learningState: "NEW")
        StatePillView(learningState: "LEARNING")
        StatePillView(learningState: "MASTERY")
    }
    .padding()
}
