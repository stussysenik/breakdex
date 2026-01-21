import SwiftUI

// MARK: - Tag Flow Layout
/// A flow layout that wraps tags horizontally, moving to the next row when full.
/// Uses ViewThatFits on iOS 16+ for optimal performance.

struct TagFlowLayout<Content: View>: View {

    // MARK: - Properties

    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let content: () -> Content

    // MARK: - Initialization

    init(
        horizontalSpacing: CGFloat = 8,
        verticalSpacing: CGFloat = 8,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.content = content
    }

    // MARK: - Body

    var body: some View {
        _VariadicView.Tree(FlowLayoutHelper(
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing
        )) {
            content()
        }
    }
}

// MARK: - Flow Layout Helper

private struct FlowLayoutHelper: _VariadicView_UnaryViewRoot {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    @ViewBuilder
    func body(children: _VariadicView.Children) -> some View {
        GeometryReader { geometry in
            FlowLayoutContent(
                availableWidth: geometry.size.width,
                horizontalSpacing: horizontalSpacing,
                verticalSpacing: verticalSpacing,
                children: children
            )
        }
        .frame(minHeight: 0)
    }
}

// MARK: - Flow Layout Content

private struct FlowLayoutContent: View {
    let availableWidth: CGFloat
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let children: _VariadicView.Children

    @State private var sizes: [CGSize] = []
    @State private var totalHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { _ in
                layoutContent()
            }
        }
        .frame(height: totalHeight)
    }

    @ViewBuilder
    private func layoutContent() -> some View {
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var calculatedHeight: CGFloat = 0

        ZStack(alignment: .topLeading) {
            ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                child
                    .alignmentGuide(.leading) { dimension in
                        let width = dimension.width

                        // Check if we need to wrap
                        if currentX + width > availableWidth && currentX > 0 {
                            currentX = 0
                            currentY += rowHeight + verticalSpacing
                            rowHeight = 0
                        }

                        let result = -currentX
                        currentX += width + horizontalSpacing
                        rowHeight = max(rowHeight, dimension.height)

                        // Track total height
                        calculatedHeight = currentY + rowHeight

                        // Reset for last item
                        if index == children.count - 1 {
                            currentX = 0
                            DispatchQueue.main.async {
                                totalHeight = calculatedHeight
                            }
                        }

                        return result
                    }
                    .alignmentGuide(.top) { dimension in
                        let result = -currentY
                        return result
                    }
            }
        }
    }
}

// MARK: - Simple Flow Layout (Alternative)
/// A simpler flow layout using a custom layout approach

struct SimpleFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            // Check if we need to wrap to next line
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }

        let totalHeight = currentY + rowHeight
        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

// MARK: - Convenience View for Tags

struct TagsFlowView: View {
    let tags: [String]
    var onRemove: ((String) -> Void)?
    var onTap: ((String) -> Void)?

    var body: some View {
        SimpleFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(tags, id: \.self) { tag in
                TagChipView(
                    tag: tag,
                    isRemovable: onRemove != nil,
                    onRemove: { onRemove?(tag) },
                    onTap: { onTap?(tag) }
                )
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TagFlowLayout_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            Text("Flow Layout Demo")
                .font(.ibmPlexMono(size: 20, weight: .bold))

            // Using SimpleFlowLayout
            SimpleFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                TagChipView(tag: "Footwork", onRemove: {})
                TagChipView(tag: "Power Move", onRemove: {})
                TagChipView(tag: "Foundation", onRemove: {})
                TagChipView(tag: "Toprock", onRemove: {})
                TagChipView(tag: "Freeze", onRemove: {})
                TagChipView(tag: "Windmill", onRemove: {})
                TagChipView(tag: "Flare", onRemove: {})
                TagChipView(tag: "Airflare", onRemove: {})
            }
            .padding()
            .background(Color.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Using convenience view
            TagsFlowView(
                tags: ["Breaking", "Bboy", "Tutorial", "Practice"],
                onRemove: { tag in print("Remove: \(tag)") }
            )
            .padding()
            .background(Color.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(Color.backgroundPrimary)
    }
}
#endif
