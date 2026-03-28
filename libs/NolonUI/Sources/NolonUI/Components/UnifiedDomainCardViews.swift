import SwiftUI
import NolonUIFoundation

private struct ProviderReadOnlyCardTemplate<HeaderContent: View, BodyContent: View, MetaContent: View, MenuContent: View>: View {
    let minHeight: CGFloat
    let onTap: () -> Void
    let showsMeta: Bool
    @ViewBuilder let headerContent: () -> HeaderContent
    @ViewBuilder let bodyContent: () -> BodyContent
    @ViewBuilder let metaContent: () -> MetaContent
    @ViewBuilder let menuContent: () -> MenuContent

    init(
        minHeight: CGFloat = 140,
        onTap: @escaping () -> Void,
        showsMeta: Bool,
        @ViewBuilder headerContent: @escaping () -> HeaderContent,
        @ViewBuilder bodyContent: @escaping () -> BodyContent,
        @ViewBuilder metaContent: @escaping () -> MetaContent,
        @ViewBuilder menuContent: @escaping () -> MenuContent
    ) {
        self.minHeight = minHeight
        self.onTap = onTap
        self.showsMeta = showsMeta
        self.headerContent = headerContent
        self.bodyContent = bodyContent
        self.metaContent = metaContent
        self.menuContent = menuContent
    }

    var body: some View {
        UnifiedSlotCardView(
            minHeight: minHeight,
            contentPadding: DesignSystem.Metrics.spacingL,
            style: .provider(isSelected: false),
            onTap: onTap,
            showsBody: true,
            showsMeta: showsMeta,
            showsActions: false
        ) {
            headerContent()
        } bodyContent: {
            bodyContent()
        } metaContent: {
            metaContent()
        } actionContent: {
            EmptyView()
        } menuContent: {
            menuContent()
        }
    }
}

private struct ProviderActionCardTemplate<HeaderContent: View, BodyContent: View, MetaContent: View, ActionContent: View, MenuContent: View>: View {
    let minHeight: CGFloat
    let onTap: (() -> Void)?
    let showsMeta: Bool
    let showsDividerBeforeActions: Bool
    @ViewBuilder let headerContent: () -> HeaderContent
    @ViewBuilder let bodyContent: () -> BodyContent
    @ViewBuilder let metaContent: () -> MetaContent
    @ViewBuilder let actionContent: () -> ActionContent
    @ViewBuilder let menuContent: () -> MenuContent

    init(
        minHeight: CGFloat = 140,
        onTap: (() -> Void)? = nil,
        showsMeta: Bool,
        showsDividerBeforeActions: Bool = false,
        @ViewBuilder headerContent: @escaping () -> HeaderContent,
        @ViewBuilder bodyContent: @escaping () -> BodyContent,
        @ViewBuilder metaContent: @escaping () -> MetaContent,
        @ViewBuilder actionContent: @escaping () -> ActionContent,
        @ViewBuilder menuContent: @escaping () -> MenuContent
    ) {
        self.minHeight = minHeight
        self.onTap = onTap
        self.showsMeta = showsMeta
        self.showsDividerBeforeActions = showsDividerBeforeActions
        self.headerContent = headerContent
        self.bodyContent = bodyContent
        self.metaContent = metaContent
        self.actionContent = actionContent
        self.menuContent = menuContent
    }

    var body: some View {
        UnifiedSlotCardView(
            minHeight: minHeight,
            contentPadding: DesignSystem.Metrics.spacingL,
            style: .provider(isSelected: false),
            onTap: onTap,
            showsBody: true,
            showsMeta: showsMeta,
            showsDividerBeforeActions: showsDividerBeforeActions,
            showsActions: true
        ) {
            headerContent()
        } bodyContent: {
            bodyContent()
        } metaContent: {
            metaContent()
        } actionContent: {
            actionContent()
        } menuContent: {
            menuContent()
        }
    }
}


public struct AgentDocCardView<ExtraContextMenu: View>: View {
    @State private var viewModel: AgentDocCardViewViewModel
    private let onReveal: () -> Void
    private let onDelete: () async -> Void
    private let onTap: () -> Void
    private let extraContextMenu: (AgentDocInfo) -> ExtraContextMenu

