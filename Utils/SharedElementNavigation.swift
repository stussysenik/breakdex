import SwiftUI

// MARK: - Shared Element Navigation
// Implements smooth shared element transitions between list and detail views
// Follows PRD specifications: 220ms ease-in-out with Reduce Motion fallback

struct SharedElementContainer<Content: View>: View {
    @Namespace private var namespace
    @ViewBuilder let content: (Namespace.ID) -> Content

    var body: some View {
        content(namespace)
    }
}

// MARK: - Shared Element List Item
// Enhanced list item with shared element animation support

struct SharedElementListItem<Content: View>: View {
    let content: Content
    let sharedID: String
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        content
            .matchedGeometryEffect(id: sharedID, in: namespace)
            .onTapGesture {
                withAnimation(MotionCatalog.Accessibility.accessibleAnimation(MotionCatalog.Navigation.push)) {
                    action()
                }
            }
    }
}

// MARK: - Shared Element Detail View
// Detail view that receives shared elements from list

struct SharedElementDetailView<Content: View>: View {
    let content: Content
    let sharedID: String
    let namespace: Namespace.ID

    var body: some View {
        content
            .matchedGeometryEffect(id: sharedID, in: namespace)
    }
}

// MARK: - Navigation Stack with Shared Elements
// Enhanced NavigationStack with shared element support

struct SharedElementNavigationStack<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        SharedElementContainer { namespace in
            NavigationStack {
                content()
                    .environment(\.sharedNamespace, namespace)
            }
            .animation(MotionCatalog.Accessibility.accessibleAnimation(MotionCatalog.Navigation.push), value: UUID())
        }
    }
}

// MARK: - Environment Key for Shared Namespace
private struct SharedNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var sharedNamespace: Namespace.ID? {
        get { self[SharedNamespaceKey.self] }
        set { self[SharedNamespaceKey.self] = newValue }
    }
}

// MARK: - View Extensions for Shared Elements
extension View {
    /// Add shared element effect to a view
    func sharedElement(id: String, namespace: Namespace.ID) -> some View {
        self.matchedGeometryEffect(id: id, in: namespace)
    }

    /// Add shared element effect using environment namespace
    func sharedElement(id: String) -> some View {
        Group {
            if let namespace = EnvironmentValues().sharedNamespace {
                self.matchedGeometryEffect(id: id, in: namespace)
            } else {
                self
            }
        }
    }

    /// Apply smooth navigation animation
    func navigationAnimation() -> some View {
        self.animation(MotionCatalog.Accessibility.accessibleAnimation(MotionCatalog.Navigation.push), value: UUID())
    }
}

// MARK: - Convenience Functions
extension MotionCatalog.Navigation {
    /// Shared element transition animation
    static let sharedElement = Animation.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)
}
