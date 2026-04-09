import SwiftUI
import NolonUIFoundation

enum ResourceCardBadgeStyle {
    case skill
    case workflow
    case mcp

    var foreground: Color {
        switch self {
        case .skill:
            return DesignSystem.Colors.primary
        case .workflow:
            return DesignSystem.Colors.Status.warning
        case .mcp:
            return DesignSystem.Colors.secondary
        }
    }

    var background: Color {
        foreground.opacity(0.15)
    }

    var minHeight: CGFloat {
        switch self {
        case .mcp:
            return 160
        case .skill, .workflow:
            return 140
        }
    }
}

struct ResourceInstallCardTemplate<ExtraAction: View, ExtraContextMenu: View>: View {
    let name: String
    let version: String?
    let summary: String?
    let metaItems: [ResourceCardMetaItem]
    let command: String?
    let badgeStyle: ResourceCardBadgeStyle
    let isInstalled: Bool
    let isInstalling: Bool
    let installErrorMessage: String?
    let isSelected: Bool
    let isDeleting: Bool
    let onTap: () -> Void
    let onInstall: () -> Void
    let onRetry: () -> Void
    let onRevealInFinder: (() -> Void)?
    let onDeleteRequest: (() -> Void)?
    let onCopyCommand: (() -> Void)?
    @ViewBuilder let extraAction: () -> ExtraAction
    @ViewBuilder let extraContextMenu: () -> ExtraContextMenu

    var body: some View {
        UnifiedSlotCardView(
            minHeight: badgeStyle.minHeight,
            contentPadding: 16,
            style: .resource(isSelected: isSelected),
            onTap: onTap,
            spacing: 12,
            showsInlineMenuButton: true,
            showsBody: true,
            showsMeta: true,
            showsDividerBeforeActions: true,
            showsActions: true
        ) {
            ResourceCardHeaderGroup(
                name: name,
                version: version,
                badgeForeground: badgeStyle.foreground,
                badgeBackground: badgeStyle.background
            )
        } bodyContent: {
            ResourceCardSummaryGroup(summary: summary)
        } metaContent: {
            ResourceCardMetaItemsView(items: metaItems)
        } actionContent: {
            HStack(spacing: 8) {
                ResourceInstallStateView(
                    isInstalled: isInstalled,
                    isInstalling: isInstalling,
                    errorMessage: installErrorMessage,
                    onInstall: onInstall,
                    onRetry: onRetry
                )
                extraAction()
            }
        } menuContent: {
            ResourceCardContextMenuGroup(
                onTap: onTap,
                onRevealInFinder: onRevealInFinder,
                canInstall: !isInstalled && !isInstalling,
                onInstall: onInstall,
                canDelete: isInstalled && !isDeleting,
                onDeleteRequest: onDeleteRequest,
                copyCommand: command,
                onCopyCommand: onCopyCommand,
                extraContent: extraContextMenu
            )
        }
    }
}

public struct ResourceSkillCardView<ExtraAction: View, ExtraContextMenu: View>: View {
    private let name: String
    private let version: String?
    private let summary: String?
    private let metaItems: [ResourceCardMetaItem]
    private let isInstalled: Bool
    private let isInstalling: Bool
    private let installErrorMessage: String?
    private let isSelected: Bool
    private let isDeleting: Bool
    private let onTap: () -> Void
    private let onInstall: () -> Void
    private let onRetry: () -> Void
    private let onRevealInFinder: (() -> Void)?
    private let onDeleteRequest: (() -> Void)?
    private let extraAction: () -> ExtraAction
    private let extraContextMenu: () -> ExtraContextMenu

    public struct Config {
        public var name: String
        public var version: String?
        public var summary: String?
        public var metaItems: [ResourceCardMetaItem]
        public var isInstalled: Bool
        public var isInstalling: Bool
        public var installErrorMessage: String?
        public var isSelected: Bool
        public var isDeleting: Bool
        public var onTap: () -> Void
        public var onInstall: () -> Void
        public var onRetry: () -> Void
        public var onRevealInFinder: (() -> Void)?
        public var onDeleteRequest: (() -> Void)?
        public var extraAction: () -> ExtraAction
        public var extraContextMenu: () -> ExtraContextMenu