    public struct Config {
        public var doc: AgentDocInfo
        public var searchText: String
        public var onReveal: () -> Void
        public var onDelete: () async -> Void
        public var onTap: () -> Void
        public var extraContextMenu: (AgentDocInfo) -> ExtraContextMenu

        public init(
            doc: AgentDocInfo,
            searchText: String,
            onReveal: @escaping () -> Void,
            onDelete: @escaping () async -> Void,
            onTap: @escaping () -> Void,
            @ViewBuilder extraContextMenu: @escaping (AgentDocInfo) -> ExtraContextMenu
        ) {
            self.doc = doc
            self.searchText = searchText
            self.onReveal = onReveal
            self.onDelete = onDelete
            self.onTap = onTap
            self.extraContextMenu = extraContextMenu
        }
    }

    public init(config: Config) {
        self._viewModel = State(
            initialValue: AgentDocCardViewViewModel(
                doc: config.doc,
                searchText: config.searchText
            )
        )
        self.onReveal = config.onReveal
        self.onDelete = config.onDelete
        self.onTap = config.onTap
        self.extraContextMenu = config.extraContextMenu
    }

    public init(
        doc: AgentDocInfo,
        searchText: String,
        onReveal: @escaping () -> Void,
        onDelete: @escaping () async -> Void,
        onTap: @escaping () -> Void,
        @ViewBuilder extraContextMenu: @escaping (AgentDocInfo) -> ExtraContextMenu
    ) {
        self.init(
            config: Config(
                doc: doc,
                searchText: searchText,
                onReveal: onReveal,
                onDelete: onDelete,
                onTap: onTap,
                extraContextMenu: extraContextMenu
            )
        )
    }

    public init(
        doc: AgentDocInfo,
        searchText: String,
        onReveal: @escaping () -> Void,
        onDelete: @escaping () async -> Void,
        onTap: @escaping () -> Void
    ) where ExtraContextMenu == EmptyView {
        self.init(
            doc: doc,
            searchText: searchText,
            onReveal: onReveal,
            onDelete: onDelete,
            onTap: onTap,
            extraContextMenu: { _ in EmptyView() }
        )
    }

    public var body: some View {
        ProviderReadOnlyCardTemplate(
            onTap: onTap,
            showsMeta: false
        ) {
            ProviderCardTitleMenuRow {
                HighlightedText(text: viewModel.title, query: viewModel.searchText)
                    .font(.headline)
                    .lineLimit(1)
            } menuContent: {
                contextMenuItems
            }
        } bodyContent: {
            VStack(alignment: .leading, spacing: DesignSystem.Metrics.spacingM) {
                ProviderCardIconCaptionRow(
                    iconName: viewModel.priorityIconName,
                    title: viewModel.priorityText
                )
                ProviderCardOptionalPreviewBlock(
                    preview: viewModel.preview,
                    searchText: viewModel.searchText,
                    minHeight: 16,
                    maxHeight: .infinity,
                    placeholderHeight: 16
                )
            }
        } metaContent: {
            EmptyView()
        } menuContent: {
            contextMenuItems
        }
        .destructiveConfirmationDialog(
            data: DestructiveConfirmationDialogData(
                title: NSLocalizedString("action.delete_confirm_title", value: "Confirm Delete", comment: "Delete confirmation title"),
                message: NSLocalizedString(
                    "agents.delete_confirm_message",
                    value: "Are you sure you want to delete this AGENTS document? This action cannot be undone.",
                    comment: "AGENTS document delete confirmation message"
                ),
                confirmTitle: NSLocalizedString("action.delete", comment: "Delete"),
                cancelTitle: NSLocalizedString("action.cancel", value: "Cancel", comment: "Cancel action")
            ),
            isPresented: $viewModel.showingDeleteConfirmation,
            onConfirm: {
                Task { await onDelete() }
            },
            onCancel: {}
        )
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        ProviderCardRevealDeleteContextMenu(
            onReveal: onReveal,
            onDeleteRequest: { viewModel.showingDeleteConfirmation = true },
            extraContent: { extraContextMenu(viewModel.doc) }
        )
    }
}




