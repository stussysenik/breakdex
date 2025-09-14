import SwiftUI

struct AddMoveErrorView: View {
    @Bindable var viewModel: AddMoveViewModel
    let message: String
    let underlyingError: Error?
    @Binding var selectedTab: TabSelection // Added selectedTab binding
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("Error Message Text") // Added accessibility identifier
            
            if let error = underlyingError {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("Underlying Error Text") // Added accessibility identifier
            }
            
            HStack(spacing: 12) {
                Button("Try Again") { // Changed button text
                    viewModel.reset() // Reset to allow retrying the flow
                }
                .buttonStyle(.appPrimary(size: .small))
                .accessibilityIdentifier("Try Again Button")
                
                Button("Cancel") { // Changed button text
                    selectedTab = .arsenal // Switch to Arsenal tab
                    viewModel.reset() // Reset the AddMoveViewModel state
                }
                .buttonStyle(.appSecondary(size: .small))
                .accessibilityIdentifier("Cancel Button")
            }
        }
        .padding()
    }
}