        public init(
            name: String,
            version: String?,
            summary: String?,
            metaItems: [ResourceCardMetaItem],
            isInstalled: Bool,
            isInstalling: Bool,
            installErrorMessage: String?,
            isSelected: Bool,
            isDeleting: Bool,
            onTap: @escaping () -> Void,
            onInstall: @escaping () -> Void,
            onRetry: @escaping () -> Void,
            onRevealInFinder: (() -> Void)? = nil,
            onDeleteRequest: (() -> Void)? = nil,
            @ViewBuilder extraAction: @escaping () -> ExtraAction,
            @ViewBuilder extraContextMenu: @escaping () -> ExtraContextMenu
        ) {
            self.name = name
            self.version = version
            self.summary = summary
            self.metaItems = metaItems
            self.isInstalled = isInstalled
            self.isInstalling = isInstalling
            self.installErrorMessage = installErrorMessage
            self.isSelected = isSelected
            self.isDeleting = isDeleting
            self.onTap = onTap
            self.onInstall = onInstall
            self.onRetry = onRetry
            self.onRevealInFinder = onRevealInFinder
            self.onDeleteRequest = onDeleteRequest
            self.extraAction = extraAction
            self.extraContextMenu = extraContextMenu
        }
    }

    public init(config: Config) {
        self.name = config.name
        self.version = config.version
        self.summary = config.summary
        self.metaItems = config.metaItems
        self.isInstalled = config.isInstalled
        self.isInstalling = config.isInstalling
        self.installErrorMessage = config.installErrorMessage
        self.isSelected = config.isSelected
        self.isDeleting = config.isDeleting
        self.onTap = config.onTap
        self.onInstall = config.onInstall
        self.onRetry = config.onRetry
        self.onRevealInFinder = config.onRevealInFinder
        self.onDeleteRequest = config.onDeleteRequest
        self.extraAction = config.extraAction
        self.extraContextMenu = config.extraContextMenu
    }

    public init(
        name: String,
        version: String?,
        summary: String?,
        metaItems: [ResourceCardMetaItem],
        isInstalled: Bool,
        isInstalling: Bool,
        installErrorMessage: String?,
        isSelected: Bool,
        isDeleting: Bool,
        onTap: @escaping () -> Void,
        onInstall: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onRevealInFinder: (() -> Void)? = nil,
        onDeleteRequest: (() -> Void)? = nil,
        @ViewBuilder extraAction: @escaping () -> ExtraAction,
        @ViewBuilder extraContextMenu: @escaping () -> ExtraContextMenu
    ) {
        self.init(
            config: Config(
                name: name,
                version: version,
                summary: summary,
                metaItems: metaItems,
                isInstalled: isInstalled,
                isInstalling: isInstalling,
                installErrorMessage: installErrorMessage,
                isSelected: isSelected,
                isDeleting: isDeleting,
                onTap: onTap,
                onInstall: onInstall,
                onRetry: onRetry,
                onRevealInFinder: onRevealInFinder,
                onDeleteRequest: onDeleteRequest,
                extraAction: extraAction,
                extraContextMenu: extraContextMenu
            )
        )
    }

    public init(
        name: String,
        version: String?,
        summary: String?,
        metaItems: [ResourceCardMetaItem],
        isInstalled: Bool,
        isInstalling: Bool,
        installErrorMessage: String?,
        isSelected: Bool,
        isDeleting: Bool,
        onTap: @escaping () -> Void,
        onInstall: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onRevealInFinder: (() -> Void)? = nil,
        onDeleteRequest: (() -> Void)? = nil
    ) where ExtraAction == EmptyView, ExtraContextMenu == EmptyView {
        self.init(
            name: name,
            version: version,
            summary: summary,
            metaItems: metaItems,
            isInstalled: isInstalled,
            isInstalling: isInstalling,
            installErrorMessage: installErrorMessage,
            isSelected: isSelected,
            isDeleting: isDeleting,
            onTap: onTap,
            onInstall: onInstall,
            onRetry: onRetry,
            onRevealInFinder: onRevealInFinder,
            onDeleteRequest: onDeleteRequest,
            extraAction: { EmptyView() },
            extraContextMenu: { EmptyView() }
        )
    }

