import SwiftUI

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
        UnifiedCardContainerView(
            minHeight: 140,
            contentPadding: 16,
            style: .resource(isSelected: isSelected),
            onTap: onTap
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    headerView
                    Spacer()
                    EllipsisMenuButton(content: { contextMenuItems })
                }
                summaryView
                ResourceCardMetaItemsView(items: metaItems)
                Divider()
                actionView
            }
        } menuContent: {
            contextMenuItems
        }
    }

    @ViewBuilder
    private var headerView: some View {
        ResourceCardHeaderGroup(
            name: name,
            version: version,
            badgeForeground: DesignSystem.Colors.Status.warning,
            badgeBackground: DesignSystem.Colors.Status.warning.opacity(0.15)
        )
    }

    @ViewBuilder
    private var summaryView: some View {
        ResourceCardSummaryGroup(summary: summary)
    }

    private var actionView: some View {
        ResourceInstallStateView(
            isInstalled: isInstalled,
            isInstalling: isInstalling,
            errorMessage: installErrorMessage,
            onInstall: onInstall,
            onRetry: onRetry
        )
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
