import SwiftUI

// MARK: - Feedback Toast Component
/// CW&T-inspired: "Legibility" — user always knows what's happening
/// Minimal toast for CRUD feedback with success/error states

struct FeedbackToast: View {
    
    // MARK: - Types
    enum Style {
        case success
        case error
        case info
        
        var icon: String {
            switch self {
            case .success: return "checkmark"
            case .error: return "xmark"
            case .info: return "info"
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .success: return Color.black.opacity(0.9)
            case .error: return Color.red.opacity(0.9)
            case .info: return Color.gray.opacity(0.9)
            }
        }
    }
    
    // MARK: - Properties
    let message: String
    let style: Style
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: style.icon)
                .font(.ibmPlexMono(size: 14, weight: .bold))
            
            // Message
            Text(message)
                .font(.ibmPlexMono(size: 14))
                .lineLimit(2)
            
            Spacer()
            
            // Optional action button
            if let action, let actionLabel {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.ibmPlexMono(size: 12, weight: .bold))
                        .foregroundColor(.accent)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(style.backgroundColor)
        .foregroundColor(.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.2), radius: 4, y: 2)
    }
}

// MARK: - Toast Manager
/// Manages toast display with auto-dismiss
@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var currentToast: ToastItem?
    
    struct ToastItem: Identifiable {
        let id = UUID()
        let message: String
        let style: FeedbackToast.Style
        let action: (() -> Void)?
        let actionLabel: String?
    }
    
    private var dismissTask: Task<Void, Never>?
    
    /// Show a toast with auto-dismiss
    func show(_ message: String, style: FeedbackToast.Style, duration: TimeInterval = 3.0, action: (() -> Void)? = nil, actionLabel: String? = nil) {
        // Cancel any existing dismiss task
        dismissTask?.cancel()
        
        // Show new toast
        withAnimation(.easeInOut(duration: 0.2)) {
            currentToast = ToastItem(message: message, style: style, action: action, actionLabel: actionLabel)
        }
        
        // Auto-dismiss
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.currentToast = nil
                    }
                }
            }
        }
    }
    
    /// Dismiss current toast
    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            currentToast = nil
        }
    }
    
    // MARK: - Convenience Methods
    
    func showSuccess(_ message: String) {
        show(message, style: .success)
    }
    
    func showError(_ message: String, retry: (() -> Void)? = nil) {
        show(message, style: .error, duration: 5.0, action: retry, actionLabel: retry != nil ? "Retry" : nil)
    }
    
    func showInfo(_ message: String) {
        show(message, style: .info)
    }
}

// MARK: - Toast Container View
/// Overlay container for displaying toasts
struct ToastContainer: ViewModifier {
    @ObservedObject var manager = ToastManager.shared
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            VStack {
                Spacer()
                
                if let toast = manager.currentToast {
                    FeedbackToast(
                        message: toast.message,
                        style: toast.style,
                        action: toast.action,
                        actionLabel: toast.actionLabel
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100) // Above tab bar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
}

extension View {
    /// Add toast overlay to any view
    func withToastOverlay() -> some View {
        modifier(ToastContainer())
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        FeedbackToast(message: "Windmill saved", style: .success)
        FeedbackToast(message: "Failed: No video access", style: .error, action: {}, actionLabel: "Retry")
        FeedbackToast(message: "Loading video...", style: .info)
    }
    .padding()
}
