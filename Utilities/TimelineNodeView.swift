// In TimelineNodeView.swift
import SwiftUI

struct TimelineNodeView: View {
    let sequenceNumber: Int
    let isActive: Bool
    let onDelete: () -> Void
    let move: Move?
    let showDelete: Bool
    
    init(sequenceNumber: Int, isActive: Bool, onDelete: @escaping () -> Void, move: Move? = nil, showDelete: Bool = true) {
        self.sequenceNumber = sequenceNumber
        self.isActive = isActive
        self.onDelete = onDelete
        self.move = move
        self.showDelete = showDelete
    }
    
    private var borderColor: Color {
        if isActive {
            return .accent
        } else if let move = move {
            switch move.learningState {
            case "NEW": return .stateNew
            case "LEARNING": return .stateLearning
            case "MASTERY": return .stateMastery
            default: return .gray
            }
        } else {
            return .gray
        }
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .strokeBorder(borderColor, lineWidth: isActive ? 4 : 2)
                .background(Circle().fill(isActive ? Color.white : Color.gray.opacity(0.3)))
                .frame(width: isActive ? 60 : 50, height: isActive ? 60 : 50)
                .overlay(
                    Text("\(sequenceNumber)")
                        .font(.ibmPlexMono(size: isActive ? 18 : 16, weight: isActive ? .bold : .regular))
                        .foregroundColor(isActive ? .black : .white)
                )
            
            if isActive && showDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white).frame(width: 20, height: 20))
                }
                .offset(x: 6, y: -6)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 70, height: 70) // Fixed container size to prevent overflow
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isActive)
    }
}

#Preview {
    TimelineNodeView(sequenceNumber: 1, isActive: false, onDelete: {}, move: nil, showDelete: true)
}