    public var body: some View {
        ResourceInstallCardTemplate(
            name: name,
            version: version,
            summary: summary,
            metaItems: metaItems,
            command: nil,
            badgeStyle: .skill,
            isInstalled: isInstalled,
            isInstalling: isInstalling,
            installErrorMessage: installErrorMessage,
            isSelected: isSelected,
            isDeleting: isDeleting,
            onTap: onTap,
            onInstall: onInstall,
            onRetry: onRetry,
            onRevealInFinder: onRevealInFinder,
            onDeleteRequest: onDeleteRequest,
            onCopyCommand: nil,
            extraAction: extraAction,
            extraContextMenu: extraContextMenu
        )
    }
}

public struct ResourceWorkflowCardView<ExtraContextMenu: View>: View {
    private let name: String
    private let version: String?
    private let summary: String?
    private let metaItems: [ResourceCardMetaItem]
    private let isInstalled: Bool
    private let isInstalling: Bool
    private let installErrorMessage: String?
    private let isSelected: Bool
    private let isDeleting: Bool
    private let onTap: () -> Void
    private let onInstall: () -> Void
    private let onRetry: () -> Void
    private let onRevealInFinder: (() -> Void)?
    private let onDeleteRequest: (() -> Void)?
    private let extraContextMenu: () -> ExtraContextMenu

    public struct Config {
        public var name: String
        public var version: String?
        public var summary: String?
        public var metaItems: [ResourceCardMetaItem]
        public var isInstalled: Bool
        public var isInstalling: Bool
        public var installErrorMessage: String?
        public var isSelected: Bool
        public var isDeleting: Bool
        public var onTap: () -> Void
        public var onInstall: () -> Void
        public var onRetry: () -> Void
        public var onRevealInFinder: (() -> Void)?
        public var onDeleteRequest: (() -> Void)?
        public var extraContextMenu: () -> ExtraContextMenu

        public init(
            name: String,
            version: String?,
            summary: String?,
            metaItems: [ResourceCardMetaItem],
            isInstalled: Bool,
            isInstalling: Bool,
            installErrorMessage: String?,
            isSelected: Bool,
            isDeleting: Bool,
            onTap: @escaping () -> Void,
            onInstall: @escaping () -> Void,
            onRetry: @escaping () -> Void,
            onRevealInFinder: (() -> Void)? = nil,
            onDeleteRequest: (() -> Void)? = nil,
            @ViewBuilder extraContextMenu: @escaping () -> ExtraContextMenu
        ) {
            self.name = name
            self.version = version
            self.summary = summary
            self.metaItems = metaItems
            self.isInstalled = isInstalled
            self.isInstalling = isInstalling
            self.installErrorMessage = installErrorMessage
            self.isSelected = isSelected
            self.isDeleting = isDeleting
            self.onTap = onTap
            self.onInstall = onInstall
            self.onRetry = onRetry
            self.onRevealInFinder = onRevealInFinder
            self.onDeleteRequest = onDeleteRequest
            self.extraContextMenu = extraContextMenu
        }
    }

    public init(config: Config) {
        self.name = config.name
        self.version = config.version
        self.summary = config.summary
        self.metaItems = config.metaItems
        self.isInstalled = config.isInstalled
        self.isInstalling = config.isInstalling
        self.installErrorMessage = config.installErrorMessage
        self.isSelected = config.isSelected
        self.isDeleting = config.isDeleting
        self.onTap = config.onTap
        self.onInstall = config.onInstall
        self.onRetry = config.onRetry
        self.onRevealInFinder = config.onRevealInFinder
        self.onDeleteRequest = config.onDeleteRequest
        self.extraContextMenu = config.extraContextMenu
    }

    public init(
        name: String,
        version: String?,
        summary: String?,
        metaItems: [ResourceCardMetaItem],
        isInstalled: Bool,
        isInstalling: Bool,
        installErrorMessage: String?,
        isSelected: Bool,
        isDeleting: Bool,
        onTap: @escaping () -> Void,
        onInstall: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onRevealInFinder: (() -> Void)? = nil,
        onDeleteRequest: (() -> Void)? = nil,
        @ViewBuilder extraContextMenu: @escaping () -> ExtraContextMenu
    ) {
        self.init(
            config: Config(
                name: name,
                version: version,
                summary: summary,
                metaItems: metaItems,
                isInstalled: isInstalled,
                isInstalling: isInstalling,
                installErrorMessage: installErrorMessage,
                isSelected: isSelected,
                isDeleting: isDeleting,
                onTap: onTap,
                onInstall: onInstall,
                onRetry: onRetry,
                onRevealInFinder: onRevealInFinder,
                onDeleteRequest: onDeleteRequest,
                extraContextMenu: extraContextMenu
            )
        )
    }

