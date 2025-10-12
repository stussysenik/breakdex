import SwiftUI

// MARK: - Shared Loading View
/// Clean, reusable loading view for consistent loading experience across features
public struct SharedLoadingView: View {
    // MARK: - Properties
    private let configuration: LoadingConfiguration

    // MARK: - Loading Configuration
    public struct LoadingConfiguration {
        let style: LoadingStyle
        let message: String?
        let progress: Double?
        let showPercentage: Bool
        let backgroundColor: Color
        let foregroundColor: Color
        let size: LoadingSize

        public enum LoadingStyle {
            case circular        // Spinning circle
            case linear          // Horizontal progress bar
            case dots            // Animated dots
            case pulse           // Pulsing indicator
        }

        public enum LoadingSize {
            case small
            case medium
            case large
            case custom(width: CGFloat, height: CGFloat)

            var dimensions: (width: CGFloat, height: CGFloat) {
                switch self {
                case .small: return (20, 20)
                case .medium: return (40, 40)
                case .large: return (60, 60)
                case .custom(let width, let height): return (width, height)
                }
            }
        }

        public init(
            style: LoadingStyle = .circular,
            message: String? = nil,
            progress: Double? = nil,
            showPercentage: Bool = false,
            backgroundColor: Color = .clear,
            foregroundColor: Color = .blue,
            size: LoadingSize = .medium
        ) {
            self.style = style
            self.message = message
            self.progress = progress
            self.showPercentage = showPercentage
            self.backgroundColor = backgroundColor
            self.foregroundColor = foregroundColor
            self.size = size
        }

        // Preset configurations
        public static let videoProcessing = LoadingConfiguration(
            style: .circular,
            message: "Processing video...",
            showPercentage: true,
            size: .large
        )

        public static let videoLoading = LoadingConfiguration(
            style: .circular,
            message: "Loading video...",
            size: .medium
        )

        public static let saving = LoadingConfiguration(
            style: .linear,
            message: "Saving...",
            showPercentage: true,
            size: .medium
        )

        public static let minimal = LoadingConfiguration(
            style: .circular,
            size: .small
        )

        // Default configuration for general use
        public static let `default` = LoadingConfiguration(
            style: .circular,
            size: .medium
        )
    }

    // MARK: - Initialization
    public init(configuration: LoadingConfiguration = .default) {
        self.configuration = configuration
    }

    // Convenience initializers
    public init(message: String) {
        self.configuration = LoadingConfiguration(message: message)
    }

    public init(progress: Double) {
        self.configuration = LoadingConfiguration(
            style: .linear,
            progress: progress,
            showPercentage: true
        )
    }

    // MARK: - Body
    public var body: some View {
        VStack(spacing: 16) {
            // Loading indicator
            loadingIndicator

            // Message
            if let message = configuration.message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }

            // Progress percentage
            if let progress = configuration.progress, configuration.showPercentage {
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(configuration.backgroundColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loading Indicators

    @ViewBuilder
    private var loadingIndicator: some View {
        switch configuration.style {
        case .circular:
            circularIndicator
        case .linear:
            linearIndicator
        case .dots:
            dotsIndicator
        case .pulse:
            pulseIndicator
        }
    }

    private var circularIndicator: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: configuration.foregroundColor))
            .scaleEffect(scaleForSize)
    }

    private var linearIndicator: some View {
        VStack(spacing: 8) {
            if let progress = configuration.progress {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: configuration.foregroundColor))
                    .frame(height: heightForSize)
            } else {
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle(tint: configuration.foregroundColor))
                    .frame(height: heightForSize)
            }
        }
    }

    private var dotsIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(configuration.foregroundColor)
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(animationScale(for: index))
                    .animation(
                        .easeInOut(duration: 0.6)
                        .delay(Double(index) * 0.2)
                        .repeatForever(autoreverses: true),
                        value: UUID()
                    )
            }
        }
    }

    private var pulseIndicator: some View {
        Circle()
            .fill(configuration.foregroundColor.opacity(0.6))
            .frame(width: size.dimensions.width, height: size.dimensions.height)
            .scaleEffect(pulseScale)
            .animation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true),
                value: UUID()
            )
    }

    // MARK: - Helper Properties

    private var size: LoadingConfiguration.LoadingSize {
        return configuration.size
    }

    private var scaleForSize: CGFloat {
        switch size {
        case .small: return 0.8
        case .medium: return 1.0
        case .large: return 1.5
        case .custom: return 1.0
        }
    }

    private var heightForSize: CGFloat {
        switch size {
        case .small: return 4
        case .medium: return 6
        case .large: return 8
        case .custom: return 6
        }
    }

    private var dotSize: CGFloat {
        switch size {
        case .small: return 6
        case .medium: return 8
        case .large: return 12
        case .custom: return 8
        }
    }

    private func animationScale(for index: Int) -> CGFloat {
        let baseScale: CGFloat = 1.0
        let animationScale: CGFloat = 0.3
        return baseScale + animationScale * sin(Date().timeIntervalSince1970 + Double(index) * 0.5)
    }

    private var pulseScale: CGFloat {
        let baseScale: CGFloat = 1.0
        let pulseAmount: CGFloat = 0.3
        return baseScale + pulseAmount * sin(Date().timeIntervalSince1970)
    }
}