public struct RuleCardView<ExtraContextMenu: View>: View {
    @State private var viewModel: RuleCardViewViewModel
    private let onReveal: () -> Void
    private let onDelete: () async -> Void
    private let onTap: () -> Void
    private let extraContextMenu: (RuleInfo) -> ExtraContextMenu

    private let descriptionHeight: CGFloat = 44

    public struct Config {
        public var rule: RuleInfo
        public var searchText: String
        public var onReveal: () -> Void
        public var onDelete: () async -> Void
        public var onTap: () -> Void
        public var extraContextMenu: (RuleInfo) -> ExtraContextMenu

        public init(
            rule: RuleInfo,
            searchText: String,
            onReveal: @escaping () -> Void,
            onDelete: @escaping () async -> Void,
            onTap: @escaping () -> Void,
            @ViewBuilder extraContextMenu: @escaping (RuleInfo) -> ExtraContextMenu
        ) {
            self.rule = rule
            self.searchText = searchText
            self.onReveal = onReveal
            self.onDelete = onDelete
            self.onTap = onTap
            self.extraContextMenu = extraContextMenu
        }
    }

    public init(config: Config) {
        self._viewModel = State(
            initialValue: RuleCardViewViewModel(
                rule: config.rule,
                searchText: config.searchText
            )
        )
        self.onReveal = config.onReveal
        self.onDelete = config.onDelete
        self.onTap = config.onTap
        self.extraContextMenu = config.extraContextMenu
    }

    public init(
        rule: RuleInfo,
        searchText: String,
        onReveal: @escaping () -> Void,
        onDelete: @escaping () async -> Void,
        onTap: @escaping () -> Void,
        @ViewBuilder extraContextMenu: @escaping (RuleInfo) -> ExtraContextMenu
    ) {
        self.init(
            config: Config(
                rule: rule,
                searchText: searchText,
                onReveal: onReveal,
                onDelete: onDelete,
                onTap: onTap,
                extraContextMenu: extraContextMenu
            )
        )
    }

    public init(
        rule: RuleInfo,
        searchText: String,
        onReveal: @escaping () -> Void,
        onDelete: @escaping () async -> Void,
        onTap: @escaping () -> Void
    ) where ExtraContextMenu == EmptyView {
        self.init(
            rule: rule,
            searchText: searchText,
            onReveal: onReveal,
            onDelete: onDelete,
            onTap: onTap,
            extraContextMenu: { _ in EmptyView() }
        )
    }

    public var body: some View {
        ProviderReadOnlyCardTemplate(
            onTap: onTap,
            showsMeta: true
        ) {
            ProviderCardTitleMenuRow {
                HighlightedText(text: viewModel.title, query: viewModel.searchText)
                    .font(.headline)
                    .lineLimit(1)
            } menuContent: {
                contextMenuItems
            }
        } bodyContent: {
            ProviderCardOptionalPreviewBlock(
                preview: viewModel.preview,
                searchText: viewModel.searchText,
                minHeight: descriptionHeight,
                maxHeight: descriptionHeight
            )
        } metaContent: {
            HStack(spacing: DesignSystem.Metrics.spacingS) {
                Image(systemName: "doc.text")
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                HighlightedText(text: viewModel.relativePath, query: viewModel.searchText)
                    .font(.caption2.monospaced())
                    .dsSecondaryText(font: .caption2)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
        } menuContent: {
            contextMenuItems
        }
        .destructiveConfirmationDialog(
            data: DestructiveConfirmationDialogData(
                title: NSLocalizedString("action.delete_confirm_title", value: "Confirm Delete", comment: "Delete confirmation title"),
                message: NSLocalizedString(
                    "rules.delete_confirm_message",
                    value: "Are you sure you want to delete this rule? This action cannot be undone.",
                    comment: "Rule delete confirmation message"
                ),
                confirmTitle: NSLocalizedString("action.delete", comment: "Delete"),
                cancelTitle: NSLocalizedString("action.cancel", value: "Cancel", comment: "Cancel action")
            ),
            isPresented: $viewModel.showingDeleteConfirmation,
            onConfirm: {
                Task { await onDelete() }
            },
            onCancel: {}
        )
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        ProviderCardRevealDeleteContextMenu(
            onReveal: onReveal,
            onDeleteRequest: { viewModel.showingDeleteConfirmation = true },
            extraContent: { extraContextMenu(viewModel.rule) }
        )
    }
}




public struct WorkflowCardView<ExtraContextMenu: View>: View {
    @State private var viewModel: WorkflowCardViewViewModel
    private let onReveal: () -> Void
    private let onDelete: () async -> Void
    private let onTap: () -> Void
    private let extraContextMenu: (WorkflowInfo) -> ExtraContextMenu

