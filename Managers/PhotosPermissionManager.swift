import Photos
import SwiftUI
import Combine

/// Manages Photos permission requests and status monitoring for BreakDex
@MainActor
class PhotosPermissionManager: ObservableObject {
    static let shared = PhotosPermissionManager()
    
    enum PermissionStatus {
        case notDetermined
        case restricted
        case denied
        case authorized
        case limited
        
        var canAccessPhotos: Bool {
            switch self {
            case .authorized, .limited:
                return true
            case .notDetermined, .restricted, .denied:
                return false
            }
        }
        
        var description: String {
            switch self {
            case .notDetermined:
                return "Photos access has not been requested yet."
            case .restricted:
                return "Photos access is restricted, possibly due to parental controls."
            case .denied:
                return "Photos access has been denied. Please enable it in Settings."
            case .authorized:
                return "Full access to Photos library granted."
            case .limited:
                return "Limited access to Photos library. You can select specific photos."
            }
        }
    }
    
    @Published private(set) var status: PermissionStatus = .notDetermined
    @Published private(set) var isRequestingPermission = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Check initial permission status
        checkPermissionStatus()
        
        // Listen for app becoming active to recheck permissions
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkPermissionStatus()
            }
            .store(in: &cancellables)
    }
    
    /// Check current Photos permission status
    func checkPermissionStatus() {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        status = mapPHAuthorizationStatus(currentStatus)
    }
    
    /// Request Photos permission if not already granted
    /// - Returns: PermissionStatus after request completes
    func requestPermission() async -> PermissionStatus {
        await MainActor.run { isRequestingPermission = true }
        defer { Task { await MainActor.run { isRequestingPermission = false } } }
        
        let currentStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        
        let mappedStatus = mapPHAuthorizationStatus(currentStatus)
        await MainActor.run { status = mappedStatus }
        
        return mappedStatus
    }
    
    /// Request permission with completion handler (for legacy compatibility)
    func requestPermission(completion: @escaping (PermissionStatus) -> Void) {
        Task {
            let result = await requestPermission()
            completion(result)
        }
    }
    
    /// Ensure permission is granted, showing appropriate UI if needed
    /// - Returns: true if permission is granted, false otherwise
    func ensurePermission() async -> Bool {
        checkPermissionStatus()
        
        if status.canAccessPhotos {
            return true
        }
        
        // Request permission if not determined
        if case .notDetermined = status {
            let newStatus = await requestPermission()
            return newStatus.canAccessPhotos
        }
        
        return false
    }
    
    /// Open Settings app to allow user to change permission
    func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
    
    // MARK: - Private Helpers
    
    private func mapPHAuthorizationStatus(_ status: PHAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        @unknown default:
            return .denied
        }
    }
}

// MARK: - SwiftUI Convenience Extensions

extension View {
    /// Request Photos permission when view appears if not already granted
    func requestPhotosPermissionIfNeeded() -> some View {
        self.onAppear {
            Task {
                await PhotosPermissionManager.shared.ensurePermission()
            }
        }
    }
}

// MARK: - Error Types

enum PhotosPermissionError: LocalizedError {
    case accessDenied
    case accessRestricted
    case notDetermined
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Photos access denied. Please enable access in Settings to use BreakDex features."
        case .accessRestricted:
            return "Photos access is restricted, possibly due to parental controls."
        case .notDetermined:
            return "Photos permission has not been requested."
        }
    }
}
