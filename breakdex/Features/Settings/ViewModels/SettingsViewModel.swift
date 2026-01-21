//
//  SettingsViewModel.swift
//  BreakingFlashcards
//
//  Created by Claude on 01/20/26.
//

import Foundation
import OSLog
import SwiftUI

// MARK: - Settings ViewModel
/// Manages app settings and preferences.
@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var largeTouchTargets: Bool {
        didSet {
            UserDefaults.standard.set(largeTouchTargets, forKey: Keys.largeTouchTargets)
            logger.info("Large touch targets: \(self.largeTouchTargets)")
        }
    }

    @Published var highContrastMode: Bool {
        didSet {
            UserDefaults.standard.set(highContrastMode, forKey: Keys.highContrastMode)
            logger.info("High contrast mode: \(self.highContrastMode)")
        }
    }

    @Published var reduceMotion: Bool {
        didSet {
            UserDefaults.standard.set(reduceMotion, forKey: Keys.reduceMotion)
            logger.info("Reduce motion: \(self.reduceMotion)")
        }
    }

    @Published var cacheSize: String = "Calculating..."
    @Published var isClearing: Bool = false
    @Published var showClearConfirmation: Bool = false

    // MARK: - Computed Properties

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.breakingflashcards", category: "SettingsViewModel")

    // MARK: - Constants

    private enum Keys {
        static let largeTouchTargets = "settings.largeTouchTargets"
        static let highContrastMode = "settings.highContrastMode"
        static let reduceMotion = "settings.reduceMotion"
    }

    // MARK: - Initialization

    init() {
        self.largeTouchTargets = UserDefaults.standard.bool(forKey: Keys.largeTouchTargets)
        self.highContrastMode = UserDefaults.standard.bool(forKey: Keys.highContrastMode)
        self.reduceMotion = UserDefaults.standard.bool(forKey: Keys.reduceMotion)

        calculateCacheSize()
    }

    // MARK: - Cache Management

    func calculateCacheSize() {
        Task {
            let size = await getCacheSizeInBytes()
            await MainActor.run {
                cacheSize = formatBytes(size)
            }
        }
    }

    private func getCacheSizeInBytes() async -> Int64 {
        var totalSize: Int64 = 0

        // Calculate temporary directory size
        let tempDir = FileManager.default.temporaryDirectory
        totalSize += directorySize(at: tempDir)

        // Calculate caches directory size
        if let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            totalSize += directorySize(at: cachesDir)
        }

        return totalSize
    }

    private func directorySize(at url: URL) -> Int64 {
        var size: Int64 = 0
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                size += Int64(resourceValues.fileSize ?? 0)
            } catch {
                // Skip files we can't read
            }
        }

        return size
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func clearCache() {
        isClearing = true
        logger.info("Clearing cache...")

        Task {
            let fileManager = FileManager.default

            // Clear temporary directory
            let tempDir = fileManager.temporaryDirectory
            clearDirectory(at: tempDir)

            // Clear specific cache subdirectories (not all caches)
            if let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
                let videoCacheDir = cachesDir.appendingPathComponent("VideoCache")
                clearDirectory(at: videoCacheDir)

                let thumbnailCacheDir = cachesDir.appendingPathComponent("Thumbnails")
                clearDirectory(at: thumbnailCacheDir)
            }

            await MainActor.run {
                isClearing = false
                calculateCacheSize()
                HapticFeedback.notificationHaptic(.success)
                logger.info("Cache cleared successfully")
            }
        }
    }

    private func clearDirectory(at url: URL) {
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: nil) else {
            return
        }

        for case let fileURL as URL in enumerator {
            try? fileManager.removeItem(at: fileURL)
        }
    }

    // MARK: - Reset

    func resetToDefaults() {
        largeTouchTargets = false
        highContrastMode = false
        reduceMotion = false
        logger.info("Settings reset to defaults")
        HapticFeedback.actionHaptic()
    }
}
