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
        ResourceCardScaffold(
            minHeight: 140,
            isSelected: isSelected,
            onTap: onTap,
            headerContent: { headerView },
            summaryContent: { summaryView },
            metaContent: { ResourceCardMetaItemsView(items: metaItems) },
            actionContent: { actionView },
            menuContent: { contextMenuItems }
        )
    }

    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.headline.weight(.semibold))
                .lineLimit(1)

            if let version {
                Text(version)
                    .font(.system(size: 10, weight: .bold))
                    .dsBadge(
                        foreground: DesignSystem.Colors.primary,
                        background: DesignSystem.Colors.primary.opacity(0.15),
                        horizontalPadding: 6,
                        verticalPadding: 2
                    )
            }
        }
    }

    @ViewBuilder
    private var summaryView: some View {
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
        Button {
            onTap()
        } label: {
            Label(NSLocalizedString("View Details", comment: "View resource details"), systemImage: "info.circle")
                .dsIconLabelButton()
        }

        if let onRevealInFinder {
            Button {
                onRevealInFinder()
            } label: {
                Label(NSLocalizedString("action.show_in_finder", comment: "Show in Finder"), systemImage: "folder")
                    .dsIconLabelButton()
            }
        }

        if !isInstalled && !isInstalling {
            Divider()
            Button {
                onInstall()
            } label: {
                Label(NSLocalizedString("action.install", value: "Install", comment: "Install action"), systemImage: "arrow.down.circle")
                    .dsIconLabelButton()
            }
        }

        if isInstalled && !isDeleting {
            Divider()
            Button(role: .destructive) {
                onDeleteRequest?()
            } label: {
                Label(NSLocalizedString("action.delete", value: "Delete", comment: "Delete action"), systemImage: "trash")
                    .dsIconLabelButton()
            }
            .disabled(onDeleteRequest == nil)
        }

        extraContextMenu()
    }
}