// MARK: - Loading View Variants
public extension SharedLoadingView {
    /// Video processing loading view with progress
    static func videoProcessing(progress: Double, message: String = "Processing video...") -> SharedLoadingView {
        return SharedLoadingView(
            configuration: LoadingConfiguration(
                style: .circular,
                message: message,
                progress: progress,
                showPercentage: true,
                size: .large
            )
        )
    }

    /// Video loading view without progress
    static func videoLoading(message: String = "Loading video...") -> SharedLoadingView {
        return SharedLoadingView(
            configuration: LoadingConfiguration.videoLoading
        )
    }

    /// Saving progress view
    static func saving(progress: Double, message: String = "Saving...") -> SharedLoadingView {
        return SharedLoadingView(
            configuration: LoadingConfiguration(
                style: .linear,
                message: message,
                progress: progress,
                showPercentage: true,
                size: .medium
            )
        )
    }

    /// Minimal loading indicator
    static func minimal() -> SharedLoadingView {
        return SharedLoadingView(
            configuration: LoadingConfiguration.minimal
        )
    }

    /// Custom loading with message
    static func withMessage(_ message: String, style: LoadingConfiguration.LoadingStyle = .circular) -> SharedLoadingView {
        return SharedLoadingView(
            configuration: LoadingConfiguration(
                style: style,
                message: message
            )
        )
    }
}

// MARK: - Loading View Modifier
public extension View {
    /// Overlay loading view on top of existing content
    func loadingOverlay(isLoading: Bool, configuration: SharedLoadingView.LoadingConfiguration = .default) -> some View {
        self.overlay(
            Group {
                if isLoading {
                    SharedLoadingView(configuration: configuration)
                        .background(Color.black.opacity(0.3))
                }
            }
        )
    }

    /// Replace content with loading view when loading
    func loadingContent(isLoading: Bool, configuration: SharedLoadingView.LoadingConfiguration = .default) -> some View {
        Group {
            if isLoading {
                SharedLoadingView(configuration: configuration)
            } else {
                self
            }
        }
    }
}

// MARK: - Preview
#Preview("Loading Styles") {
    VStack(spacing: 40) {
        // Circular with message
        SharedLoadingView(
            configuration: SharedLoadingView.LoadingConfiguration(
                style: .circular,
                message: "Loading video...",
                size: .large
            )
        )

        // Linear with progress
        SharedLoadingView(
            configuration: SharedLoadingView.LoadingConfiguration(
                style: .linear,
                message: "Processing video...",
                progress: 0.65,
                showPercentage: true
            )
        )

        // Dots animation
        SharedLoadingView(
            configuration: SharedLoadingView.LoadingConfiguration(
                style: .dots,
                message: "Loading...",
                size: .medium
            )
        )

        // Pulse animation
        SharedLoadingView(
            configuration: SharedLoadingView.LoadingConfiguration(
                style: .pulse,
                message: "Preparing...",
                size: .large
            )
        )
    }
    .padding()
}

#Preview("Convenience Initializers") {
    VStack(spacing: 20) {
        SharedLoadingView.videoProcessing(progress: 0.75)
        SharedLoadingView.videoLoading()
        SharedLoadingView.saving(progress: 0.45)
        SharedLoadingView.minimal()
        SharedLoadingView.withMessage("Custom message", style: .dots)
    }
    .padding()
}