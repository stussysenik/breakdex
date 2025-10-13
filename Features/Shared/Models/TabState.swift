// import Foundation

// // MARK: - Tab Selection
// /// Tab selection for AddMove flow - essentialist approach with only necessary states
// public enum TabSelection: CaseIterable {
//     case ready     // Initial state, ready to select video
//     case add       // Add new video from library
//     case trimming  // Video trimming interface
//     case naming    // Naming the move
//     case saving    // Saving process
//     case arsenal   // Arsenal tab (for navigation back to main view)
// }

// // MARK: - Flow State
// /// Overall flow state for AddMove feature - tracks current operation
// public enum AddMoveFlowState: Equatable {
//     case ready                 // Initial ready state
//     case loading               // Initial loading or video processing
//     case loadingVideo          // Loading video from library/iCloud
//     case loadingTrimmedAsset(SimpleProgress) // Loading trimmed asset with progress
//     case trimming              // User is trimming video
//     case naming                // User is entering move name
//     case saving                // Saving in progress
//     case success(String)       // Process completed successfully with message
//     case done                  // Process completed successfully
//     case error(String, String?) // Error state with message and underlying error
// }

// // MARK: - Convenience Extensions
// extension TabSelection {
//     /// Next tab in the flow
//     var next: TabSelection? {
//         switch self {
//         case .ready: return .add
//         case .add: return .trimming
//         case .trimming: return .naming
//         case .naming: return .saving
//         case .saving: return nil
//         case .arsenal: return nil
//         }
//     }

//     /// Previous tab in the flow
//     var previous: TabSelection? {
//         switch self {
//         case .ready: return nil
//         case .add: return .ready
//         case .trimming: return .add
//         case .naming: return .trimming
//         case .saving: return .naming
//         case .arsenal: return nil
//         }
//     }

//     /// Localized display name
//     var displayName: String {
//         switch self {
//         case .ready: return "Ready"
//         case .add: return "Add"
//         case .trimming: return "Trim"
//         case .naming: return "Name"
//         case .saving: return "Save"
//         case .arsenal: return "Arsenal"
//         }
//     }
// }

// // MARK: - Equatable Conformance
// extension AddMoveFlowState {
//     public static func == (lhs: AddMoveFlowState, rhs: AddMoveFlowState) -> Bool {
//         switch (lhs, rhs) {
//         case (.ready, .ready),
//              (.loading, .loading),
//              (.loadingVideo, .loadingVideo),
//              (.trimming, .trimming),
//              (.naming, .naming),
//              (.saving, .saving),
//              (.done, .done):
//             return true
//         case (.loadingTrimmedAsset(let lhsProgress), .loadingTrimmedAsset(let rhsProgress)):
//             return lhsProgress == rhsProgress
//         case (.success(let lhsMessage), .success(let rhsMessage)):
//             return lhsMessage == rhsMessage
//         case (.error(let lhsMessage, let lhsUnderlying), .error(let rhsMessage, let rhsUnderlying)):
//             return lhsMessage == rhsMessage && lhsUnderlying == rhsUnderlying
//         default:
//             return false
//         }
//     }
// }

// // MARK: - AddMoveFlowState Convenience Extensions
// extension AddMoveFlowState {
//     /// Check if state represents a loading operation
//     var isLoading: Bool {
//         switch self {
//         case .loading, .loadingVideo, .loadingTrimmedAsset, .saving:
//             return true
//         case .ready, .trimming, .naming, .success, .done, .error:
//             return false
//         }
//     }
// }