    public init(
        name: String,
        version: String?,
        summary: String?,
        metaItems: [ResourceCardMetaItem],
        isInstalled: Bool,
        isInstalling: Bool,
        installErrorMessage: String?,
        isSelected: Bool,
        isDeleting: Bool,
        onTap: @escaping () -> Void,
        onInstall: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onRevealInFinder: (() -> Void)? = nil,
        onDeleteRequest: (() -> Void)? = nil
    ) where ExtraContextMenu == EmptyView {
        self.init(
            name: name,
            version: version,
            summary: summary,
            metaItems: metaItems,
            isInstalled: isInstalled,
            isInstalling: isInstalling,
            installErrorMessage: installErrorMessage,
            isSelected: isSelected,
            isDeleting: isDeleting,
            onTap: onTap,
            onInstall: onInstall,
            onRetry: onRetry,
            onRevealInFinder: onRevealInFinder,
            onDeleteRequest: onDeleteRequest,
            extraContextMenu: { EmptyView() }
        )
    }

    public var body: some View {
        ResourceInstallCardTemplate(
            name: name,
            version: version,
            summary: summary,
            metaItems: metaItems,
            command: nil,
            badgeStyle: .workflow,
            isInstalled: isInstalled,
            isInstalling: isInstalling,
            installErrorMessage: installErrorMessage,
            isSelected: isSelected,
            isDeleting: isDeleting,
            onTap: onTap,
            onInstall: onInstall,
            onRetry: onRetry,
            onRevealInFinder: onRevealInFinder,
            onDeleteRequest: onDeleteRequest,
            onCopyCommand: nil,
            extraAction: { EmptyView() },
            extraContextMenu: extraContextMenu
        )
    }
}

public struct ResourceMcpCardView<ExtraContextMenu: View>: View {
    private let name: String
    private let version: String?
    private let summary: String?
    private let metaItems: [ResourceCardMetaItem]
    private let command: String?
    private let isInstalled: Bool
    private let isInstalling: Bool
    private let installErrorMessage: String?
    private let isSelected: Bool
    private let isDeleting: Bool
    private let onTap: () -> Void
    private let onInstall: () -> Void
    private let onRetry: () -> Void
    private let onRevealInFinder: (() -> Void)?
    private let onDeleteRequest: (() -> Void)?
    private let onCopyCommand: (() -> Void)?
    private let extraContextMenu: () -> ExtraContextMenu

    public struct Config {
        public var name: String
        public var version: String?
        public var summary: String?
        public var metaItems: [ResourceCardMetaItem]
        public var command: String?
        public var isInstalled: Bool
        public var isInstalling: Bool
        public var installErrorMessage: String?
        public var isSelected: Bool
        public var isDeleting: Bool
        public var onTap: () -> Void
        public var onInstall: () -> Void
        public var onRetry: () -> Void
        public var onRevealInFinder: (() -> Void)?
        public var onDeleteRequest: (() -> Void)?
        public var onCopyCommand: (() -> Void)?
        public var extraContextMenu: () -> ExtraContextMenu

