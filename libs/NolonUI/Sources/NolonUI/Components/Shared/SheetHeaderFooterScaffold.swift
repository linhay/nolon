import SwiftUI

public struct SheetHeaderFooterScaffold<Content: View, Footer: View>: View {
    let title: String
    let subtitle: String?
    let isCloseDisabled: Bool
    let onClose: () -> Void
    let content: () -> Content
    let footer: () -> Footer

    public init(
        title: String,
        subtitle: String? = nil,
        isCloseDisabled: Bool = false,
        onClose: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isCloseDisabled = isCloseDisabled
        self.onClose = onClose
        self.content = content
        self.footer = footer
    }

    public var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(
                title: title,
                subtitle: subtitle,
                isCloseDisabled: isCloseDisabled,
                onClose: onClose
            )

            SheetDivider()

            content()

            SheetDivider()

            footer()
        }
    }
}
