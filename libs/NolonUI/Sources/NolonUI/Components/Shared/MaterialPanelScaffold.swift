import SwiftUI

public struct MaterialPanelScaffold<Header: View, Content: View, Footer: View>: View {
    let width: CGFloat
    let cornerRadius: CGFloat
    let dividerOpacity: CGFloat
    let header: () -> Header
    let content: () -> Content
    let footer: () -> Footer

    public init(
        width: CGFloat = 360,
        cornerRadius: CGFloat = 20,
        dividerOpacity: CGFloat = 0.5,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.width = width
        self.cornerRadius = cornerRadius
        self.dividerOpacity = dividerOpacity
        self.header = header
        self.content = content
        self.footer = footer
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header()
            content()
            Divider()
                .opacity(dividerOpacity)
            footer()
        }
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}
