import NolonUIFoundation
import SwiftUI
import WebKit

// MARK: - ProviderDetailCommonViews

public struct ProviderDetailPlaceholderView: View {
    public enum Preset {
        case noProvider
        case noTab
    }

    let title: String
    let systemImage: String

    public struct Config {
        public var title: String
        public var systemImage: String

        public init(title: String, systemImage: String) {
            self.title = title
            self.systemImage = systemImage
        }
    }

    public init(config: Config) {
        self.title = config.title
        self.systemImage = config.systemImage
    }

    public init(title: String, systemImage: String) {
        self.init(config: Config(title: title, systemImage: systemImage))
    }

    public init(preset: Preset) {
        switch preset {
        case .noProvider:
            self.title = NSLocalizedString("detail.no_provider", comment: "Select a Provider")
            self.systemImage = "sidebar.left"
        case .noTab:
            self.title = NSLocalizedString("detail.select_tab", comment: "Select a Tab")
            self.systemImage = "list.bullet"
        }
    }

    public var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
                    .dsEmptyStateTitle()
            } icon: {
                Image(systemName: systemImage)
                    .dsEmptyStateIcon()
            }
        }
    }
}

public struct ProviderWarningCardView: View {
    let message: String

    public struct Config {
        public var message: String

        public init(message: String) {
            self.message = message
        }
    }

    public init(config: Config) {
        self.message = config.message
    }

    public init(message: String) {
        self.init(config: Config(message: message))
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignSystem.Colors.Status.warning)
            Text(message)
                .font(.callout)
                .dsSecondaryText(font: .callout)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .dsCard(
            background: DesignSystem.Colors.Status.warning.opacity(0.08),
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Status.warning.opacity(0.25),
            borderWidth: 1
        )
    }
}

public struct ProviderCodexXcodeNoticeCardView: View {
    let title: String
    let description: String
    let closeAction: () -> Void

    public struct Config {
        public var title: String
        public var description: String
        public var closeAction: () -> Void

        public init(
            title: String,
            description: String,
            closeAction: @escaping () -> Void
        ) {
            self.title = title
            self.description = description
            self.closeAction = closeAction
        }
    }

    public init(config: Config) {
        self.title = config.title
        self.description = config.description
        self.closeAction = config.closeAction
    }

    public init(
        title: String,
        description: String,
        closeAction: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                title: title,
                description: description,
                closeAction: closeAction
            )
        )
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hammer.fill")
                .font(.title3)
                .foregroundStyle(DesignSystem.Colors.Status.info)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                Text(description)
                    .font(.callout)
                    .dsSecondaryText(font: .callout)
            }

            Spacer(minLength: 0)
            Button {
                closeAction()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    .padding(6)
                    .background(DesignSystem.Colors.Component.controlFillSubtle, in: .circle)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.4)
        )
    }
}

public struct FloatingAccentActionButton: View {
    let systemImage: String
    let iconSize: CGFloat
    let action: () -> Void

    public struct Config {
        public var systemImage: String
        public var iconSize: CGFloat
        public var action: () -> Void

        public init(
            systemImage: String = "plus",
            iconSize: CGFloat = 24,
            action: @escaping () -> Void
        ) {
            self.systemImage = systemImage
            self.iconSize = iconSize
            self.action = action
        }
    }

    public init(config: Config) {
        self.systemImage = config.systemImage
        self.iconSize = config.iconSize
        self.action = config.action
    }

    public init(
        systemImage: String = "plus",
        iconSize: CGFloat = 24,
        action: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                systemImage: systemImage,
                iconSize: iconSize,
                action: action
            )
        )
    }

    public var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primary)
                    .frame(width: 56, height: 56)
                    .shadow(color: DesignSystem.Colors.primary.opacity(0.4), radius: 10, x: 0, y: 5)

                Image(systemName: systemImage)
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.Text.onAccent)
            }
        }
        .dsLinkButton()
    }
}

public struct ProviderResourceHealthSummaryCardView: View {
    let data: ProviderResourceHealthSummaryData
    let onTapOrphanedSkills: () -> Void

    public struct Config {
        public var data: ProviderResourceHealthSummaryData
        public var onTapOrphanedSkills: () -> Void

        public init(
            data: ProviderResourceHealthSummaryData,
            onTapOrphanedSkills: @escaping () -> Void
        ) {
            self.data = data
            self.onTapOrphanedSkills = onTapOrphanedSkills
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.onTapOrphanedSkills = config.onTapOrphanedSkills
    }

    public init(
        data: ProviderResourceHealthSummaryData,
        onTapOrphanedSkills: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                data: data,
                onTapOrphanedSkills: onTapOrphanedSkills
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DesignSystem.Colors.Status.warning)
                Text(data.warningTitle)
                    .font(.callout.weight(.semibold))
            }

