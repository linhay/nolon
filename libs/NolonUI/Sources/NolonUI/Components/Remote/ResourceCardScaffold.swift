import SwiftUI

public enum ResourceCardMetaItem: Equatable, Sendable {
    case stars(Int)
    case downloads(Int)
    case usages(Int)
    case installs(Int)
    case command(String)
}

struct ResourceCardScaffold<HeaderContent: View, SummaryContent: View, MetaContent: View, ActionContent: View, MenuContent: View>: View {
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

struct ResourceCardMetaItemsView: View {
    let items: [ResourceCardMetaItem]

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    metaLabel(for: item)
                }
            }
        }
    }

    @ViewBuilder
    private func metaLabel(for item: ResourceCardMetaItem) -> some View {
        switch item {
        case let .stars(value):
            Label("\(value)", systemImage: "star.fill")
                .dsIconLabelText(foreground: DesignSystem.Colors.Status.warning, font: .caption2)
        case let .downloads(value):
            Label("\(value)", systemImage: "arrow.down.circle")
                .dsIconLabelText()
        case let .usages(value):
            Label("\(value)", systemImage: "arrow.triangle.branch")
                .dsIconLabelText()
        case let .installs(value):
            Label("\(value)", systemImage: "server.rack")
                .dsIconLabelText()
        case let .command(value):
            HStack(spacing: 4) {
                Image(systemName: "terminal")
                    .font(.caption2)
                Text(value)
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .dsBadge(
                foreground: DesignSystem.Colors.Text.secondary,
                background: DesignSystem.Colors.Component.controlFillSubtle,
                horizontalPadding: 6,
                verticalPadding: 3,
                cornerRadius: DesignSystem.Metrics.cornerRadiusXS
            )
            .frame(maxWidth: 160, alignment: .leading)
        }
    }
}
