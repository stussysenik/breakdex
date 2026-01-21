import Foundation
import Combine
import OSLog
import AVFoundation

// MARK: - Thermal Guard
/// Monitors device thermal state and adjusts video quality accordingly.
/// Prevents crashes and throttling during intensive video operations.

@MainActor
final class ThermalGuard: ObservableObject {

    // MARK: - Singleton

    static let shared = ThermalGuard()

    // MARK: - Published Properties

    @Published private(set) var currentState: ProcessInfo.ThermalState = .nominal
    @Published private(set) var qualityLevel: QualityLevel = .full
    @Published private(set) var shouldReduceWork: Bool = false

    // MARK: - Quality Levels

    enum QualityLevel: Int, Comparable {
        case full = 0        // Normal operation
        case reduced = 1     // Slight reduction (fair thermal state)
        case minimal = 2     // Significant reduction (serious thermal state)
        case emergency = 3   // Maximum reduction (critical thermal state)

        static func < (lhs: QualityLevel, rhs: QualityLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var videoPreviewResolution: CGSize {
            switch self {
            case .full:      return CGSize(width: 1920, height: 1080)
            case .reduced:   return CGSize(width: 1280, height: 720)
            case .minimal:   return CGSize(width: 854, height: 480)
            case .emergency: return CGSize(width: 640, height: 360)
            }
        }

        var thumbnailSize: CGSize {
            switch self {
            case .full:      return CGSize(width: 400, height: 400)
            case .reduced:   return CGSize(width: 300, height: 300)
            case .minimal:   return CGSize(width: 200, height: 200)
            case .emergency: return CGSize(width: 150, height: 150)
            }
        }

        var targetFrameRate: Float {
            switch self {
            case .full:      return 60
            case .reduced:   return 30
            case .minimal:   return 24
            case .emergency: return 15
            }
        }

        var maxConcurrentOperations: Int {
            switch self {
            case .full:      return 4
            case .reduced:   return 3
            case .minimal:   return 2
            case .emergency: return 1
            }
        }

        var description: String {
            switch self {
            case .full:      return "Full Quality"
            case .reduced:   return "Reduced Quality"
            case .minimal:   return "Minimal Quality"
            case .emergency: return "Emergency Mode"
            }
        }
    }

    // MARK: - Properties

    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.breakdex", category: "ThermalGuard")

    // Callbacks for components to react to changes
    var onQualityChange: ((QualityLevel) -> Void)?

    // MARK: - Initialization

    private init() {
        currentState = ProcessInfo.processInfo.thermalState
        updateQualityLevel()
        setupObservers()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Monitor thermal state changes
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleThermalStateChange()
            }
            .store(in: &cancellables)

        // Monitor memory warnings
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }

    // MARK: - Thermal State Handling

    private func handleThermalStateChange() {
        let newState = ProcessInfo.processInfo.thermalState
        let previousState = currentState
        currentState = newState

        logger.info("Thermal state changed: \(self.thermalStateName(previousState)) -> \(self.thermalStateName(newState))")

        updateQualityLevel()

        // Provide haptic feedback for significant state changes
        if qualityLevel >= .minimal {
            HapticFeedback.notificationHaptic(.warning)
        }
    }

    private func handleMemoryWarning() {
        logger.warning("Memory warning received, reducing quality")

        // Temporarily reduce quality
        if qualityLevel < .minimal {
            qualityLevel = .minimal
            shouldReduceWork = true
            onQualityChange?(qualityLevel)
        }

        // Clear caches
        ThumbnailGenerator.shared.clearCache()
    }

    private func updateQualityLevel() {
        let newQuality: QualityLevel

        switch currentState {
        case .nominal:
            newQuality = .full
            shouldReduceWork = false
        case .fair:
            newQuality = .reduced
            shouldReduceWork = false
        case .serious:
            newQuality = .minimal
            shouldReduceWork = true
        case .critical:
            newQuality = .emergency
            shouldReduceWork = true
        @unknown default:
            newQuality = .reduced
            shouldReduceWork = false
        }

        if newQuality != qualityLevel {
            qualityLevel = newQuality
            logger.info("Quality level changed to: \(newQuality.description)")
            onQualityChange?(newQuality)
        }
    }

    // MARK: - Public Methods

    /// Check if intensive operations should proceed
    func shouldAllowIntensiveOperation() -> Bool {
        switch currentState {
        case .nominal, .fair:
            return true
        case .serious, .critical:
            return false
        @unknown default:
            return true
        }
    }

    /// Get recommended video export settings based on thermal state
    func recommendedExportPreset() -> String {
        switch qualityLevel {
        case .full:
            return AVAssetExportPresetHighestQuality
        case .reduced:
            return AVAssetExportPreset1920x1080
        case .minimal:
            return AVAssetExportPreset1280x720
        case .emergency:
            return AVAssetExportPreset960x540
        }
    }

    /// Execute work with thermal consideration
    func executeWithThermalGuard<T>(_ work: () async throws -> T) async throws -> T {
        if qualityLevel >= .minimal {
            // Add a small delay to reduce thermal stress
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        return try await work()
    }

    /// Request temporary quality reduction for intensive operations
    func requestTemporaryReduction(duration: TimeInterval = 5.0) {
        guard qualityLevel < .reduced else { return }

        let previousLevel = qualityLevel
        qualityLevel = .reduced
        onQualityChange?(qualityLevel)

        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            // Restore if thermal state allows
            await MainActor.run {
                if self.currentState == .nominal {
                    self.qualityLevel = previousLevel
                    self.onQualityChange?(self.qualityLevel)
                }
            }
        }
    }

    // MARK: - Helpers

    private func thermalStateName(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:  return "Nominal"
        case .fair:     return "Fair"
        case .serious:  return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Thermal Aware Video Player Extension

extension SharedVideoPlayer {

    /// Apply thermal-aware settings to the player
    func applyThermalSettings() {
        let quality = ThermalGuard.shared.qualityLevel

        // Adjust playback rate if needed
        if quality >= .minimal {
            // Could reduce quality here if needed
        }
    }
}

// MARK: - Thermal Status View
/// A debug view showing current thermal state

struct ThermalStatusView: View {
    @ObservedObject private var thermalGuard = ThermalGuard.shared

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(thermalGuard.qualityLevel.description)
                .font(.ibmPlexMono(size: 10))
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.backgroundSecondary)
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch thermalGuard.qualityLevel {
        case .full:      return .green
        case .reduced:   return .yellow
        case .minimal:   return .orange
        case .emergency: return .red
        }
    }
}

// MARK: - Thermal Warning Banner
/// Shows a warning when thermal state is elevated

struct ThermalWarningBanner: View {
    @ObservedObject private var thermalGuard = ThermalGuard.shared

    var body: some View {
        if thermalGuard.qualityLevel >= .minimal {
            HStack(spacing: 8) {
                Image(systemName: "thermometer.high")
                    .foregroundColor(.orange)

                Text("Device is warm - quality reduced")
                    .font(.ibmPlexMono(size: 12))
                    .foregroundColor(.textSecondary)

                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.orange.opacity(0.1))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

import SwiftUI