            HStack(spacing: 12) {
                if let orphanedText = data.orphanedSkillsText {
                    Button {
                        onTapOrphanedSkills()
                    } label: {
                        Text(orphanedText)
                            .font(.caption)
                            .dsBadge(
                                foreground: DesignSystem.Colors.Status.warning,
                                background: DesignSystem.Colors.Status.warning.opacity(0.14)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(data.orphanedSkillsHelp ?? "")
                }

                if let brokenText = data.brokenSkillsText {
                    Text(brokenText)
                        .font(.caption)
                        .dsBadge(
                            foreground: DesignSystem.Colors.Status.error,
                            background: DesignSystem.Colors.Status.error.opacity(0.14)
                        )
                }

                if let unknownText = data.unknownWorkflowsText {
                    Text(unknownText)
                        .font(.caption)
                        .dsBadge(
                            foreground: DesignSystem.Colors.Text.secondary,
                            background: DesignSystem.Colors.Component.controlFillSubtle
                        )
                }

                if let mcpUpdateText = data.mcpUpdateText {
                    Text(mcpUpdateText)
                        .font(.caption)
                        .dsBadge(
                            foreground: DesignSystem.Colors.secondary,
                            background: DesignSystem.Colors.secondary.opacity(0.14)
                        )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .dsCard(
            background: DesignSystem.Colors.Status.warning.opacity(0.08),
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Status.warning.opacity(0.25),
            borderWidth: 1
        )
    }
}

public struct ProviderCodexLinkedHintCardView: View {
    let data: ProviderCodexLinkedHintData
    let onAction: () -> Void

    public struct Config {
        public var data: ProviderCodexLinkedHintData
        public var onAction: () -> Void

        public init(
            data: ProviderCodexLinkedHintData,
            onAction: @escaping () -> Void
        ) {
            self.data = data
            self.onAction = onAction
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.onAction = config.onAction
    }

    public init(
        data: ProviderCodexLinkedHintData,
        onAction: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                data: data,
                onAction: onAction
            )
        )
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(data.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)

                Text(data.pathText)
                    .font(.caption.monospaced())
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }

            Spacer(minLength: 0)
            Button(data.actionTitle) {
                onAction()
            }
            .dsPrimaryButton()
        }
        .padding(12)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(0.35)
        )
    }
}

public struct ProviderCodexTopHintsView: View {
    let noticeData: ProviderCodexXcodeNoticeData?
    let linkedHintData: ProviderCodexLinkedHintData?
    let onDismissNotice: (() -> Void)?
    let onTapLinkedHint: (() -> Void)?

    public struct Config {
        public var noticeData: ProviderCodexXcodeNoticeData?
        public var linkedHintData: ProviderCodexLinkedHintData?
        public var onDismissNotice: (() -> Void)?
        public var onTapLinkedHint: (() -> Void)?

        public init(
            noticeData: ProviderCodexXcodeNoticeData?,
            linkedHintData: ProviderCodexLinkedHintData?,
            onDismissNotice: (() -> Void)? = nil,
            onTapLinkedHint: (() -> Void)? = nil
        ) {
            self.noticeData = noticeData
            self.linkedHintData = linkedHintData
            self.onDismissNotice = onDismissNotice
            self.onTapLinkedHint = onTapLinkedHint
        }
    }

    public init(config: Config) {
        self.noticeData = config.noticeData
        self.linkedHintData = config.linkedHintData
        self.onDismissNotice = config.onDismissNotice
        self.onTapLinkedHint = config.onTapLinkedHint
    }

    public init(
        noticeData: ProviderCodexXcodeNoticeData?,
        linkedHintData: ProviderCodexLinkedHintData?,
        onDismissNotice: (() -> Void)? = nil,
        onTapLinkedHint: (() -> Void)? = nil
    ) {
        self.init(
            config: Config(
                noticeData: noticeData,
                linkedHintData: linkedHintData,
                onDismissNotice: onDismissNotice,
                onTapLinkedHint: onTapLinkedHint
            )
        )
    }

    public var body: some View {
        if let noticeData, let onDismissNotice {
            ProviderCodexXcodeNoticeCardView(
                title: noticeData.title,
                description: noticeData.description,
                closeAction: onDismissNotice
            )
        }

        if let linkedHintData, let onTapLinkedHint {
            ProviderCodexLinkedHintCardView(
                data: linkedHintData,
                onAction: onTapLinkedHint
            )
        }
    }
}

public struct ProviderTabSectionView<Content: View>: View {
    let warningMessage: String?
    let content: () -> Content

    public struct Config {
        public var warningMessage: String?

        public init(warningMessage: String?) {
            self.warningMessage = warningMessage
        }
    }

    public init(
        config: Config,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.warningMessage = config.warningMessage
        self.content = content
    }

    public init(
        warningMessage: String?,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(warningMessage: warningMessage),
            content: content
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let warningMessage, !warningMessage.isEmpty {
                ProviderWarningCardView(message: warningMessage)
            }
            content()
        }
    }
}

// MARK: - ProviderDetailGridScaffoldView

public struct ProviderDetailGridScaffoldView<Content: View, FloatingButton: View>: View {
    let showSearch: Bool
    let searchPlaceholder: String
    @Binding var searchText: String
    let showFloatingButton: Bool
    let searchTrailing: (() -> AnyView)?
    let content: (ScrollViewProxy) -> Content
    let floatingButton: () -> FloatingButton

    public struct Config {
        public var showSearch: Bool
        public var searchPlaceholder: String
        public var showFloatingButton: Bool

        public init(
            showSearch: Bool,
            searchPlaceholder: String = NSLocalizedString("search.placeholder", value: "Search", comment: "Search placeholder"),
            showFloatingButton: Bool
        ) {
            self.showSearch = showSearch
            self.searchPlaceholder = searchPlaceholder
            self.showFloatingButton = showFloatingButton
        }
    }

    public init(
        searchText: Binding<String>,
        config: Config,
        searchTrailing: (() -> AnyView)? = nil,
        @ViewBuilder content: @escaping (ScrollViewProxy) -> Content,
        @ViewBuilder floatingButton: @escaping () -> FloatingButton
    ) {
        self.showSearch = config.showSearch
        self.searchPlaceholder = config.searchPlaceholder
        self._searchText = searchText
        self.showFloatingButton = config.showFloatingButton
        self.searchTrailing = searchTrailing
        self.content = content
        self.floatingButton = floatingButton
    }

