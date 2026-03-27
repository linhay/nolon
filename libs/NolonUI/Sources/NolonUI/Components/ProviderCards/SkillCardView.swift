import SwiftUI
import NolonUIFoundation

public struct SkillCardView<ExtraContextMenu: View>: View {
    @State private var viewModel: SkillCardViewViewModel
    private let onReveal: () -> Void
    private let onUninstall: () async -> Void
    private let onLinkWorkflow: () -> Void
    private let onUnlinkWorkflow: () -> Void
    private let onMigrate: () async -> Void
    private let onTap: () -> Void
    private let extraContextMenu: () -> ExtraContextMenu

    private let descriptionHeight: CGFloat = 44

    public init(
        name: String,
        description: String,
        version: String,
        isOrphaned: Bool,
        hasWorkflow: Bool,
        referenceCount: Int,
        scriptCount: Int,
        searchText: String,
        onReveal: @escaping () -> Void,
        onUninstall: @escaping () async -> Void,
        onLinkWorkflow: @escaping () -> Void,
        onUnlinkWorkflow: @escaping () -> Void,
        onMigrate: @escaping () async -> Void,
        onTap: @escaping () -> Void,
        @ViewBuilder extraContextMenu: @escaping () -> ExtraContextMenu
    ) {
        self._viewModel = State(
            initialValue: SkillCardViewViewModel(
                name: name,
                descriptionText: description,
                version: version,
                isOrphaned: isOrphaned,
                hasWorkflow: hasWorkflow,
                referenceCount: referenceCount,
                scriptCount: scriptCount,
                searchText: searchText
            )
        )
        self.onReveal = onReveal
        self.onUninstall = onUninstall
        self.onLinkWorkflow = onLinkWorkflow
        self.onUnlinkWorkflow = onUnlinkWorkflow
        self.onMigrate = onMigrate
        self.onTap = onTap
        self.extraContextMenu = extraContextMenu
    }

    public init(
        name: String,
        description: String,
        version: String,
        isOrphaned: Bool,
        hasWorkflow: Bool,
        referenceCount: Int,
        scriptCount: Int,
        searchText: String,
        onReveal: @escaping () -> Void,
        onUninstall: @escaping () async -> Void,
        onLinkWorkflow: @escaping () -> Void,
        onUnlinkWorkflow: @escaping () -> Void,
        onMigrate: @escaping () async -> Void,
        onTap: @escaping () -> Void
    ) where ExtraContextMenu == EmptyView {
        self.init(
            name: name,
            description: description,
            version: version,
            isOrphaned: isOrphaned,
            hasWorkflow: hasWorkflow,
            referenceCount: referenceCount,
            scriptCount: scriptCount,
            searchText: searchText,
            onReveal: onReveal,
            onUninstall: onUninstall,
            onLinkWorkflow: onLinkWorkflow,
            onUnlinkWorkflow: onUnlinkWorkflow,
            onMigrate: onMigrate,
            onTap: onTap,
            extraContextMenu: { EmptyView() }
        )
    }

    public var body: some View {
        ProviderCardTemplate(
            minHeight: 140,
            onTap: onTap
        ) {
            ProviderCardTitleMenuRow {
                HighlightedText(text: viewModel.name, query: viewModel.searchText)
                    .font(.headline)
                    .lineLimit(1)
            } menuContent: {
                contextMenuItems
            }
        } bodyContent: {
            VStack(alignment: .leading, spacing: DesignSystem.Metrics.spacingM) {
                HStack(spacing: 4) {
                    Text("v\(viewModel.version)")
                        .dsBadge(
                            foreground: DesignSystem.Colors.Text.primary,
                            background: DesignSystem.Colors.Component.controlFillSubtle,
                            horizontalPadding: 6,
                            verticalPadding: 2,
                            cornerRadius: DesignSystem.Metrics.cornerRadiusXS
                        )
                    if viewModel.isOrphaned {
                        Text(NSLocalizedString("skill.orphaned", value: "Needs Migration", comment: "Orphaned skill badge"))
                            .dsBadge(
                                foreground: DesignSystem.Colors.Text.onAccent,
                                background: DesignSystem.Colors.Status.warning,
                                horizontalPadding: 6,
                                verticalPadding: 2,
                                cornerRadius: DesignSystem.Metrics.cornerRadiusXS
                            )
                    }
                }

                ProviderCardDescriptionBlock(
                    text: viewModel.descriptionText,
                    searchText: viewModel.searchText,
                    minHeight: descriptionHeight,
                    maxHeight: descriptionHeight
                )
            }
        } footerContent: {
            EmptyView()
        } actionContent: {
            actionRow
        } contextMenuContent: {
            contextMenuItems
        }
        .destructiveConfirmationDialog(
            data: DestructiveConfirmationDialogData(
                title: NSLocalizedString("action.uninstall_confirm_title", value: "Confirm Uninstall", comment: "Uninstall confirmation title"),
                message: NSLocalizedString(
                    "action.uninstall_confirm_message",
                    value: "Are you sure you want to uninstall this skill? This action cannot be undone.",
                    comment: "Uninstall confirmation message"
                ),
                confirmTitle: NSLocalizedString("action.uninstall", comment: "Uninstall"),
                cancelTitle: NSLocalizedString("action.cancel", value: "Cancel", comment: "Cancel action")
            ),
            isPresented: $viewModel.showingUninstallConfirmation,
            onConfirm: {
                Task { await onUninstall() }
            },
            onCancel: {}
        )
    }

