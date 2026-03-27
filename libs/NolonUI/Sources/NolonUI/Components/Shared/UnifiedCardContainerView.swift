import SwiftUI

enum UnifiedCardContainerStyle {
    case provider(isSelected: Bool)
    case resource(isSelected: Bool)
}

struct UnifiedCardContainerView<Content: View, MenuContent: View>: View {
    @State private var isHovered = false

    let minHeight: CGFloat
    let contentPadding: CGFloat
    let style: UnifiedCardContainerStyle
    let onTap: (() -> Void)?
    @ViewBuilder let content: () -> Content
    @ViewBuilder let menuContent: () -> MenuContent

    init(
        minHeight: CGFloat,
        contentPadding: CGFloat,
        style: UnifiedCardContainerStyle,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder menuContent: @escaping () -> MenuContent
    ) {
        self.minHeight = minHeight
        self.contentPadding = contentPadding
        self.style = style
        self.onTap = onTap
        self.content = content
        self.menuContent = menuContent
    }

    var body: some View {
        let wrapped = styledContent()
            .contentShape(Rectangle())
            .contextMenu {
                menuContent()
            }

        let tappable: AnyView
        if let onTap {
            tappable = AnyView(wrapped.onTapGesture(perform: onTap))
        } else {
            tappable = AnyView(wrapped)
        }

        return tappable
    }

    @ViewBuilder
    private func styledContent() -> some View {
        switch style {
        case let .provider(isSelected):
            content()
                .padding(contentPadding)
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
                .providerTabCardStyle(isSelected: isSelected)

        case let .resource(isSelected):
            content()
                .padding(contentPadding)
                .frame(minHeight: minHeight)
                .dsCard(
                    background: isSelected
                        ? DesignSystem.Colors.primary.opacity(0.10)
                        : DesignSystem.Colors.Background.elevated,
                    borderColor: isSelected
                        ? DesignSystem.Colors.primary
                        : (isHovered
                            ? DesignSystem.Colors.primary.opacity(0.24)
                            : DesignSystem.Colors.Component.border.opacity(0.60)),
                    borderWidth: isSelected ? 2 : 1
                )
                .shadow(
                    color: DesignSystem.Colors.Shadow.floating.opacity(isHovered ? 0.28 : 0.18),
                    radius: isHovered ? 12 : 7,
                    y: isHovered ? 6 : 3
                )
                .scaleEffect(isHovered ? 1.015 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
                .onHover { hovering in
                    isHovered = hovering
                }
        }
    }
}