    public init(
        showSearch: Bool,
        searchPlaceholder: String = NSLocalizedString("search.placeholder", value: "Search", comment: "Search placeholder"),
        searchText: Binding<String>,
        showFloatingButton: Bool,
        searchTrailing: (() -> AnyView)? = nil,
        @ViewBuilder content: @escaping (ScrollViewProxy) -> Content,
        @ViewBuilder floatingButton: @escaping () -> FloatingButton
    ) {
        self.init(
            searchText: searchText,
            config: Config(
                showSearch: showSearch,
                searchPlaceholder: searchPlaceholder,
                showFloatingButton: showFloatingButton
            ),
            searchTrailing: searchTrailing,
            content: content,
            floatingButton: floatingButton
        )
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if showSearch {
                                HStack(spacing: 12) {
                                    SearchField(
                                        config: .init(
                                            placeholder: searchPlaceholder,
                                            text: $searchText
                                        )
                                    )
                                    if let searchTrailing {
                                        searchTrailing()
                                    }
                                }
                            }
                            content(scrollProxy)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .padding()
                }

                if showFloatingButton {
                    floatingButton()
                }
            }
        }
    }
}

public struct ProviderSkillsLinkToolbarMenuButton: View {
    @Binding var isEnabled: Bool
    let isApplying: Bool
    let providerPath: String
    let onShowInFinder: () -> Void
    let onToggleRequested: (Bool) -> Void

    public init(
        isEnabled: Binding<Bool>,
        isApplying: Bool,
        providerPath: String,
        onShowInFinder: @escaping () -> Void,
        onToggleRequested: @escaping (Bool) -> Void
    ) {
        self._isEnabled = isEnabled
        self.isApplying = isApplying
        self.providerPath = providerPath
        self.onShowInFinder = onShowInFinder
        self.onToggleRequested = onToggleRequested
    }

    public var body: some View {
        EllipsisMenuButton {
            Button(action: onShowInFinder) {
                Label(
                    NSLocalizedString("action.show_in_finder", comment: "Show in Finder"),
                    systemImage: "folder"
                )
                .dsIconLabelButton()
            }

            Divider()

            Toggle(
                NSLocalizedString(
                    "provider.skills_link.toggle",
                    value: "Link this provider's skills folder to ~/.nolon/skills",
                    comment: "Skills link toggle title"
                ),
                isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in onToggleRequested(newValue) }
                )
            )
            .disabled(isApplying)

            Divider()

            Text(providerPath)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .help(
            NSLocalizedString(
                "provider.skills_link.menu.help",
                value: "Skills link settings",
                comment: "Skills link menu button help text"
            )
        )
    }
}

public struct ProviderMCPLinkToolbarMenuButton: View {
    @Binding var isEnabled: Bool
    let providerPath: String
    let onShowInFinder: () -> Void
    let onToggleRequested: (Bool) -> Void

    public init(
        isEnabled: Binding<Bool>,
        providerPath: String,
        onShowInFinder: @escaping () -> Void,
        onToggleRequested: @escaping (Bool) -> Void
    ) {
        self._isEnabled = isEnabled
        self.providerPath = providerPath
        self.onShowInFinder = onShowInFinder
        self.onToggleRequested = onToggleRequested
    }

    public var body: some View {
        EllipsisMenuButton {
            Button(action: onShowInFinder) {
                Label(
                    NSLocalizedString("action.show_in_finder", comment: "Show in Finder"),
                    systemImage: "folder"
                )
                .dsIconLabelButton()
            }

            Divider()

            Toggle(
                NSLocalizedString(
                    "provider.mcp_link.toggle",
                    value: "Link this provider's MCP to ~/.nolon/mcps",
                    comment: "MCP link toggle title"
                ),
                isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in onToggleRequested(newValue) }
                )
            )

            Divider()

            Text(providerPath)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .help(
            NSLocalizedString(
                "provider.mcp_link.menu.help",
                value: "MCP link settings",
                comment: "MCP link menu button help text"
            )
        )
    }
}

public struct ProviderAgentsLinkToolbarMenuButton: View {
    @Binding var isEnabled: Bool
    let providerPath: String
    let onShowInFinder: () -> Void
    let onToggleRequested: (Bool) -> Void

    public init(
        isEnabled: Binding<Bool>,
        providerPath: String,
        onShowInFinder: @escaping () -> Void,
        onToggleRequested: @escaping (Bool) -> Void
    ) {
        self._isEnabled = isEnabled
        self.providerPath = providerPath
        self.onShowInFinder = onShowInFinder
        self.onToggleRequested = onToggleRequested
    }

    public var body: some View {
        EllipsisMenuButton {
            Button(action: onShowInFinder) {
                Label(
                    NSLocalizedString("action.show_in_finder", comment: "Show in Finder"),
                    systemImage: "folder"
                )
                .dsIconLabelButton()
            }

            Divider()

            Toggle(
                NSLocalizedString(
                    "provider.agents_link.toggle",
                    value: "Link this provider's AGENTS docs to ~/.nolon/agents",
                    comment: "Agents link toggle title"
                ),
                isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in onToggleRequested(newValue) }
                )
            )

            Divider()

            Text(providerPath)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .help(
            NSLocalizedString(
                "provider.agents_link.menu.help",
                value: "AGENTS link settings",
                comment: "Agents link menu button help text"
            )
        )
    }
}

// MARK: - ProviderDetailStateContainerView

public struct ProviderDetailStateContainerView<NoProviderView: View, NoTabView: View, Content: View>: View {
    public struct Config {
        public var hasProvider: Bool
        public var hasSelectedTab: Bool
        public var isLoading: Bool
        public var noProviderView: () -> NoProviderView
        public var noTabView: () -> NoTabView
        public var content: () -> Content

        public init(
            hasProvider: Bool,
            hasSelectedTab: Bool,
            isLoading: Bool,
            @ViewBuilder noProviderView: @escaping () -> NoProviderView,
            @ViewBuilder noTabView: @escaping () -> NoTabView,
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.hasProvider = hasProvider
            self.hasSelectedTab = hasSelectedTab
            self.isLoading = isLoading
            self.noProviderView = noProviderView
            self.noTabView = noTabView
            self.content = content
        }
    }

