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
        UnifiedCardContainerView(
            minHeight: minHeight,
            contentPadding: 16,
            style: .resource(isSelected: isSelected),
            onTap: onTap
        ) {
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
        } menuContent: {
            menuContent
        }
    }

    private var moreMenu: some View {
        EllipsisMenuButton(content: { menuContent })
    }
}

struct ResourceCardMetaItemsView: View {
    @State private var viewModel = ResourceCardMetaItemsViewViewModel()
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
