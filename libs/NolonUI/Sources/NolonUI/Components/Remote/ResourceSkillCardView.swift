import SwiftUI

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
        ProviderCardTemplate(
            minHeight: 140,
            isSelected: isSelected,
            showsActionDivider: true,
            onTap: onTap,
            headerContent: { headerView },
            bodyContent: { summaryView },
            footerContent: { ResourceCardMetaItemsView(items: metaItems) },
            actionContent: { actionView },
            contextMenuContent: { contextMenuItems }
        )
    }

    @ViewBuilder
    private var headerView: some View {
        ResourceCardHeaderGroup(
            name: name,
            version: version,
            badgeForeground: DesignSystem.Colors.primary,
            badgeBackground: DesignSystem.Colors.primary.opacity(0.15)
        )
    }

    @ViewBuilder
    private var summaryView: some View {
        ResourceCardSummaryGroup(summary: summary)
    }

    private var actionView: some View {
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
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        ResourceCardContextMenuGroup(
            onTap: onTap,
            onRevealInFinder: onRevealInFinder,
            canInstall: !isInstalled && !isInstalling,
            onInstall: onInstall,
            canDelete: isInstalled && !isDeleting,
            onDeleteRequest: onDeleteRequest,
            copyCommand: nil,
            onCopyCommand: nil,
            extraContent: extraContextMenu
        )
    }
}