    let hasProvider: Bool
    let hasSelectedTab: Bool
    let isLoading: Bool
    let noProviderView: () -> NoProviderView
    let noTabView: () -> NoTabView
    let content: () -> Content

    public init(config: Config) {
        self.hasProvider = config.hasProvider
        self.hasSelectedTab = config.hasSelectedTab
        self.isLoading = config.isLoading
        self.noProviderView = config.noProviderView
        self.noTabView = config.noTabView
        self.content = config.content
    }

    public init(
        hasProvider: Bool,
        hasSelectedTab: Bool,
        isLoading: Bool,
        @ViewBuilder noProviderView: @escaping () -> NoProviderView,
        @ViewBuilder noTabView: @escaping () -> NoTabView,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                hasProvider: hasProvider,
                hasSelectedTab: hasSelectedTab,
                isLoading: isLoading,
                noProviderView: noProviderView,
                noTabView: noTabView,
                content: content
            )
        )
    }

    public var body: some View {
        if !hasProvider {
            noProviderView()
        } else if !hasSelectedTab {
            noTabView()
        } else if isLoading {
            CenteredLoadingIndicatorView()
        } else {
            content()
        }
    }
}

// MARK: - ProviderFormFieldRows

public struct ProviderProjectFolderPickerRow: View {
    let displayPath: String
    let emptyPlaceholder: String
    let chooseButtonTitle: String
    let onChoose: () -> Void

    public struct Config {
        public var displayPath: String
        public var emptyPlaceholder: String
        public var chooseButtonTitle: String
        public var onChoose: () -> Void

        public init(
            displayPath: String,
            emptyPlaceholder: String,
            chooseButtonTitle: String,
            onChoose: @escaping () -> Void
        ) {
            self.displayPath = displayPath
            self.emptyPlaceholder = emptyPlaceholder
            self.chooseButtonTitle = chooseButtonTitle
            self.onChoose = onChoose
        }
    }

    public init(config: Config) {
        self.displayPath = config.displayPath
        self.emptyPlaceholder = config.emptyPlaceholder
        self.chooseButtonTitle = config.chooseButtonTitle
        self.onChoose = config.onChoose
    }

    public init(
        displayPath: String,
        emptyPlaceholder: String,
        chooseButtonTitle: String,
        onChoose: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                displayPath: displayPath,
                emptyPlaceholder: emptyPlaceholder,
                chooseButtonTitle: chooseButtonTitle,
                onChoose: onChoose
            )
        )
    }

    public var body: some View {
        HStack {
            Text(displayPath.isEmpty ? emptyPlaceholder : displayPath)
                .foregroundStyle(displayPath.isEmpty ? DesignSystem.Colors.Text.secondary : DesignSystem.Colors.Text.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button(chooseButtonTitle) {
                onChoose()
            }
            .dsSecondaryButton()
        }
    }
}

public struct ProviderResolvedPathRow: View {
    let label: String
    let path: String
    let emptyPlaceholder: String

    public struct Config {
        public var label: String
        public var path: String
        public var emptyPlaceholder: String

        public init(
            label: String,
            path: String,
            emptyPlaceholder: String
        ) {
            self.label = label
            self.path = path
            self.emptyPlaceholder = emptyPlaceholder
        }
    }

    public init(config: Config) {
        self.label = config.label
        self.path = config.path
        self.emptyPlaceholder = config.emptyPlaceholder
    }

    public init(
        label: String,
        path: String,
        emptyPlaceholder: String
    ) {
        self.init(
            config: Config(
                label: label,
                path: path,
                emptyPlaceholder: emptyPlaceholder
            )
        )
    }

    public var body: some View {
        LabeledContent(label) {
            Text(path.isEmpty ? emptyPlaceholder : path)
                .foregroundStyle(path.isEmpty ? DesignSystem.Colors.Text.secondary : DesignSystem.Colors.Text.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

// MARK: - ProviderFormSections

public struct ProviderProjectFolderSection: View {
    let data: ProviderProjectFolderSectionData
    let onChooseProjectFolder: () -> Void

    public struct Config {
        public var data: ProviderProjectFolderSectionData
        public var onChooseProjectFolder: () -> Void

        public init(
            data: ProviderProjectFolderSectionData,
            onChooseProjectFolder: @escaping () -> Void
        ) {
            self.data = data
            self.onChooseProjectFolder = onChooseProjectFolder
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.onChooseProjectFolder = config.onChooseProjectFolder
    }

    public init(
        data: ProviderProjectFolderSectionData,
        onChooseProjectFolder: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                data: data,
                onChooseProjectFolder: onChooseProjectFolder
            )
        )
    }

    public var body: some View {
        Section {
            switch data.mode {
            case .project:
                ProviderProjectFolderPickerRow(
                    displayPath: data.displayPath,
                    emptyPlaceholder: data.emptyPlaceholder,
                    chooseButtonTitle: data.chooseButtonTitle,
                    onChoose: onChooseProjectFolder
                )
            case .vendorLocked:
                Text(data.vendorLockedDescription)
                    .dsSecondaryText(font: .callout)
            }
        } header: {
            Text(data.sectionTitle)
        }
    }
}

public struct ProviderResolvedPathsSection: View {
    let title: String
    let items: [ProviderResolvedPathItemData]

    public struct Config {
        public var title: String
        public var items: [ProviderResolvedPathItemData]

        public init(
            title: String,
            items: [ProviderResolvedPathItemData]
        ) {
            self.title = title
            self.items = items
        }
    }

    public init(config: Config) {
        self.title = config.title
        self.items = config.items
    }

    public init(
        title: String,
        items: [ProviderResolvedPathItemData]
    ) {
        self.init(
            config: Config(
                title: title,
                items: items
            )
        )
    }

    public var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items) { item in
                    ProviderResolvedPathRow(
                        label: item.label,
                        path: item.path,
                        emptyPlaceholder: item.emptyPlaceholder
                    )
                }
            }
        } header: {
            Text(title)
        }
    }
}


