import SwiftUI

struct LayoutMetrics {
    let screenWidth: CGFloat
    let screenHeight: CGFloat

    private static let phi: CGFloat = 1.618

    // MARK: - Device Breakpoints

    private enum DeviceClass {
        case se          // 375
        case standard    // 390
        case proMax      // 430
        case iPadMini    // 744
        case iPad        // 820
        case iPadPro     // 1024+

        init(width: CGFloat) {
            switch width {
            case ..<383:     self = .se
            case ..<410:     self = .standard
            case ..<600:     self = .proMax
            case ..<780:     self = .iPadMini
            case ..<920:     self = .iPad
            default:         self = .iPadPro
            }
        }

        var isTablet: Bool {
            switch self {
            case .iPadMini, .iPad, .iPadPro: return true
            default: return false
            }
        }
    }

    private var device: DeviceClass { DeviceClass(width: screenWidth) }

    // MARK: - Computed Layout Values

    var isLandscape: Bool { screenWidth > screenHeight }
    var isTablet: Bool { device.isTablet }

    /// Video player height — golden ratio of width in portrait
    var videoPlayerHeight: CGFloat {
        if isLandscape {
            return screenHeight * 0.65
        }
        return screenWidth / Self.phi
    }

    /// Timeline strip height — scales with device
    var timelineHeight: CGFloat {
        switch device {
        case .se:                       return 60
        case .standard, .proMax:        return 68
        case .iPadMini:                 return 72
        case .iPad, .iPadPro:           return 80
        }
    }

    /// Individual thumbnail width — golden ratio of timeline height
    var thumbnailWidth: CGFloat {
        timelineHeight * Self.phi
    }

    /// Horizontal padding
    var horizontalPadding: CGFloat {
        switch device {
        case .se:                       return 16
        case .standard, .proMax:        return 20
        case .iPadMini:                 return 28
        case .iPad:                     return 34
        case .iPadPro:                  return 40
        }
    }

    /// Available width for timeline after padding
    var timelineWidth: CGFloat {
        screenWidth - (horizontalPadding * 2)
    }

    /// Thumbnail size for the generator
    var thumbnailSize: CGSize {
        if device.isTablet {
            return CGSize(width: 130, height: 78)
        }
        return CGSize(width: 100, height: 60)
    }

    /// How many thumbnails to display based on width and duration
    func thumbnailCount(for duration: TimeInterval) -> Int {
        guard duration > 0 else { return 0 }
        let maxByWidth = Int(timelineWidth / (thumbnailWidth * 0.3))
        let maxByDuration: Int
        if duration <= 120 {
            maxByDuration = min(40, max(8, Int(duration / 3)))
        } else if duration <= 600 {
            maxByDuration = min(60, max(20, Int(duration / 10)))
        } else {
            maxByDuration = min(80, max(30, Int(duration / 20)))
        }
        return min(maxByWidth, maxByDuration)
    }

    /// Landscape split proportions
    var landscapeVideoFraction: CGFloat { 0.6 }
    var landscapeControlsFraction: CGFloat { 0.4 }

    // MARK: - Init from GeometryProxy

    init(geometry: GeometryProxy) {
        self.screenWidth = geometry.size.width
        self.screenHeight = geometry.size.height
    }

    init(width: CGFloat, height: CGFloat) {
        self.screenWidth = width
        self.screenHeight = height
    }
}
