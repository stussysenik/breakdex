import UIKit

final class HapticEngine {
    static let shared = HapticEngine()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    private init() {}

    /// Pre-warm all generators — call on editor appear
    func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        rigidImpact.prepare()
        softImpact.prepare()
        selection.prepare()
        notification.prepare()
    }

    // MARK: - Semantic Feedback

    /// Tick while scrubbing across thumbnails
    func scrubTick() {
        selection.selectionChanged()
        selection.prepare()
    }

    /// Grab a trim handle or playhead
    func handleGrab() {
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }

    /// Handle snaps to boundary (start/end of video)
    func handleSnap() {
        rigidImpact.impactOccurred()
        rigidImpact.prepare()
    }

    /// Trim point confirmed
    func trimPointSet() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    /// Play/pause toggled
    func playbackToggle() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    /// Speed pill changed
    func speedChange() {
        rigidImpact.impactOccurred()
        rigidImpact.prepare()
    }

    /// 90-degree rotation snap
    func rotationSnap() {
        heavyImpact.impactOccurred()
        heavyImpact.prepare()
    }

    /// Export completed successfully
    func exportComplete() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    /// Error feedback
    func error() {
        notification.notificationOccurred(.error)
        notification.prepare()
    }
}