// MARK: - ProviderGridEmptyStateView

public struct ProviderGridEmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String

    public struct Config {
        public var title: String
        public var systemImage: String
        public var description: String

        public init(
            title: String,
            systemImage: String,
            description: String
        ) {
            self.title = title
            self.systemImage = systemImage
            self.description = description
        }
    }

    public init(config: Config) {
        self.title = config.title
        self.systemImage = config.systemImage
        self.description = config.description
    }

    public init(
        title: String,
        systemImage: String,
        description: String
    ) {
        self.init(
            config: Config(
                title: title,
                systemImage: systemImage,
                description: description
            )
        )
    }

    public var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(description)
                .dsSecondaryText(font: .body)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - ProviderGroupedPathHeaderView

public struct ProviderGroupedPathHeaderView: View {
    let title: String
    let columnCount: Int

    public struct Config {
        public var title: String
        public var columnCount: Int

        public init(title: String, columnCount: Int) {
            self.title = title
            self.columnCount = columnCount
        }
    }

    public init(config: Config) {
        self.title = config.title
        self.columnCount = config.columnCount
    }

    public init(title: String, columnCount: Int) {
        self.init(config: Config(title: title, columnCount: columnCount))
    }

    public var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .dsSecondaryText(font: .headline)
            Spacer()
        }
        .padding(.top, 8)
        .gridCellColumns(columnCount)
    }
}

// MARK: - ProviderIdentityAndPathsFormSections

public struct ProviderIdentityAndPathsFormSections: View {
    @Binding var name: String
    let nameSection: ProviderNameSectionData
    let vendorInfo: ProviderLabeledValueData?
    let projectFolderData: ProviderProjectFolderSectionData
    let resolvedPathsTitle: String
    let resolvedPathItems: [ProviderResolvedPathItemData]
    let onChooseProjectFolder: () -> Void

    public struct Config {
        public var nameSection: ProviderNameSectionData
        public var vendorInfo: ProviderLabeledValueData?
        public var projectFolderData: ProviderProjectFolderSectionData
        public var resolvedPathsTitle: String
        public var resolvedPathItems: [ProviderResolvedPathItemData]
        public var onChooseProjectFolder: () -> Void

        public init(
            nameSection: ProviderNameSectionData,
            vendorInfo: ProviderLabeledValueData? = nil,
            projectFolderData: ProviderProjectFolderSectionData,
            resolvedPathsTitle: String = NSLocalizedString(
                "add_provider.resolved_paths_label",
                value: "Resolved Paths",
                comment: "Resolved paths section header"
            ),
            resolvedPathItems: [ProviderResolvedPathItemData],
            onChooseProjectFolder: @escaping () -> Void
        ) {
            self.nameSection = nameSection
            self.vendorInfo = vendorInfo
            self.projectFolderData = projectFolderData
            self.resolvedPathsTitle = resolvedPathsTitle
            self.resolvedPathItems = resolvedPathItems
            self.onChooseProjectFolder = onChooseProjectFolder
        }
    }

    public init(
        name: Binding<String>,
        config: Config
    ) {
        self._name = name
        self.nameSection = config.nameSection
        self.vendorInfo = config.vendorInfo
        self.projectFolderData = config.projectFolderData
        self.resolvedPathsTitle = config.resolvedPathsTitle
        self.resolvedPathItems = config.resolvedPathItems
        self.onChooseProjectFolder = config.onChooseProjectFolder
    }

    public init(
        name: Binding<String>,
        nameSection: ProviderNameSectionData,
        vendorInfo: ProviderLabeledValueData? = nil,
        projectFolderData: ProviderProjectFolderSectionData,
        resolvedPathsTitle: String = NSLocalizedString(
            "add_provider.resolved_paths_label",
            value: "Resolved Paths",
            comment: "Resolved paths section header"
        ),
        resolvedPathItems: [ProviderResolvedPathItemData],
        onChooseProjectFolder: @escaping () -> Void
    ) {
        self.init(
            name: name,
            config: Config(
                nameSection: nameSection,
                vendorInfo: vendorInfo,
                projectFolderData: projectFolderData,
                resolvedPathsTitle: resolvedPathsTitle,
                resolvedPathItems: resolvedPathItems,
                onChooseProjectFolder: onChooseProjectFolder
            )
        )
    }

    public var body: some View {
        Section {
            TextField(nameSection.placeholder, text: $name)
        } header: {
            Text(nameSection.title)
        }

        if let vendorInfo {
            Section {
                LabeledContent(vendorInfo.label) {
                    Text(vendorInfo.value)
                }
            }
        }

        ProviderProjectFolderSection(
            data: projectFolderData,
            onChooseProjectFolder: onChooseProjectFolder
        )

        ProviderResolvedPathsSection(
            title: resolvedPathsTitle,
            items: resolvedPathItems
        )
    }
}

// MARK: - ProviderLogoView

public struct ProviderLogoView: View {
    public enum Style {
        case iconOnly
        case vertical
        case horizontal
    }
    
    let name: String
    let logoName: String?
    var style: Style = .iconOnly
    var iconSize: CGFloat? = nil
    var highlightQuery: String = ""
    
    public struct Config {
        public var name: String
        public var logoName: String?
        public var highlightQuery: String
        public var style: Style
        public var iconSize: CGFloat?

        public init(
            name: String,
            logoName: String?,
            highlightQuery: String = "",
            style: Style = .iconOnly,
            iconSize: CGFloat? = nil
        ) {
            self.name = name
            self.logoName = logoName
            self.highlightQuery = highlightQuery
            self.style = style
            self.iconSize = iconSize
        }
    }