    private let descriptionHeight: CGFloat = 44

    public struct Config {
        public var workflow: WorkflowInfo
        public var searchText: String
        public var onReveal: () -> Void
        public var onDelete: () async -> Void
        public var onTap: () -> Void
        public var extraContextMenu: (WorkflowInfo) -> ExtraContextMenu

        public init(
            workflow: WorkflowInfo,
            searchText: String,
            onReveal: @escaping () -> Void,
            onDelete: @escaping () async -> Void,
            onTap: @escaping () -> Void,
            @ViewBuilder extraContextMenu: @escaping (WorkflowInfo) -> ExtraContextMenu
        ) {
            self.workflow = workflow
            self.searchText = searchText
            self.onReveal = onReveal
            self.onDelete = onDelete
            self.onTap = onTap
            self.extraContextMenu = extraContextMenu
        }
    }

    public init(config: Config) {
        self._viewModel = State(
            initialValue: WorkflowCardViewViewModel(
                workflow: config.workflow,
                searchText: config.searchText
            )
        )
        self.onReveal = config.onReveal
        self.onDelete = config.onDelete
        self.onTap = config.onTap
        self.extraContextMenu = config.extraContextMenu
    }

    public init(
        workflow: WorkflowInfo,
        searchText: String,
        onReveal: @escaping () -> Void,
        onDelete: @escaping () async -> Void,
        onTap: @escaping () -> Void,
        @ViewBuilder extraContextMenu: @escaping (WorkflowInfo) -> ExtraContextMenu
    ) {
        self.init(
            config: Config(
                workflow: workflow,
                searchText: searchText,
                onReveal: onReveal,
                onDelete: onDelete,
                onTap: onTap,
                extraContextMenu: extraContextMenu
            )
        )
    }

    public init(
        workflow: WorkflowInfo,
        searchText: String,
        onReveal: @escaping () -> Void,
        onDelete: @escaping () async -> Void,
        onTap: @escaping () -> Void
    ) where ExtraContextMenu == EmptyView {
        self.init(
            workflow: workflow,
            searchText: searchText,
            onReveal: onReveal,
            onDelete: onDelete,
            onTap: onTap,
            extraContextMenu: { _ in EmptyView() }
        )
    }

    public var body: some View {
        ProviderReadOnlyCardTemplate(
            onTap: onTap,
            showsMeta: true
        ) {
            ProviderCardTitleMenuRow {
                HStack(spacing: DesignSystem.Metrics.spacingS) {
                    HighlightedText(text: viewModel.title, query: viewModel.searchText)
                        .font(.headline)
                        .lineLimit(1)
                    sourceBadge
                }
            } menuContent: {
                contextMenuItems
            }
        } bodyContent: {
            ProviderCardDescriptionBlock(
                text: viewModel.descriptionText,
                searchText: viewModel.searchText,
                minHeight: descriptionHeight,
                maxHeight: descriptionHeight
            )
        } metaContent: {
            HStack {
                Label("Workflow", systemImage: "arrow.triangle.branch")
                    .dsIconLabelText(foreground: DesignSystem.Colors.Text.secondary, font: .caption2)
                Spacer()
            }
        } menuContent: {
            contextMenuItems
        }
        .destructiveConfirmationDialog(
            data: DestructiveConfirmationDialogData(
                title: NSLocalizedString("action.delete_confirm_title", value: "Confirm Delete", comment: "Delete confirmation title"),
                message: NSLocalizedString(
                    "action.delete_confirm_message",
                    value: "Are you sure you want to delete this workflow? This action cannot be undone.",
                    comment: "Delete confirmation message"
                ),
                confirmTitle: NSLocalizedString("action.delete", comment: "Delete"),
                cancelTitle: NSLocalizedString("action.cancel", value: "Cancel", comment: "Cancel action")
            ),
            isPresented: $viewModel.showingDeleteConfirmation,
            onConfirm: {
                Task { await onDelete() }
            },
            onCancel: {}
        )
    }

