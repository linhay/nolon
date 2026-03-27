import SwiftUI

public struct PaddedScrollContainer<Content: View>: View {
    let showsIndicators: Bool
    let padding: EdgeInsets
    let maxContentWidth: CGFloat?
    let contentAlignment: Alignment
    let minHeight: CGFloat?
    let maxHeight: CGFloat?
    let content: () -> Content

    public init(
        showsIndicators: Bool = true,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        maxContentWidth: CGFloat? = nil,
        contentAlignment: Alignment = .topLeading,
        minHeight: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.showsIndicators = showsIndicators
        self.padding = padding
        self.maxContentWidth = maxContentWidth
        self.contentAlignment = contentAlignment
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.content = content
    }

    public var body: some View {
        ScrollView(showsIndicators: showsIndicators) {
            if let maxContentWidth {
                content()
                    .padding(padding)
                    .frame(maxWidth: maxContentWidth, alignment: contentAlignment)
                    .frame(maxWidth: .infinity, alignment: contentAlignment)
            } else {
                content()
                    .padding(padding)
                    .frame(maxWidth: .infinity, alignment: contentAlignment)
            }
        }
        .frame(minHeight: minHeight, maxHeight: maxHeight)
    }
}