    public init(config: Config) {
        self.name = config.name
        self.logoName = config.logoName
        self.highlightQuery = config.highlightQuery
        self.style = config.style
        self.iconSize = config.iconSize
    }

    public init(name: String, logoName: String?, highlightQuery: String = "", style: Style = .iconOnly, iconSize: CGFloat? = nil) {
        self.init(
            config: Config(
                name: name,
                logoName: logoName,
                highlightQuery: highlightQuery,
                style: style,
                iconSize: iconSize
            )
        )
    }
    
    public var body: some View {
        switch style {
        case .iconOnly:
            iconView
        case .vertical:
            VStack(spacing: 4) {
                iconView
                nameView
            }
        case .horizontal:
            HStack(spacing: 8) {
                iconView
                nameView
            }
        }
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    @ViewBuilder
    var iconView: some View {
        if let logoName = logoName {
            if NSImage(named: logoName) != nil {
                // SwiftUI Image automatically handles Light/Dark appearances in XCAssets
                Image(logoName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .help(name)
            } else {
                // Fallback to remote Lobe Icons CDN
                let theme = colorScheme == .dark ? "dark" : "light"
                // Using colored priority in remote fallback if possible? 
                // Actually stick to the standard slug as it's more reliable via CDN
                let urlString = "https://unpkg.com/@lobehub/icons-static-png@latest/\(theme)/\(logoName).png"
                if let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            fallbackView
                        case .empty:
                            ProgressView()
                                .controlSize(.small)
                        @unknown default:
                            fallbackView
                        }
                    }
                    .frame(width: iconSize, height: iconSize)
                    .help(name)
                } else {
                    fallbackView
                        .frame(width: iconSize, height: iconSize)
                        .help(name)
                }
            }
        } else {
            fallbackView
                .frame(width: iconSize, height: iconSize)
                .help(name)
        }
    }
    
    var nameView: some View {
        HighlightedText(text: name, query: highlightQuery)
            .font(.caption)
            .lineLimit(1)
            .foregroundStyle(DesignSystem.Colors.Text.primary)
    }
    
    var fallbackView: some View {
        let font: Font = {
            if let size = iconSize {
                return .system(size: size * 0.6, design: .rounded)
            } else {
                return .system(.title2, design: .rounded)
            }
        }()
        
        return Text(name.prefix(1).uppercased())
            .font(font)
            .fontWeight(.bold)
            .dsSecondaryText(font: font)
    }
}

// MARK: - ProviderMcpConfigScaffoldView

public struct ProviderMcpConfigScaffoldView<
    NoConfigView: View,
    NoServersView: View,
    NoResultsView: View,
    ContentView: View
>: View {
    let supportsNativeConfig: Bool
    let configExists: Bool
    let isSearching: Bool
    let hasFilteredServers: Bool
    let unsupportedTitle: String
    let unsupportedSystemImage: String
    let unsupportedDescription: String
    let noConfigView: () -> NoConfigView
    let noServersView: () -> NoServersView
    let noResultsView: () -> NoResultsView
    let contentView: () -> ContentView

    public struct Config {
        public var supportsNativeConfig: Bool
        public var configExists: Bool
        public var isSearching: Bool
        public var hasFilteredServers: Bool
        public var unsupportedTitle: String
        public var unsupportedSystemImage: String
        public var unsupportedDescription: String

        public init(
            supportsNativeConfig: Bool,
            configExists: Bool,
            isSearching: Bool,
            hasFilteredServers: Bool,
            unsupportedTitle: String = NSLocalizedString(
                "mcp.not_supported",
                value: "MCP Not Supported",
                comment: "MCP unsupported title"
            ),
            unsupportedSystemImage: String = "exclamationmark.triangle",
            unsupportedDescription: String = NSLocalizedString(
                "mcp.not_supported_desc",
                value: "This provider does not support MCP configuration",
                comment: "MCP unsupported description"
            )
        ) {
            self.supportsNativeConfig = supportsNativeConfig
            self.configExists = configExists
            self.isSearching = isSearching
            self.hasFilteredServers = hasFilteredServers
            self.unsupportedTitle = unsupportedTitle
            self.unsupportedSystemImage = unsupportedSystemImage
            self.unsupportedDescription = unsupportedDescription
        }
    }

    public init(
        config: Config,
        @ViewBuilder noConfigView: @escaping () -> NoConfigView,
        @ViewBuilder noServersView: @escaping () -> NoServersView,
        @ViewBuilder noResultsView: @escaping () -> NoResultsView,
        @ViewBuilder contentView: @escaping () -> ContentView
    ) {
        self.supportsNativeConfig = config.supportsNativeConfig
        self.configExists = config.configExists
        self.isSearching = config.isSearching
        self.hasFilteredServers = config.hasFilteredServers
        self.unsupportedTitle = config.unsupportedTitle
        self.unsupportedSystemImage = config.unsupportedSystemImage
        self.unsupportedDescription = config.unsupportedDescription
        self.noConfigView = noConfigView
        self.noServersView = noServersView
        self.noResultsView = noResultsView
        self.contentView = contentView
    }

    public init(
        supportsNativeConfig: Bool,
        configExists: Bool,
        isSearching: Bool,
        hasFilteredServers: Bool,
        unsupportedTitle: String = NSLocalizedString(
            "mcp.not_supported",
            value: "MCP Not Supported",
            comment: "MCP unsupported title"
        ),
        unsupportedSystemImage: String = "exclamationmark.triangle",
        unsupportedDescription: String = NSLocalizedString(
            "mcp.not_supported_desc",
            value: "This provider does not support MCP configuration",
            comment: "MCP unsupported description"
        ),
        @ViewBuilder noConfigView: @escaping () -> NoConfigView,
        @ViewBuilder noServersView: @escaping () -> NoServersView,
        @ViewBuilder noResultsView: @escaping () -> NoResultsView,
        @ViewBuilder contentView: @escaping () -> ContentView
    ) {
        self.init(
            config: Config(
                supportsNativeConfig: supportsNativeConfig,
                configExists: configExists,
                isSearching: isSearching,
                hasFilteredServers: hasFilteredServers,
                unsupportedTitle: unsupportedTitle,
                unsupportedSystemImage: unsupportedSystemImage,
                unsupportedDescription: unsupportedDescription
            ),
            noConfigView: noConfigView,
            noServersView: noServersView,
            noResultsView: noResultsView,
            contentView: contentView
        )
    }

    public var body: some View {
        if !supportsNativeConfig {
            McpConfigUnsupportedStateView(
                title: unsupportedTitle,
                systemImage: unsupportedSystemImage,
                description: unsupportedDescription
            )
        } else {
            McpConfigStateContainerView(
                configExists: configExists,
                isSearching: isSearching,
                hasFilteredServers: hasFilteredServers
            ) {
                noConfigView()
            } noServersView: {
                noServersView()
            } noResultsView: {
                noResultsView()
            } contentView: {
                contentView()
            }
        }
    }
}

