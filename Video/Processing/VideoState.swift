import Foundation

// MARK: - Video State
enum VideoState: String, CaseIterable, Equatable, Hashable {
    case idle = "idle"
    case loading = "loading"
    case loaded = "loaded"
    case processing = "processing"
    case ready = "ready"
    case playing = "playing"
    case paused = "paused"
    case error = "error"
    
    var canTransitionTo: [VideoState] {
        switch self {
        case .idle:
            return [.loading]
        case .loading:
            return [.loaded, .error]
        case .loaded:
            return [.processing, .ready]
        case .processing:
            return [.ready, .error]
        case .ready:
            return [.playing, .paused, .error]
        case .playing:
            return [.paused, .ready, .error]
        case .paused:
            return [.playing, .ready, .error]
        case .error:
            return [.idle, .loading]
        }
    }
    
    func canTransition(to state: VideoState) -> Bool {
        return canTransitionTo.contains(state)
    }
}