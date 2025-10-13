// import SwiftUI
// import CoreData

// // Simple protocol for Move-like objects
// protocol MoveProtocol {
//     var name: String? { get }
//     var learningState: String? { get }
// }

// // MARK: - Timeline Node View
// /// Simple timeline node component for combo sequences
// /// Essentialist design - minimal and focused
// public struct TimelineNodeView: View {

//     // MARK: - Properties
//     let sequenceNumber: Int
//     let isActive: Bool
//     let onDelete: () -> Void
//     let move: MoveProtocol
//     let showDelete: Bool

//     // MARK: - Body
//     public var body: some View {
//         VStack(spacing: 8) {
//             ZStack {
//                 Circle()
//                     .fill(backgroundColor)
//                     .frame(width: 44, height: 44)
//                     .overlay(
//                         Circle()
//                             .stroke(borderColor, lineWidth: 2)
//                     )

//                 Text("\(sequenceNumber)")
//                     .font(.system(size: 16, weight: .semibold, design: .rounded))
//                     .foregroundColor(textColor)
//             }

//             if showDelete {
//                 Button(action: onDelete) {
//                     Image(systemName: "minus.circle.fill")
//                         .font(.system(size: 20))
//                         .foregroundColor(.red)
//                 }
//                 .buttonStyle(PlainButtonStyle())
//             } else {
//                 // Spacer for alignment when no delete button
//                 Rectangle()
//                     .fill(Color.clear)
//                     .frame(width: 20, height: 20)
//             }
//         }
//     }

//     // MARK: - Styling
//     private var backgroundColor: Color {
//         if isActive {
//             return Color.blue
//         } else {
//             return move.learningState?.uppercased() == "MASTERY" ? Color.green.opacity(0.3) :
//                    move.learningState?.uppercased() == "LEARNING" ? Color.orange.opacity(0.3) :
//                    Color.gray.opacity(0.3)
//         }
//     }

//     private var borderColor: Color {
//         if isActive {
//             return Color.blue
//         } else {
//             return move.learningState?.uppercased() == "MASTERY" ? Color.green :
//                    move.learningState?.uppercased() == "LEARNING" ? Color.orange :
//                    Color.gray
//         }
//     }

//     private var textColor: Color {
//         if isActive {
//             return .white
//         } else {
//             return move.learningState?.uppercased() == "MASTERY" ? Color.green :
//                    move.learningState?.uppercased() == "LEARNING" ? Color.orange :
//                    Color.gray
//         }
//     }

//     // MARK: - Initialization
//     init(
//         sequenceNumber: Int,
//         isActive: Bool,
//         onDelete: @escaping () -> Void,
//         move: MoveProtocol,
//         showDelete: Bool
//     ) {
//         self.sequenceNumber = sequenceNumber
//         self.isActive = isActive
//         self.onDelete = onDelete
//         self.move = move
//         self.showDelete = showDelete
//     }
// }

// // MARK: - Preview
// #Preview("Timeline Node View") {
//     VStack(spacing: 20) {
//         // Create a simple mock move without Core Data for preview
//         let mockMove = MockMove(name: "Test Move", learningState: "LEARNING")

//         TimelineNodeView(
//             sequenceNumber: 1,
//             isActive: false,
//             onDelete: {},
//             move: mockMove,
//             showDelete: true
//         )

//         TimelineNodeView(
//             sequenceNumber: 2,
//             isActive: true,
//             onDelete: {},
//             move: mockMove,
//             showDelete: false
//         )
//     }
//     .padding()
// }

// // Mock Move for preview purposes
// private struct MockMove: MoveProtocol {
//     let name: String?
//     let learningState: String?
// }

// extension Move: MoveProtocol {}