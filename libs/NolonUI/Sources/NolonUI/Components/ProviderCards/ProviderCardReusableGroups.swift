import SwiftUI

struct ProviderCardTitleMenuRow<TitleContent: View, MenuContent: View>: View {
    @ViewBuilder let titleContent: TitleContent
    @ViewBuilder let menuContent: MenuContent

    init(
        @ViewBuilder titleContent: () -> TitleContent,
        @ViewBuilder menuContent: () -> MenuContent
    ) {
        self.titleContent = titleContent()
        self.menuContent = menuContent()
    }

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Metrics.spacingS) {
            titleContent
            Spacer()
            EllipsisMenuButton(content: { menuContent })
        }
    }
}

struct ProviderCardRevealDeleteContextMenu<ExtraContent: View>: View {
    let onReveal: () -> Void
    let onDeleteRequest: () -> Void
    let extraContent: () -> ExtraContent

    var body: some View {
        ContextMenuShowInFinderButton(action: onReveal)

        Divider()

        ContextMenuDeleteButton(action: onDeleteRequest)

        extraContent()
    }
}

struct ProviderCardOptionalPreviewBlock: View {
    let preview: String
    let searchText: String
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let placeholderHeight: CGFloat?

    init(
        preview: String,
        searchText: String,
        minHeight: CGFloat,
        maxHeight: CGFloat,
        placeholderHeight: CGFloat? = nil
    ) {
        self.preview = preview
        self.searchText = searchText
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.placeholderHeight = placeholderHeight
    }

    var body: some View {
        let hasPreview = !preview.isEmpty

        if hasPreview {
            HighlightedText(text: preview, query: searchText)
                .font(.caption)
                .dsSecondaryText(font: .caption)
                .lineLimit(3)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: maxHeight, alignment: .topLeading)
        } else {
            Color.clear
                .frame(height: placeholderHeight)
                .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: maxHeight, alignment: .topLeading)
        }
    }
}

struct ProviderCardIconCaptionRow: View {
    let iconName: String
    let title: String
    let iconColor: Color
    let textFont: Font
    let textColor: Color
    let spacing: CGFloat

    init(
        iconName: String,
        title: String,
        iconColor: Color = DesignSystem.Colors.Text.secondary,
        textFont: Font = .caption,
        textColor: Color = DesignSystem.Colors.Text.secondary,
        spacing: CGFloat = DesignSystem.Metrics.spacingS - 2
    ) {
        self.iconName = iconName
        self.title = title
        self.iconColor = iconColor
        self.textFont = textFont
        self.textColor = textColor
        self.spacing = spacing
    }

    var body: some View {
        HStack(spacing: spacing) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
            Text(title)
                .font(textFont)
                .foregroundStyle(textColor)
                .lineLimit(1)
        }
    }
}

struct ProviderCardMetaCountLabel: View {
    let count: Int
    let systemImage: String

    var body: some View {
        Label("\(count)", systemImage: systemImage)
            .dsIconLabelButton(
                foreground: DesignSystem.Colors.Text.secondary,
                font: .caption2
            )
    }
}
