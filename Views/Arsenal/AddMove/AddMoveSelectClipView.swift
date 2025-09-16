import SwiftUI
import PhotosUI
import OSLog


// AddMoveState and AddMoveError are defined in AddMoveState.swift

// Select a Clip page
private let logger = Logger(subsystem: "com.breakingflashcards", category: "AddMoveSelectClip")

struct AppPhotosPickerButton: View {
    @Binding var selection: PhotosPickerItem?
    
    var body: some View {
        PhotosPicker(
            selection: $selection,
            matching: .videos,
            preferredItemEncoding: .current,
            photoLibrary: .shared()
        ) {
            Text("Select a Clip")
        }
        .buttonStyle(.photosPicker(type: .primary))
        .accessibilityIdentifier("Select a Clip Button")
        .onChange(of: selection) { oldValue, newValue in
            logger.info("🎬 PHOTO_PICKER: Selection changed")
            logger.info("🎬 PHOTO_PICKER: Old value: \(oldValue?.itemIdentifier ?? "nil")")
            logger.info("🎬 PHOTO_PICKER: New value: \(newValue?.itemIdentifier ?? "nil")")
            
            if let newValue = newValue {
                logger.info("🎬 PHOTO_PICKER: New selection details:")
                logger.info("   - Item ID: \(newValue.itemIdentifier ?? "nil")")
                logger.info("   - Supported types: \(newValue.supportedContentTypes)")
            } else {
                logger.info("🎬 PHOTO_PICKER: Selection cleared")
            }
        }
    }
}

struct AddMoveSelectClipView: View {
    @Bindable var viewModel: AddMoveViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            switch viewModel.state {
            case .ready:
                VStack {
                    Spacer()
                    //
                    AppPhotosPickerButton(selection: $viewModel.selectedItem)
                    
                    Spacer()
                }
                .background(Color.black.ignoresSafeArea())
            case .selectingVideo(_):
                VStack {
                    Spacer()
                    Text("Selecting video...")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .background(Color.black.ignoresSafeArea())
            case .loading(progress: let progress, status: let status):
                VStack {
                    Spacer()
                    
                    // Enhanced loading UI with real-time feedback
                    VStack(spacing: 20) {
                        // Animated circular progress
                        ZStack {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(1.2)
                                .tint(.blue)
                            
                            // Percentage in center
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 80, height: 80)
                        
                        // Enhanced status text with emoji support
                        Text(status)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Real-time progress bar
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(.blue)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(4)
                            .frame(width: 200)
                    }
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.8))
                            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 4)
                    )
                    
                    Spacer()
                }
                .background(Color.black.ignoresSafeArea())
            case .initializing(progress: let progress, status: let status):
                VStack {
                    Spacer()
                    
                    // Enhanced initializing UI
                    VStack(spacing: 20) {
                        // Animated circular progress
                        ZStack {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(1.2)
                                .tint(.orange)
                            
                            // Percentage in center
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 80, height: 80)
                        
                        // Enhanced status text
                        Text(status)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        // Progress bar
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(.orange)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(4)
                            .frame(width: 200)
                    }
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.8))
                            .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 4)
                    )
                    
                    Spacer()
                }
                .background(Color.black.ignoresSafeArea())
            case .previewing(_, _, _, _):
                EmptyView() // Let AddMoveContainer handle the PreTrimView
            case .saving:
                VStack {
                    Spacer()
                    ProgressView("Saving your move...")
                        .progressViewStyle(.circular)
                    Spacer()
                }
                .background(Color.black.ignoresSafeArea())
            case .success(let message):
                VStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    Text(message)
                        .font(.headline)
                        .foregroundColor(.white)
                    Button("Done") {
                        // Reset action would go here
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .background(Color.black.ignoresSafeArea())
            case .error(let message, let underlyingError):
                AddMoveErrorView(viewModel: viewModel, message: message, underlyingError: underlyingError as? Error, selectedTab: .constant(.add))
            default:
                EmptyView()
            }
            
            Spacer()
        }
        .navigationBarHidden(true)
    }
}