        public init(
            name: String,
            version: String?,
            summary: String?,
            metaItems: [ResourceCardMetaItem],
            command: String?,
            isInstalled: Bool,
            isInstalling: Bool,
            installErrorMessage: String?,
            isSelected: Bool,
            isDeleting: Bool,
            onTap: @escaping () -> Void,
            onInstall: @escaping () -> Void,
            onRetry: @escaping () -> Void,
            onRevealInFinder: (() -> Void)? = nil,
            onDeleteRequest: (() -> Void)? = nil,
            onCopyCommand: (() -> Void)? = nil,
            @ViewBuilder extraContextMenu: @escaping () -> ExtraContextMenu
        ) {
            self.name = name
            self.version = version
            self.summary = summary
            self.metaItems = metaItems
            self.command = command
            self.isInstalled = isInstalled
            self.isInstalling = isInstalling
            self.installErrorMessage = installErrorMessage
            self.isSelected = isSelected
            self.isDeleting = isDeleting
            self.onTap = onTap
            self.onInstall = onInstall
            self.onRetry = onRetry
            self.onRevealInFinder = onRevealInFinder
            self.onDeleteRequest = onDeleteRequest
            self.onCopyCommand = onCopyCommand
            self.extraContextMenu = extraContextMenu
        }
    }

    public init(config: Config) {
        self.name = config.name
        self.version = config.version
        self.summary = config.summary
        self.metaItems = config.metaItems
        self.command = config.command
        self.isInstalled = config.isInstalled
        self.isInstalling = config.isInstalling
        self.installErrorMessage = config.installErrorMessage
        self.isSelected = config.isSelected
        self.isDeleting = config.isDeleting
        self.onTap = config.onTap
        self.onInstall = config.onInstall
        self.onRetry = config.onRetry
        self.onRevealInFinder = config.onRevealInFinder
        self.onDeleteRequest = config.onDeleteRequest
        self.onCopyCommand = config.onCopyCommand
        self.extraContextMenu = config.extraContextMenu
    }

    public init(
        name: String,
        version: String?,
        summary: String?,
        metaItems: [ResourceCardMetaItem],
        command: String?,
        isInstalled: Bool,
        isInstalling: Bool,
        installErrorMessage: String?,
        isSelected: Bool,
        isDeleting: Bool,
        onTap: @escaping () -> Void,
        onInstall: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onRevealInFinder: (() -> Void)? = nil,
        onDeleteRequest: (() -> Void)? = nil,
        onCopyCommand: (() -> Void)? = nil,
        @ViewBuilder extraContextMenu: @escaping () -> ExtraContextMenu
    ) {
        self.init(
            config: Config(
                name: name,
                version: version,
                summary: summary,
                metaItems: metaItems,
                command: command,
                isInstalled: isInstalled,
                isInstalling: isInstalling,
                installErrorMessage: installErrorMessage,
                isSelected: isSelected,
                isDeleting: isDeleting,
                onTap: onTap,
                onInstall: onInstall,
                onRetry: onRetry,
                onRevealInFinder: onRevealInFinder,
                onDeleteRequest: onDeleteRequest,
                onCopyCommand: onCopyCommand,
                extraContextMenu: extraContextMenu
            )
        )
    }

    public init(
        name: String,
        version: String?,
        summary: String?,
        metaItems: [ResourceCardMetaItem],
        command: String?,
        isInstalled: Bool,
        isInstalling: Bool,
        installErrorMessage: String?,
        isSelected: Bool,
        isDeleting: Bool,
        onTap: @escaping () -> Void,
        onInstall: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onRevealInFinder: (() -> Void)? = nil,
        onDeleteRequest: (() -> Void)? = nil,
        onCopyCommand: (() -> Void)? = nil
    ) where ExtraContextMenu == EmptyView {
        self.init(
            name: name,
            version: version,
            summary: summary,
            metaItems: metaItems,
            command: command,
            isInstalled: isInstalled,
            isInstalling: isInstalling,
            installErrorMessage: installErrorMessage,
            isSelected: isSelected,
            isDeleting: isDeleting,
            onTap: onTap,
            onInstall: onInstall,
            onRetry: onRetry,
            onRevealInFinder: onRevealInFinder,
            onDeleteRequest: onDeleteRequest,
            onCopyCommand: onCopyCommand,
            extraContextMenu: { EmptyView() }
        )
    }

    public var body: some View {
        ResourceInstallCardTemplate(
            name: name,
            version: version,
            summary: summary,
            metaItems: metaItems,
            command: command,
            badgeStyle: .mcp,
            isInstalled: isInstalled,
            isInstalling: isInstalling,
            installErrorMessage: installErrorMessage,
            isSelected: isSelected,
            isDeleting: isDeleting,
            onTap: onTap,
            onInstall: onInstall,
            onRetry: onRetry,
            onRevealInFinder: onRevealInFinder,
            onDeleteRequest: onDeleteRequest,
            onCopyCommand: onCopyCommand,
            extraAction: { EmptyView() },
            extraContextMenu: extraContextMenu
        )
    }
}

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
        ProviderCardDescriptionBlock(
            text: preview,
            searchText: searchText,
            minHeight: minHeight,
            maxHeight: maxHeight,
            allowsEmpty: true,
            placeholderHeight: placeholderHeight
        )
    }
}