    @ViewBuilder
    private var sourceBadge: some View {
        Text(viewModel.sourceTitle)
            .font(DesignSystem.Typography.caption2)
            .fontWeight(.bold)
            .dsBadge(
                foreground: viewModel.sourceColor,
                background: viewModel.sourceColor.opacity(0.15),
                horizontalPadding: 6,
                verticalPadding: 2
            )
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        ProviderCardRevealDeleteContextMenu(
            onReveal: onReveal,
            onDeleteRequest: { viewModel.showingDeleteConfirmation = true },
            extraContent: { extraContextMenu(viewModel.workflow) }
        )
    }
}




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

    public struct Config {
        public var name: String
        public var description: String
        public var version: String
        public var isOrphaned: Bool
        public var hasWorkflow: Bool
        public var referenceCount: Int
        public var scriptCount: Int
        public var searchText: String
        public var onReveal: () -> Void
        public var onUninstall: () async -> Void
        public var onLinkWorkflow: () -> Void
        public var onUnlinkWorkflow: () -> Void
        public var onMigrate: () async -> Void
        public var onTap: () -> Void
        public var extraContextMenu: () -> ExtraContextMenu

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
            self.name = name
            self.description = description
            self.version = version
            self.isOrphaned = isOrphaned
            self.hasWorkflow = hasWorkflow
            self.referenceCount = referenceCount
            self.scriptCount = scriptCount
            self.searchText = searchText
            self.onReveal = onReveal
            self.onUninstall = onUninstall
            self.onLinkWorkflow = onLinkWorkflow
            self.onUnlinkWorkflow = onUnlinkWorkflow
            self.onMigrate = onMigrate
            self.onTap = onTap
            self.extraContextMenu = extraContextMenu
        }
    }

    public init(config: Config) {
        self._viewModel = State(
            initialValue: SkillCardViewViewModel(
                name: config.name,
                descriptionText: config.description,
                version: config.version,
                isOrphaned: config.isOrphaned,
                hasWorkflow: config.hasWorkflow,
                referenceCount: config.referenceCount,
                scriptCount: config.scriptCount,
                searchText: config.searchText
            )
        )
        self.onReveal = config.onReveal
        self.onUninstall = config.onUninstall
        self.onLinkWorkflow = config.onLinkWorkflow
        self.onUnlinkWorkflow = config.onUnlinkWorkflow
        self.onMigrate = config.onMigrate
        self.onTap = config.onTap
        self.extraContextMenu = config.extraContextMenu
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
        onTap: @escaping () -> Void,
        @ViewBuilder extraContextMenu: @escaping () -> ExtraContextMenu
    ) {
        self.init(
            config: Config(
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
                extraContextMenu: extraContextMenu
            )
        )
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
        ProviderActionCardTemplate(
            minHeight: 140,
            onTap: onTap,
            showsMeta: false
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
            }
        } metaContent: {
            EmptyView()
        } actionContent: {
            actionRow
        } menuContent: {
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




public enum McpServerCardCacheState: Sendable, Hashable {
    case notMigrated
    case migratedUpToDate
    case migratedNeedsUpdate
}

public enum McpServerMaintenanceAction: Sendable, Hashable {
    case none
    case migrate
    case update
}

public enum McpServerPrimaryAction: Sendable, Hashable {
    case none
    case migrate
    case update
}

public struct McpServerCardView<TitleContent: View, ExtraContextMenu: View>: View {
    @State private var viewModel = McpServerCardViewViewModel()
    private let commandText: String?
    private let searchText: String
    private let hasWorkflow: Bool
    private let isEnabled: Bool
    private let cacheState: McpServerCardCacheState
    private let onLinkWorkflow: () -> Void
    private let onUnlinkWorkflow: () -> Void
    private let onSetEnabled: (Bool) -> Void
    private let onMigrateToNolon: () -> Void
    private let onUpdateNolonCache: () -> Void
    private let onEdit: () -> Void
    private let onDelete: () -> Void
    private let titleContent: () -> TitleContent
    private let extraContextMenu: () -> ExtraContextMenu

    public struct Config {
        public var commandText: String?
        public var searchText: String
        public var hasWorkflow: Bool
        public var isEnabled: Bool
        public var cacheState: McpServerCardCacheState
        public var onLinkWorkflow: () -> Void
        public var onUnlinkWorkflow: () -> Void
        public var onSetEnabled: (Bool) -> Void
        public var onMigrateToNolon: () -> Void
        public var onUpdateNolonCache: () -> Void
        public var onEdit: () -> Void
        public var onDelete: () -> Void
        public var titleContent: () -> TitleContent
        public var extraContextMenu: () -> ExtraContextMenu

        public init(
            commandText: String?,
            searchText: String,
            hasWorkflow: Bool,
            isEnabled: Bool,
            cacheState: McpServerCardCacheState,
            onLinkWorkflow: @escaping () -> Void,
            onUnlinkWorkflow: @escaping () -> Void,
            onSetEnabled: @escaping (Bool) -> Void,
            onMigrateToNolon: @escaping () -> Void,
            onUpdateNolonCache: @escaping () -> Void,
            onEdit: @escaping () -> Void,
            onDelete: @escaping () -> Void,
            @ViewBuilder titleContent: @escaping () -> TitleContent,
            @ViewBuilder extraContextMenu: @escaping () -> ExtraContextMenu
        ) {
            self.commandText = commandText
            self.searchText = searchText
            self.hasWorkflow = hasWorkflow
            self.isEnabled = isEnabled
            self.cacheState = cacheState
            self.onLinkWorkflow = onLinkWorkflow
            self.onUnlinkWorkflow = onUnlinkWorkflow
            self.onSetEnabled = onSetEnabled
            self.onMigrateToNolon = onMigrateToNolon
            self.onUpdateNolonCache = onUpdateNolonCache
            self.onEdit = onEdit
            self.onDelete = onDelete
            self.titleContent = titleContent
            self.extraContextMenu = extraContextMenu
        }
    }

    public init(config: Config) {
        self.commandText = config.commandText
        self.searchText = config.searchText
        self.hasWorkflow = config.hasWorkflow
        self.isEnabled = config.isEnabled
        self.cacheState = config.cacheState
        self.onLinkWorkflow = config.onLinkWorkflow
        self.onUnlinkWorkflow = config.onUnlinkWorkflow
        self.onSetEnabled = config.onSetEnabled
        self.onMigrateToNolon = config.onMigrateToNolon
        self.onUpdateNolonCache = config.onUpdateNolonCache
        self.onEdit = config.onEdit
        self.onDelete = config.onDelete
        self.titleContent = config.titleContent
        self.extraContextMenu = config.extraContextMenu
    }

    public init(
        commandText: String?,
        searchText: String,
        hasWorkflow: Bool,
        isEnabled: Bool,
        cacheState: McpServerCardCacheState,
        onLinkWorkflow: @escaping () -> Void,
        onUnlinkWorkflow: @escaping () -> Void,
        onSetEnabled: @escaping (Bool) -> Void,
        onMigrateToNolon: @escaping () -> Void,
        onUpdateNolonCache: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        @ViewBuilder titleContent: @escaping () -> TitleContent,
        @ViewBuilder extraContextMenu: @escaping () -> ExtraContextMenu
    ) {
        self.init(
            config: Config(
                commandText: commandText,
                searchText: searchText,
                hasWorkflow: hasWorkflow,
                isEnabled: isEnabled,
                cacheState: cacheState,
                onLinkWorkflow: onLinkWorkflow,
                onUnlinkWorkflow: onUnlinkWorkflow,
                onSetEnabled: onSetEnabled,
                onMigrateToNolon: onMigrateToNolon,
                onUpdateNolonCache: onUpdateNolonCache,
                onEdit: onEdit,
                onDelete: onDelete,
                titleContent: titleContent,
                extraContextMenu: extraContextMenu
            )
        )
    }

    public var body: some View {
        ProviderActionCardTemplate(
            minHeight: 156,
            onTap: nil,
            showsMeta: true,
            showsDividerBeforeActions: true,
        ) {
            headerRow
        } bodyContent: {
            commandRow
        } metaContent: {
            statusRow
        } actionContent: {
            actionRow
        } menuContent: {
            contextMenuItems
        }
        .destructiveConfirmationDialog(
            data: DestructiveConfirmationDialogData(
                title: NSLocalizedString("action.delete_confirm_title_mcp", value: "Confirm Delete MCP", comment: "MCP Delete confirmation title"),
                message: NSLocalizedString(
                    "action.delete_confirm_message_mcp",
                    value: "Are you sure you want to delete this MCP server? This will remove its configuration.",
                    comment: "MCP Delete confirmation message"
                ),
                confirmTitle: NSLocalizedString("action.delete", comment: "Delete"),
                cancelTitle: NSLocalizedString("action.cancel", value: "Cancel", comment: "Cancel action")
            ),
            isPresented: $viewModel.showingDeleteConfirmation,
            onConfirm: {
                onDelete()
            },
            onCancel: {}
        )
    }

    nonisolated static func resolveMaintenanceAction(for cacheState: McpServerCardCacheState) -> McpServerMaintenanceAction {
        switch cacheState {
        case .notMigrated:
            return .migrate
        case .migratedNeedsUpdate:
            return .update
        case .migratedUpToDate:
            return .none
        }
    }

    nonisolated static func isMissingCommand(_ commandText: String?) -> Bool {
        guard let commandText else {
            return true
        }
        return commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    nonisolated static func resolvePrimaryAction(
        cacheState: McpServerCardCacheState
    ) -> McpServerPrimaryAction {
        switch cacheState {
        case .notMigrated:
            return .migrate
        case .migratedNeedsUpdate:
            return .update
        case .migratedUpToDate:
            return .none
        }
    }

    private var headerRow: some View {
        ProviderCardTitleMenuRow {
            titleContent()
        } menuContent: {
            contextMenuItems
        }
    }

    private var commandRow: some View {
        HStack(alignment: .top, spacing: DesignSystem.Metrics.spacingS) {
            Image(systemName: "terminal")
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .padding(.top, 2)

            if Self.isMissingCommand(commandText) {
                Text(NSLocalizedString("mcp.no_command", value: "No command specified", comment: "Placeholder when MCP command is missing"))
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
                    .italic()
            } else {
                Text(commandText ?? "")
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .dsSecondaryText(font: .caption)
                    .lineLimit(4)
                    .textSelection(.enabled)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, DesignSystem.Metrics.spacingM)
        .padding(.vertical, DesignSystem.Metrics.spacingS + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.Component.controlFillSubtle)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS))
    }

    private var statusRow: some View {
        HStack(spacing: DesignSystem.Metrics.spacingS) {
            if let cacheStatusLabel {
                Label(cacheStatusLabel, systemImage: cacheStatusIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var actionRow: some View {
        HStack(spacing: DesignSystem.Metrics.spacingS) {
            if primaryAction != .none {
                Button {
                    switch primaryAction {
                    case .migrate:
                        onMigrateToNolon()
                    case .update:
                        onUpdateNolonCache()
                    case .none:
                        break
                    }
                } label: {
                    Image(systemName: primaryActionIcon)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help(primaryActionTitle)
                .accessibilityLabel(primaryActionTitle)
            }

            workflowActionButton

            Spacer(minLength: 0)

            Toggle(
                isOn: Binding(
                    get: { isEnabled },
                    set: { onSetEnabled($0) }
                )
            ) {
                Text(
                    isEnabled
                        ? NSLocalizedString("mcp.status.enabled", value: "Enabled", comment: "MCP runtime enabled")
                        : NSLocalizedString("mcp.status.disabled", value: "Disabled", comment: "MCP runtime disabled")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .accessibilityLabel(
                isEnabled
                    ? NSLocalizedString("mcp.action.disable", value: "Disable MCP", comment: "Disable MCP")
                    : NSLocalizedString("mcp.action.enable", value: "Enable MCP", comment: "Enable MCP")
            )
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var workflowActionButton: some View {
        let title = hasWorkflow
            ? NSLocalizedString("action.unlink_workflow", value: "Unlink Workflow", comment: "Unlink from Workflow")
            : NSLocalizedString("action.link_workflow", value: "Link Workflow", comment: "Link to Workflow")
        let icon = hasWorkflow ? "arrow.triangle.branch" : "plus.circle"

        if primaryAction == .none {
            Button {
                hasWorkflow ? onUnlinkWorkflow() : onLinkWorkflow()
            } label: {
                Image(systemName: icon)
                    .frame(minWidth: 16, minHeight: 16)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .help(title)
            .accessibilityLabel(title)
        } else {
            Button {
                hasWorkflow ? onUnlinkWorkflow() : onLinkWorkflow()
            } label: {
                Image(systemName: icon)
                    .frame(minWidth: 16, minHeight: 16)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(title)
            .accessibilityLabel(title)
        }
    }

    private var primaryAction: McpServerPrimaryAction {
        Self.resolvePrimaryAction(cacheState: cacheState)
    }

    private var primaryActionTitle: String {
        switch primaryAction {
        case .migrate:
            return NSLocalizedString("action.migrate", value: "Migrate", comment: "Migrate")
        case .update:
            return NSLocalizedString("action.update", value: "Update", comment: "Update")
        case .none:
            return ""
        }
    }

    private var primaryActionIcon: String {
        switch primaryAction {
        case .migrate:
            return "tray.and.arrow.down"
        case .update:
            return "arrow.triangle.2.circlepath"
        case .none:
            return "circle"
        }
    }

    private var cacheStatusLabel: String? {
        switch cacheState {
        case .notMigrated:
            return NSLocalizedString("mcp.cache.not_migrated", value: "Not migrated", comment: "MCP not migrated")
        case .migratedNeedsUpdate:
            return NSLocalizedString("mcp.cache.update_available", value: "Update available", comment: "MCP cache update available")
        case .migratedUpToDate:
            return nil
        }
    }

    private var cacheStatusIcon: String {
        switch cacheState {
        case .notMigrated:
            return "tray.and.arrow.down"
        case .migratedNeedsUpdate:
            return "arrow.triangle.2.circlepath"
        case .migratedUpToDate:
            return "checkmark.circle"
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        if cacheState == .notMigrated {
            Button(action: onMigrateToNolon) {
                Label(
                    NSLocalizedString("action.migrate", value: "Migrate", comment: "Migrate"),
                    systemImage: "tray.and.arrow.down"
                )
            }
            Divider()
        } else if cacheState == .migratedNeedsUpdate {
            Button(action: onUpdateNolonCache) {
                Label(
                    NSLocalizedString("action.update", value: "Update", comment: "Update"),
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }
            Divider()
        }

        Button {
            onSetEnabled(!isEnabled)
        } label: {
            Label(
                isEnabled
                    ? NSLocalizedString("mcp.action.disable", value: "Disable", comment: "Disable MCP")
                    : NSLocalizedString("mcp.action.enable", value: "Enable", comment: "Enable MCP"),
                systemImage: isEnabled ? "pause.circle" : "play.circle"
            )
        }

        Divider()

        if hasWorkflow {
            Button {
                onUnlinkWorkflow()
            } label: {
                Label(
                    NSLocalizedString("action.unlink_workflow", value: "Unlink Workflow", comment: "Unlink from Workflow"),
                    systemImage: "link.slash"
                )
            }
        } else {
            Button {
                onLinkWorkflow()
            } label: {
                Label(
                    NSLocalizedString("action.link_workflow", comment: "Link to Workflow"),
                    systemImage: "link"
                )
            }
        }

        Divider()

        Button(action: onEdit) {
            Label(NSLocalizedString("action.edit", value: "Edit", comment: "Edit action"), systemImage: "pencil")
                .dsIconLabelButton()
        }

        ContextMenuDeleteButton {
            viewModel.showingDeleteConfirmation = true
        }

        extraContextMenu()
    }

}






private enum ResourceCardBadgeStyle {
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

private struct ResourceInstallCardTemplate<ExtraAction: View, ExtraContextMenu: View>: View {
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