// MARK: - ProviderQuotaSectionView

public struct ProviderQuotaSectionView: View {
    let data: ProviderQuotaSectionData
    let onRefresh: (() -> Void)?

    public struct Config {
        public var data: ProviderQuotaSectionData
        public var onRefresh: (() -> Void)?

        public init(
            data: ProviderQuotaSectionData,
            onRefresh: (() -> Void)? = nil
        ) {
            self.data = data
            self.onRefresh = onRefresh
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.onRefresh = config.onRefresh
    }

    public init(data: ProviderQuotaSectionData, onRefresh: (() -> Void)? = nil) {
        self.init(
            config: Config(
                data: data,
                onRefresh: onRefresh
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if data.showsHeader {
                header
            }

            if data.isLoading {
                loadingSkeleton
            } else if let errorMessage = data.errorMessage {
                errorState(message: errorMessage)
            } else if !data.rows.isEmpty || data.creditsText != nil {
                quotaList
            } else if data.showsEmptyState {
                emptyState
            }

            footer
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            if data.usesCardChrome {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DesignSystem.Colors.Background.surface)
            }
        }
        .overlay {
            if data.usesCardChrome {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DesignSystem.Colors.Background.elevated.opacity(0.3), lineWidth: 1)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(statusColor(for: data.statusPercent))
                .frame(width: 6, height: 6)
                .shadow(color: statusColor(for: data.statusPercent).opacity(0.5), radius: 3)

            Text(data.accountTitle)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .lineLimit(1)

            Spacer()

            if let onRefresh {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                }
                .buttonStyle(.plain)
                .opacity(data.isLoading ? 0.3 : 0.6)
                .disabled(data.isLoading)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }

    private var quotaList: some View {
        VStack(spacing: 2) {
            ForEach(data.rows) { row in
                ghostRow(row: row)
            }

            if let creditsText = data.creditsText {
                creditsRow(creditsText)
            }
        }
    }

    private func ghostRow(row: ProviderQuotaSectionData.WindowRow) -> some View {
        let color = statusColor(for: row.remainingPercent)

        return ZStack(alignment: .leading) {
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.15))
                    .frame(
                        width: row.remainingPercent.isInfinite
                            ? proxy.size.width
                            : max(0, proxy.size.width * min(1, max(0, row.remainingPercent / 100.0)))
                    )
            }
            .frame(height: 28)

            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(row.title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)

                    if let resetText = row.resetText, !resetText.isEmpty {
                        Text("· \(resetText)")
                            .font(.system(size: 9))
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    }
                }

                Spacer()

                Text(row.percentText)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func creditsRow(_ creditsText: String) -> some View {
        HStack {
            Text(NSLocalizedString("usage.metric.credits", value: "Credits", comment: "Credits label"))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)

            Spacer()

            Text(creditsText)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.primary)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
    }

    private var footer: some View {
        HStack(alignment: .center) {
            if let planText = data.planText, !planText.isEmpty {
                Text(planText)
                    .font(.system(size: 8, weight: .black))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 4).fill(planColor(planText).opacity(0.15)))
                    .foregroundStyle(planColor(planText))
                    .textCase(.uppercase)
            }

            Spacer()

            if let syncText = data.syncText, !syncText.isEmpty {
                Text(syncText)
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 4)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignSystem.Colors.Background.elevated.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.top, 4)
    }

    private func errorState(message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(NSLocalizedString("usage.error.title", value: "Sync Failed", comment: "Error title"))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Status.error)
            Text(message)
                .font(.system(size: 9))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.Status.error.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(0..<2, id: \.self) { index in
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignSystem.Colors.Background.elevated.opacity(0.28))
                    .frame(height: 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(statusColor(for: 100).opacity(index == 0 ? 0.12 : 0.08))
                            .frame(width: index == 0 ? 148 : 116)
                    }
            }
        }
        .redacted(reason: .placeholder)
    }

    private var emptyState: some View {
        Text(NSLocalizedString("usage.monitor.empty.desc", value: "No data available.", comment: "Empty data"))
            .font(.system(size: 10))
            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            .frame(maxWidth: .infinity, minHeight: 40)
    }

    private func statusColor(for percent: Double) -> Color {
        if percent.isInfinite { return DesignSystem.Colors.Status.success }
        if percent < 10 { return DesignSystem.Colors.Status.error }
        if percent < 25 { return DesignSystem.Colors.Status.warning }
        return DesignSystem.Colors.primary
    }

    private func planColor(_ plan: String) -> Color {
        let value = plan.lowercased()
        if value.contains("pro") || value.contains("enterprise") || value.contains("team") {
            return DesignSystem.Colors.primary
        }
        if value.contains("free") || value.contains("limited") {
            return DesignSystem.Colors.Status.error
        }
        return DesignSystem.Colors.Text.secondary
    }
}