struct ProviderCardDescriptionBlock: View {
    let text: String
    let searchText: String
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let allowsEmpty: Bool
    let placeholderHeight: CGFloat?

    init(
        text: String,
        searchText: String,
        minHeight: CGFloat,
        maxHeight: CGFloat,
        allowsEmpty: Bool = false,
        placeholderHeight: CGFloat? = nil
    ) {
        self.text = text
        self.searchText = searchText
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.allowsEmpty = allowsEmpty
        self.placeholderHeight = placeholderHeight
    }

    var body: some View {
        if allowsEmpty, text.isEmpty {
            Color.clear
                .frame(height: placeholderHeight)
                .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: maxHeight, alignment: .topLeading)
        } else {
            HighlightedText(text: text, query: searchText)
                .font(.caption)
                .dsSecondaryText(font: .caption)
                .lineLimit(3)
                .truncationMode(.tail)
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

struct ProviderCardActionBadge<Content: View>: View {
    let foreground: Color
    let background: Color
    let cornerRadius: CGFloat
    @ViewBuilder let content: Content

    init(
        foreground: Color,
        background: Color,
        cornerRadius: CGFloat = DesignSystem.Metrics.cornerRadiusS,
        @ViewBuilder content: () -> Content
    ) {
        self.foreground = foreground
        self.background = background
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .fontWeight(.semibold)
            .dsBadge(
                foreground: foreground,
                background: background,
                horizontalPadding: 6,
                verticalPadding: 6,
                cornerRadius: cornerRadius
            )
    }
}

struct ResourceCardHeaderGroup: View {
    let name: String
    let version: String?
    let badgeForeground: Color
    let badgeBackground: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.headline.weight(.semibold))
                .lineLimit(1)

            if let version {
                Text(version)
                    .font(.system(size: 10, weight: .bold))
                    .dsBadge(
                        foreground: badgeForeground,
                        background: badgeBackground,
                        horizontalPadding: 6,
                        verticalPadding: 2
                    )
            }
        }
    }
}

struct ResourceCardSummaryGroup: View {
    let summary: String?

    var body: some View {
        if let summary {
            Text(summary)
                .dsSecondaryText(font: .subheadline)
                .lineSpacing(2)
                .lineLimit(3)
                .frame(maxHeight: .infinity, alignment: .topLeading)
        } else {
            Spacer()
        }
    }
}

struct ResourceCardContextMenuGroup<ExtraContent: View>: View {
    let onTap: () -> Void
    let onRevealInFinder: (() -> Void)?
    let canInstall: Bool
    let onInstall: () -> Void
    let canDelete: Bool
    let onDeleteRequest: (() -> Void)?
    let copyCommand: String?
    let onCopyCommand: (() -> Void)?
    let extraContent: () -> ExtraContent

    var body: some View {
        ContextMenuViewDetailsButton(action: onTap)

        if let onRevealInFinder {
            ContextMenuShowInFinderButton(action: onRevealInFinder)
        }

        if canInstall {
            Divider()
            ContextMenuInstallButton(action: onInstall)
        }

        if canDelete {
            Divider()
            ContextMenuDeleteButton(
                isEnabled: onDeleteRequest != nil,
                action: { onDeleteRequest?() }
            )
        }

        if let command = copyCommand, !command.isEmpty, let onCopyCommand {
            Divider()
            Button {
                onCopyCommand()
            } label: {
                Label(NSLocalizedString("Copy Command", comment: "Copy command"), systemImage: "doc.on.doc")
                    .dsIconLabelButton()
            }
        }

        extraContent()
    }
}

public enum ResourceCardMetaItem: Equatable, Sendable {
    case stars(Int)
    case downloads(Int)
    case usages(Int)
    case installs(Int)
    case command(String)
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
