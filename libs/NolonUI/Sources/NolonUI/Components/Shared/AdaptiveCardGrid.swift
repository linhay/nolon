import SwiftUI

public struct AdaptiveCardGrid<Content: View>: View {
    let columns: [GridItem]
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    let content: () -> Content

    public init(
        columns: [GridItem],
        alignment: HorizontalAlignment = .leading,
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.columns = columns
        self.alignment = alignment
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        LazyVGrid(columns: columns, alignment: alignment, spacing: spacing) {
            content()
        }
    }
}