// MARK: - ProviderResourceGridSectionView

public enum ProviderResourceGridKind: Hashable, Sendable {
    case skills
    case workflows
    case rules
    case agents
}

public struct ProviderResourceGridSectionView<Content: View>: View {
    let isEmpty: Bool
    let searchText: String
    let kind: ProviderResourceGridKind?
    let emptyTitle: String
    let emptySystemImage: String
    let emptyDescription: String
    let noResultsTitle: String
    let noResultsSystemImage: String
    let noResultsDescription: String
    let columns: [GridItem]
    let content: () -> Content

    public struct Config {
        public var isEmpty: Bool
        public var searchText: String
        public var kind: ProviderResourceGridKind?
        public var emptyTitle: String?
        public var emptySystemImage: String?
        public var emptyDescription: String?
        public var noResultsTitle: String
        public var noResultsSystemImage: String
        public var noResultsDescription: String
        public var columns: [GridItem]

        public init(
            isEmpty: Bool,
            searchText: String,
            kind: ProviderResourceGridKind? = nil,
            emptyTitle: String? = nil,
            emptySystemImage: String? = nil,
            emptyDescription: String? = nil,
            noResultsTitle: String = "No Results",
            noResultsSystemImage: String = "magnifyingglass",
            noResultsDescription: String,
            columns: [GridItem]
        ) {
            self.isEmpty = isEmpty
            self.searchText = searchText
            self.kind = kind
            self.emptyTitle = emptyTitle
            self.emptySystemImage = emptySystemImage
            self.emptyDescription = emptyDescription
            self.noResultsTitle = noResultsTitle
            self.noResultsSystemImage = noResultsSystemImage
            self.noResultsDescription = noResultsDescription
            self.columns = columns
        }
    }

    public init(
        config: Config,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isEmpty = config.isEmpty
        self.searchText = config.searchText
        self.kind = config.kind
        self.emptyTitle = config.emptyTitle ?? Self.defaultEmptyTitle(for: config.kind)
        self.emptySystemImage = config.emptySystemImage ?? Self.defaultEmptySystemImage(for: config.kind)
        self.emptyDescription = config.emptyDescription ?? Self.defaultEmptyDescription(for: config.kind)
        self.noResultsTitle = config.noResultsTitle
        self.noResultsSystemImage = config.noResultsSystemImage
        self.noResultsDescription = config.noResultsDescription
        self.columns = config.columns
        self.content = content
    }

    public init(
        isEmpty: Bool,
        searchText: String,
        kind: ProviderResourceGridKind? = nil,
        emptyTitle: String? = nil,
        emptySystemImage: String? = nil,
        emptyDescription: String? = nil,
        noResultsTitle: String = "No Results",
        noResultsSystemImage: String = "magnifyingglass",
        noResultsDescription: String,
        columns: [GridItem],
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                isEmpty: isEmpty,
                searchText: searchText,
                kind: kind,
                emptyTitle: emptyTitle,
                emptySystemImage: emptySystemImage,
                emptyDescription: emptyDescription,
                noResultsTitle: noResultsTitle,
                noResultsSystemImage: noResultsSystemImage,
                noResultsDescription: noResultsDescription,
                columns: columns
            ),
            content: content
        )
    }

    public var body: some View {
        ProviderGridContentScaffold(
            isEmpty: isEmpty,
            emptyTitle: searchText.isEmpty ? emptyTitle : noResultsTitle,
            emptySystemImage: searchText.isEmpty ? emptySystemImage : noResultsSystemImage,
            emptyDescription: searchText.isEmpty ? emptyDescription : noResultsDescription,
            columns: columns
        ) {
            content()
        }
    }

    nonisolated private static func defaultEmptyTitle(for kind: ProviderResourceGridKind?) -> String {
        switch kind {
        case .skills:
            return NSLocalizedString("skills.empty", value: "No Skills", comment: "No skills")
        case .workflows:
            return NSLocalizedString("workflows.empty", value: "No Workflows", comment: "No workflows")
        case .rules:
            return NSLocalizedString("rules.empty", value: "No Rules", comment: "No rules")
        case .agents:
            return NSLocalizedString("agents.empty", value: "No AGENTS.md Files", comment: "No agent docs")
        case nil:
            return NSLocalizedString("remote.search.no_results", value: "No Results", comment: "No results")
        }
    }

    nonisolated private static func defaultEmptySystemImage(for kind: ProviderResourceGridKind?) -> String {
        switch kind {
        case .skills:
            return "square.grid.2x2"
        case .workflows:
            return "arrow.triangle.branch"
        case .rules:
            return "list.bullet.rectangle"
        case .agents:
            return "doc.text"
        case nil:
            return "tray"
        }
    }

    nonisolated private static func defaultEmptyDescription(for kind: ProviderResourceGridKind?) -> String {
        switch kind {
        case .skills:
            return NSLocalizedString("skills.empty_desc", value: "No skills installed in this provider", comment: "No skills in provider")
        case .workflows:
            return NSLocalizedString("workflows.empty_desc", value: "No workflows in this provider", comment: "No workflows in provider")
        case .rules:
            return NSLocalizedString("rules.empty_desc", value: "No rules in this provider", comment: "No rules in provider")
        case .agents:
            return NSLocalizedString("agents.empty_desc", value: "No AGENTS.md files found for this provider", comment: "No agents docs")
        case nil:
            return NSLocalizedString("remote.search.no_results_desc", value: "No matching results found", comment: "No search results description")
        }
    }
}