    @ViewBuilder
    private var actionRow: some View {
        if viewModel.hasWorkflow {
            HStack {
                Button {
                    onUnlinkWorkflow()
                } label: {
                    ProviderCardActionBadge(
                        foreground: DesignSystem.Colors.primary,
                        background: DesignSystem.Colors.primary.opacity(DesignSystem.Colors.Opacity.subtle),
                        cornerRadius: DesignSystem.Metrics.cornerRadiusS
                    ) {
                        ProviderCardIconCaptionRow(
                            iconName: "arrow.triangle.branch",
                            title: "Workflow",
                            iconColor: DesignSystem.Colors.primary,
                            textColor: DesignSystem.Colors.primary
                        )
                    }
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: DesignSystem.Metrics.spacingM) {
                Button {
                    onLinkWorkflow()
                } label: {
                    ProviderCardActionBadge(
                        foreground: DesignSystem.Colors.Text.secondary,
                        background: DesignSystem.Colors.Component.controlFill,
                        cornerRadius: DesignSystem.Metrics.cornerRadiusS
                    ) {
                        ProviderCardIconCaptionRow(
                            iconName: "plus.circle",
                            title: NSLocalizedString("action.link_workflow", comment: "Link to Workflow")
                        )
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                if viewModel.referenceCount > 0 {
                    ProviderCardMetaCountLabel(count: viewModel.referenceCount, systemImage: "doc.text")
                }
                if viewModel.scriptCount > 0 {
                    ProviderCardMetaCountLabel(count: viewModel.scriptCount, systemImage: "terminal")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.caption2)
            .dsSecondaryText(font: .caption2)
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        ContextMenuShowInFinderButton(action: onReveal)

        if viewModel.isOrphaned {
            Button {
                Task { await onMigrate() }
            } label: {
                Label(
                    NSLocalizedString("action.migrate", value: "Migrate", comment: "Migrate orphaned skill"),
                    systemImage: "arrow.right.arrow.left"
                )
                .dsIconLabelButton()
            }

            Divider()

            ContextMenuDeleteButton {
                Task { await onUninstall() }
            }
        } else {
            if viewModel.hasWorkflow {
                Button {
                    onUnlinkWorkflow()
                } label: {
                    Label(
                        NSLocalizedString("action.unlink_workflow", value: "Unlink Workflow", comment: "Unlink from Workflow"),
                        systemImage: "link.badge.plus"
                    )
                    .dsIconLabelButton()
                }
            } else {
                Button {
                    onLinkWorkflow()
                } label: {
                    Label(
                        NSLocalizedString("action.link_workflow", comment: "Link to Workflow"),
                        systemImage: "link"
                    )
                    .dsIconLabelButton()
                }
            }

            Divider()

            ContextMenuDestructiveButton(
                title: NSLocalizedString("action.uninstall", comment: "Uninstall"),
                systemImage: "trash"
            ) {
                viewModel.showingUninstallConfirmation = true
            }
        }

        extraContextMenu()
    }
}

private struct SkillCardViewPreviewContainer: View {
    var body: some View {
        SkillCardView(
            name: "Project Toolkit",
            description: "A reusable toolkit for project setup and developer workflows.",
            version: "1.0.0",
            isOrphaned: false,
            hasWorkflow: false,
            referenceCount: 3,
            scriptCount: 2,
            searchText: "pt",
            onReveal: {},
            onUninstall: {},
            onLinkWorkflow: {},
            onUnlinkWorkflow: {},
            onMigrate: {},
            onTap: {}
        )
        .frame(width: 320)
        .padding(16)
    }
}

#Preview("Skill Card") {
    SkillCardViewPreviewContainer()
}
