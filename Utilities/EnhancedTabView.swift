import SwiftUI

// MARK: - Enhanced TabView
// Custom TabView with MotionCatalog animations and accessibility support

struct EnhancedTabView<SelectionValue: Hashable, Content: View>: View {
    @Binding var selection: SelectionValue
    @ViewBuilder let content: Content

    @State private var previousSelection: SelectionValue?

    var body: some View {
        TabView(selection: $selection) {
            content
        }
        .tabViewStyle(.automatic)
        .onChange(of: selection) { oldValue, newValue in
            // Store previous selection for potential animation logic
            previousSelection = oldValue
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Enhanced Tab Item
// Wrapper for tab items with consistent styling and animations

struct EnhancedTabItem<Tag: Hashable, Label: View>: View {
    let label: Label
    let tag: Tag

    init(tag: Tag, @ViewBuilder label: () -> Label) {
        self.tag = tag
        self.label = label()
    }

    var body: some View {
        label
    }
}

// MARK: - Convenience Extensions
extension EnhancedTabView where SelectionValue == TabSelection {
    init(selection: Binding<TabSelection>, @ViewBuilder content: () -> Content) {
        self._selection = selection
        self.content = content()
    }
}

// MARK: - Tab Transition Helpers
extension View {
    /// Apply tab transition animation (no animation)
    func tabTransition<V: Equatable>(value: V) -> some View {
        self
    }

    /// Apply navigation transition (no animation)
    func navigationTransition<V: Equatable>(value: V) -> some View {
        self
    }
}
