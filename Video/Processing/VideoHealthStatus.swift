import Foundation

// MARK: - Video Health Status
public enum VideoHealthStatus: String, CaseIterable {
    case unknown = "unknown"
    case critical = "critical"
    case poor = "poor"
    case good = "good"
    case excellent = "excellent"
    
    var description: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .critical:
            return "Critical"
        case .poor:
            return "Poor"
        case .good:
            return "Good"
        case .excellent:
            return "Excellent"
        }
    }
    
    // Convert from VideoHealthState to VideoHealthStatus
    static func from(_ healthState: VideoHealthState) -> VideoHealthStatus {
        switch healthState {
        case .healthy:
            return .excellent
        case .warning:
            return .poor
        case .critical:
            return .critical
        }
    }
}