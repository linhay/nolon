import SwiftUI

struct ResourceCardShell<HeaderContent: View, SummaryContent: View, MetaContent: View, ActionContent: View, MenuContent: View>: View {
    let minHeight: CGFloat
    let isSelected: Bool
    let onTap: () -> Void
    @ViewBuilder let headerContent: HeaderContent
    @ViewBuilder let summaryContent: SummaryContent
    @ViewBuilder let metaContent: MetaContent
    @ViewBuilder let actionContent: ActionContent
    @ViewBuilder let menuContent: MenuContent

    @State private var isHovered = false

    init(
        minHeight: CGFloat = 140,
        isSelected: Bool = false,
        onTap: @escaping () -> Void,
        @ViewBuilder headerContent: () -> HeaderContent,
        @ViewBuilder summaryContent: () -> SummaryContent,
        @ViewBuilder metaContent: () -> MetaContent,
        @ViewBuilder actionContent: () -> ActionContent,
        @ViewBuilder menuContent: () -> MenuContent
    ) {
        self.minHeight = minHeight
        self.isSelected = isSelected
        self.onTap = onTap
        self.headerContent = headerContent()
        self.summaryContent = summaryContent()
        self.metaContent = metaContent()
        self.actionContent = actionContent()
        self.menuContent = menuContent()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                headerContent
                Spacer()
                moreMenu
            }

            summaryContent

            HStack(alignment: .center) {
                metaContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(0)
                Spacer()
                actionContent
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(2)
            }
        }
        .padding(16)
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
        .contentShape(Rectangle())
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
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            menuContent
        }
    }

    private var moreMenu: some View {
        Menu {
            menuContent
        } label: {
            Image(systemName: "ellipsis")
                .dsIconButton()
        }
        .dsBorderlessMenu()
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
