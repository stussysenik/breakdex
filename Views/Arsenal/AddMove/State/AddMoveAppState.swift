import SwiftUI
import AVKit
import PhotosUI

// MARK: - Add Move App State
// iOS 18 Modern Observable Pattern
@Observable
@MainActor
class AddMoveAppState {
    
    // MARK: - Flow State
    var currentStep: AddMoveFlowStep = .selectVideo
    var flowProgress: Double = 0.0
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    
    // MARK: - Video State
    var selectedVideoItem: PhotosPickerItem?
    var videoAsset: AVAsset?
    var photosIdentifier: String?
    var selectedFilename: String?
    
    // MARK: - Player State
    var currentPlayerViewModel: (any VideoPlayerViewModelProtocol)?
    var isVideoLoading: Bool = false
    var videoLoadingProgress: Double = 0.0
    
    // MARK: - Trimming State
    var isTrimming: Bool = false
    var trimStartTime: Double?
    var trimEndTime: Double?
    var rotationQuarterTurns: Int = 0
    
    // MARK: - User Input State
    var moveName: String = ""
    var isSaving: Bool = false
    var saveProgress: Double = 0.0
    
    // MARK: - Error State
    var errorMessage: String?
    var underlyingError: String?
    
    // MARK: - Import State
    var importState: SelectionState = .idle
    
    // MARK: - Computed Properties
    
    var isInError: Bool {
        return errorMessage != nil
    }
    
    var isReady: Bool {
        return currentStep == .selectVideo && !isInError
    }
    
    var hasVideo: Bool {
        return videoAsset != nil
    }
    
    var canProceed: Bool {
        switch currentStep {
        case .selectVideo:
            return hasVideo
        case .previewVideo:
            return true
        case .trimVideo:
            return true
        case .nameMove:
            return !moveName.isEmpty
        case .complete:
            return false
        }
    }
    
    // MARK: - State Updates
    
    func reset() {
        currentStep = .selectVideo
        flowProgress = 0.0
        canGoBack = false
        canGoForward = false
        
        selectedVideoItem = nil
        videoAsset = nil
        photosIdentifier = nil
        selectedFilename = nil
        
        currentPlayerViewModel = nil
        isVideoLoading = false
        videoLoadingProgress = 0.0
        
        isTrimming = false
        trimStartTime = nil
        trimEndTime = nil
        rotationQuarterTurns = 0
        
        moveName = ""
        isSaving = false
        saveProgress = 0.0
        
        errorMessage = nil
        underlyingError = nil
        
        importState = .idle
        
        updateFlowProgress()
    }
    
    func updateFlowProgress() {
        switch currentStep {
        case .selectVideo:
            flowProgress = 0.0
            canGoBack = false
            canGoForward = hasVideo
        case .previewVideo:
            flowProgress = 0.33
            canGoBack = true
            canGoForward = true
        case .trimVideo:
            flowProgress = 0.66
            canGoBack = true
            canGoForward = true
        case .nameMove:
            flowProgress = 0.9
            canGoBack = true
            canGoForward = false
        case .complete:
            flowProgress = 1.0
            canGoBack = false
            canGoForward = false
        }
    }
    
    func setError(message: String, underlying: String? = nil) {
        errorMessage = message
        underlyingError = underlying
    }
    
    func clearError() {
        errorMessage = nil
        underlyingError = nil
    }
}