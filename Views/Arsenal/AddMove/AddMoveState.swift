import Foundation
import AVFoundation
import AVKit

// state machine for the add move view - all the logic + states
public enum AddMoveState: Equatable, Hashable {
    case ready
    case initializing(progress: Double, status: String)
    case loading(progress: Double, status: String)
    case loaded(asset: AVAsset, photosIdentifier: String?, rotationQuarterTurns: Int) // NEW: Intermediate state
    case previewing(playerViewModel: any VideoPlayerViewModelProtocol, asset: AVAsset, photosIdentifier: String?, rotationQuarterTurns: Int)
    case selectingVideo(currentAsset: AVAsset?) // NEW: For video selection mode
    case trimming(asset: AVAsset, photosIdentifier: String?, rotationQuarterTurns: Int)
    case naming(photosIdentifier: String, originalAsset: AVAsset?, trimmedAsset: AVAsset?, trimStartTime: Double?, trimEndTime: Double?, rotationQuarterTurns: Int)
    case saving
    case success(message: String)
    case error(message: String, underlyingError: String?)

    public static func == (lhs: AddMoveState, rhs: AddMoveState) -> Bool {
        switch (lhs, rhs) {
        case (.ready, .ready), (.saving, .saving):
            return true
        case (.success(let m1), .success(let m2)):
            return m1 == m2
        case (.error(let m1, let e1), .error(let m2, let e2)):
            return m1 == m2 && e1 == e2
        case (let .initializing(p1, s1), let .initializing(p2, s2)):
            return p1 == p2 && s1 == s2
        case (let .loading(p1, s1), let .loading(p2, s2)):
            return p1 == p2 && s1 == s2
        case (let .loaded(a1, id1, rot1), let .loaded(a2, id2, rot2)):
            return a1 == a2 && id1 == id2 && rot1 == rot2
        case (let .previewing(vm1, a1, id1, rot1), let .previewing(vm2, a2, id2, rot2)):
            return vm1.hashValue == vm2.hashValue && a1 == a2 && id1 == id2 && rot1 == rot2
        case (let .selectingVideo(asset1), let .selectingVideo(asset2)):
            return asset1 == asset2
        case (let .trimming(a1, id1, rot1), let .trimming(a2, id2, rot2)):
            return a1 == a2 && id1 == id2 && rot1 == rot2
        case (let .naming(id1, _, _, start1, end1, rot1), let .naming(id2, _, _, start2, end2, rot2)):
            return id1 == id2 && start1 == start2 && end1 == end2 && rot1 == rot2
        default:
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .ready:
            hasher.combine(0)
        case .initializing(let progress, let status):
            hasher.combine(1)
            hasher.combine(progress)
            hasher.combine(status)
        case .loading(let progress, let status):
            hasher.combine(2)
            hasher.combine(progress)
            hasher.combine(status)
        case .loaded(let asset, let photosIdentifier, let rotationQuarterTurns):
            hasher.combine(3)
            hasher.combine(ObjectIdentifier(asset))
            hasher.combine(photosIdentifier)
            hasher.combine(rotationQuarterTurns)
        case .previewing(let playerViewModel, let asset, let photosIdentifier, let rotationQuarterTurns):
            hasher.combine(4)
            hasher.combine(playerViewModel.hashValue)
            hasher.combine(ObjectIdentifier(asset))
            hasher.combine(photosIdentifier)
            hasher.combine(rotationQuarterTurns)
        case .selectingVideo(let asset):
            hasher.combine(5)
            if let asset = asset {
                hasher.combine(ObjectIdentifier(asset))
            }
        case .trimming(let asset, let photosIdentifier, let rotationQuarterTurns):
            hasher.combine(6)
            hasher.combine(ObjectIdentifier(asset))
            hasher.combine(photosIdentifier)
            hasher.combine(rotationQuarterTurns)
        case .naming(let photosIdentifier, let originalAsset, let trimmedAsset, let trimStartTime, let trimEndTime, let rotationQuarterTurns):
            hasher.combine(7)
            hasher.combine(photosIdentifier)
            if let originalAsset = originalAsset {
                hasher.combine(ObjectIdentifier(originalAsset))
            }
            if let trimmedAsset = trimmedAsset {
                hasher.combine(ObjectIdentifier(trimmedAsset))
            }
            hasher.combine(trimStartTime)
            hasher.combine(trimEndTime)
            hasher.combine(rotationQuarterTurns)
        case .saving:
            hasher.combine(8)
        case .success(let message):
            hasher.combine(9)
            hasher.combine(message)
        case .error(let message, let underlyingError):
            hasher.combine(10)
            hasher.combine(message)
            hasher.combine(underlyingError)
        }
    }
}

public enum AddMoveError: LocalizedError {
    case photosPermissionDenied
    case iCloudUnavailable
    case videoLoadFailed(underlyingError: Error?)
    case videoFormatUnsupported
    case videoCopyFailed(underlyingError: Error?)
    case coreDataSaveFailed(underlyingError: Error?)
    case invalidMoveName
    case unknown(underlyingError: Error?)
    
    public var errorDescription: String? {
        switch self {
        case .photosPermissionDenied:
            return "Photos access denied. Please enable Photos access in Settings."
        case .iCloudUnavailable:
            return "iCloud is unavailable. Please check your iCloud settings."
        case .videoLoadFailed(let error):
            return "Failed to load video. " + (error?.localizedDescription ?? "")
        case .videoFormatUnsupported:
            return "Unsupported video format. Please choose an MP4 or MOV file."
        case .videoCopyFailed(let error):
            return "Failed to copy video to BreakDex. " + (error?.localizedDescription ?? "")
        case .coreDataSaveFailed(let error):
            return "Failed to save your move. " + (error?.localizedDescription ?? "")
        case .invalidMoveName:
            return "Please enter a name for your move."
        case .unknown(let error):
            return "An unexpected error occurred. " + (error?.localizedDescription ?? "")
        }
    }
}
