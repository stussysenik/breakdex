//
//  StatePillView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/27/25.
//

import SwiftUI

struct StatePillView: View {
    let learningState: String?
    
    private var stateColor: Color {
        switch learningState {
        case "NEW":
            return .stateNew
        case "LEARNING":
            return .stateLearning
        case "MASTERY":
            return .stateMastery
        default:
            return .stateNew
        }
    }
    
    private var stateText: String {
        learningState ?? "NEW"
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)
                .scaleEffect(1.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0).delay(0.1), value: stateColor)
            Text(stateText)
                .font(.ibmPlexMono(size: 10, weight: .bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(stateColor.opacity(0.2))
        .foregroundColor(stateColor)
        .clipShape(Capsule())
        .scaleEffect(1.0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0), value: stateColor)
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
