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
