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
            return NSLocalizedString("agents.empty_desc", value: "No AGENTS.md files found in Codex home", comment: "No agents docs")
        case nil:
            return NSLocalizedString("remote.search.no_results_desc", value: "No matching results found", comment: "No search results description")
        }
    }
}

// MARK: - ProviderSkillsTopControlsView

public struct ProviderSkillsTopControlsView: View {
    let providerPickerTitle: String
    let providers: [ProviderSkillsOption]
    @Binding var selectedProviderIndex: Int
    let migrationBannerTitle: String
    let migrationBannerDescription: String
    let migrationBannerActionTitle: String
    let showsMigrationBanner: Bool
    let onMigrateAll: () -> Void

    public struct Config {
        public var providerPickerTitle: String
        public var providers: [ProviderSkillsOption]
        public var migrationBannerTitle: String
        public var migrationBannerDescription: String
        public var migrationBannerActionTitle: String
        public var showsMigrationBanner: Bool
        public var onMigrateAll: () -> Void

        public init(
            providerPickerTitle: String = NSLocalizedString("provider_picker.label", value: "Provider", comment: "Provider picker label"),
            providers: [ProviderSkillsOption],
            migrationBannerTitle: String = NSLocalizedString("banner.orphaned_title", value: "Orphaned Skills Detected", comment: "Orphaned skills banner title"),
            migrationBannerDescription: String = NSLocalizedString("banner.orphaned_desc", value: "Some skills are not managed by this provider yet.", comment: "Orphaned skills banner description"),
            migrationBannerActionTitle: String = NSLocalizedString("action.import_all", value: "Import All", comment: "Import all action"),
            showsMigrationBanner: Bool,
            onMigrateAll: @escaping () -> Void
        ) {
            self.providerPickerTitle = providerPickerTitle
            self.providers = providers
            self.migrationBannerTitle = migrationBannerTitle
            self.migrationBannerDescription = migrationBannerDescription
            self.migrationBannerActionTitle = migrationBannerActionTitle
            self.showsMigrationBanner = showsMigrationBanner
            self.onMigrateAll = onMigrateAll
        }
    }

    public init(
        selectedProviderIndex: Binding<Int>,
        config: Config
    ) {
        self.providerPickerTitle = config.providerPickerTitle
        self.providers = config.providers
        self._selectedProviderIndex = selectedProviderIndex
        self.migrationBannerTitle = config.migrationBannerTitle
        self.migrationBannerDescription = config.migrationBannerDescription
        self.migrationBannerActionTitle = config.migrationBannerActionTitle
        self.showsMigrationBanner = config.showsMigrationBanner
        self.onMigrateAll = config.onMigrateAll
    }

    public init(
        providerPickerTitle: String = NSLocalizedString("provider_picker.label", value: "Provider", comment: "Provider picker label"),
        providers: [ProviderSkillsOption],
        selectedProviderIndex: Binding<Int>,
        migrationBannerTitle: String = NSLocalizedString("banner.orphaned_title", value: "Orphaned Skills Detected", comment: "Orphaned skills banner title"),
        migrationBannerDescription: String = NSLocalizedString("banner.orphaned_desc", value: "Some skills are not managed by this provider yet.", comment: "Orphaned skills banner description"),
        migrationBannerActionTitle: String = NSLocalizedString("action.import_all", value: "Import All", comment: "Import all action"),
        showsMigrationBanner: Bool,
        onMigrateAll: @escaping () -> Void
    ) {
        self.init(
            selectedProviderIndex: selectedProviderIndex,
            config: Config(
                providerPickerTitle: providerPickerTitle,
                providers: providers,
                migrationBannerTitle: migrationBannerTitle,
                migrationBannerDescription: migrationBannerDescription,
                migrationBannerActionTitle: migrationBannerActionTitle,
                showsMigrationBanner: showsMigrationBanner,
                onMigrateAll: onMigrateAll
            )
        )
    }

    public var body: some View {
        if !providers.isEmpty {
            Picker(providerPickerTitle, selection: $selectedProviderIndex) {
                ForEach(Array(providers.enumerated()), id: \.element.id) { index, provider in
                    Text(provider.title).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .padding()
        }

        if showsMigrationBanner {
            OrphanedSkillsMigrationBannerView(
                title: migrationBannerTitle,
                description: migrationBannerDescription,
                actionTitle: migrationBannerActionTitle,
                onAction: onMigrateAll
            )
            .padding(.horizontal)
        }
    }
}

// MARK: - ProviderTokenTrendSectionView

public struct ProviderTokenTrendSectionView: View {
    private let data: ProviderTokenTrendSectionData
    private let onRangeChange: (String) -> Void
    private let onRefresh: () -> Void

    @State private var sortKey: SortKey = .date
    @State private var sortAscending = false
    @State private var selectedDate: String?

    public struct Config {
        public var data: ProviderTokenTrendSectionData
        public var onRangeChange: (String) -> Void
        public var onRefresh: () -> Void

        public init(
            data: ProviderTokenTrendSectionData,
            onRangeChange: @escaping (String) -> Void,
            onRefresh: @escaping () -> Void
        ) {
            self.data = data
            self.onRangeChange = onRangeChange
            self.onRefresh = onRefresh
        }
    }

    public init(config: Config) {
        self.data = config.data
        self.onRangeChange = config.onRangeChange
        self.onRefresh = config.onRefresh
    }

    public init(
        data: ProviderTokenTrendSectionData,
        onRangeChange: @escaping (String) -> Void,
        onRefresh: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                data: data,
                onRangeChange: onRangeChange,
                onRefresh: onRefresh
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let snapshot = data.snapshot {
                summary(snapshot: snapshot)
                chartSection(snapshot: snapshot)
                tableSection(snapshot: snapshot)
            } else if let errorMessage = data.errorMessage, !errorMessage.isEmpty {
                errorState(message: errorMessage)
            } else if data.isLoading {
                loadingState()
            } else {
                emptyState
            }
        }
        .padding(16)
        .dsCard()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(NSLocalizedString("usage.token_trend.title", value: "历史 Token 消耗", comment: "Token trend section title"))
                    .font(.headline)

                Spacer()

                Button {
                    onRefresh()
                } label: {
                    if data.isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .help(NSLocalizedString("generic.refresh", value: "Refresh", comment: "Refresh button"))
            }

            HStack(alignment: .firstTextBaseline) {
                Text(NSLocalizedString("usage.token_trend.subtitle", value: "按日聚合输入、输出与缓存命中 token。", comment: "Token trend section subtitle"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)

                Spacer()

                if let snapshot = data.snapshot {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text("\(snapshot.updatedAt.formatted(date: .abbreviated, time: .shortened)) 更新")
                        if !snapshot.sourceLabel.isEmpty {
                            Text("(\(snapshot.sourceLabel))")
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                }
            }
        }
    }

    private func summary(snapshot: ProviderTokenTrendSnapshotData) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            ForEach(summaryMetrics(snapshot: snapshot, selectedDate: selectedDate)) { item in
                Button {
                    onRangeChange(item.targetRangeID)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                            .textCase(.uppercase)

                        Text(item.value)
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(DesignSystem.Colors.Text.primary)

                        Text(item.detail)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
                    .padding(12)
                    .background(summaryCardBackground(for: item))
                    .overlay(summaryCardBorder(for: item))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func chartSection(snapshot: ProviderTokenTrendSnapshotData) -> some View {
        let title = NSLocalizedString("usage.token_trend.chart", value: "Daily Trend", comment: "Daily trend chart title")
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                chartLegend
            }
            chart(snapshot: snapshot)
        }
        .padding(12)
        .background(DesignSystem.Colors.Background.elevated.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    private var chartLegend: some View {
        HStack(spacing: 12) {
            legendItem(title: "Input", color: DesignSystem.Colors.primary)
            legendItem(title: "Output", color: DesignSystem.Colors.Status.success)
            legendItem(title: "Cache", color: DesignSystem.Colors.Status.warning)
        }
    }

    private func legendItem(title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
    }

    private func chart(snapshot: ProviderTokenTrendSnapshotData) -> some View {
        GeometryReader { proxy in
            let points = snapshot.points
            let maxValue = max(points.map(\.totalTokens).max() ?? 1, 1)
            let spacing: CGFloat = 8
            let availableWidth = proxy.size.width - (CGFloat(max(0, points.count - 1)) * spacing)
            let barWidth = max(4, min(24, availableWidth / CGFloat(max(1, points.count))))

            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(points, id: \.date) { point in
                            stackedBar(point: point, maxValue: maxValue, width: barWidth, maxHeight: proxy.size.height - 24)
                                .id(point.date)
                        }
                    }
                    .padding(.bottom, 4)
                }
                .onAppear {
                    if let lastDate = points.last?.date {
                        scrollProxy.scrollTo(lastDate, anchor: .trailing)
                    }
                }
            }
        }
        .frame(height: 160)
    }

    private func stackedBar(point: ProviderTokenTrendPointData, maxValue: Int, width: CGFloat, maxHeight: CGFloat) -> some View {
        let isSelected = point.date == selectedDate
        let totalRatio = CGFloat(point.totalTokens) / CGFloat(maxValue)
        let barHeight = max(4, totalRatio * maxHeight)

        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedDate = selectedDate == point.date ? nil : point.date
            }
        } label: {
            VStack(spacing: 6) {
                VStack(spacing: 0) {
                    barSegment(value: point.inputTokens, total: point.totalTokens, height: barHeight, color: DesignSystem.Colors.primary)
                    barSegment(value: point.outputTokens, total: point.totalTokens, height: barHeight, color: DesignSystem.Colors.Status.success)
                    barSegment(value: point.cacheReadTokens, total: point.totalTokens, height: barHeight, color: DesignSystem.Colors.Status.warning)
                }
                .frame(width: width, height: barHeight)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(DesignSystem.Colors.primary, lineWidth: isSelected ? 2 : 0)
                )
                .opacity(selectedDate == nil || isSelected ? 1.0 : 0.4)

                Text(shortDate(point.date))
                    .font(.system(size: 9))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func barSegment(value: Int, total: Int, height: CGFloat, color: Color) -> some View {
        let ratio = total > 0 ? CGFloat(value) / CGFloat(total) : 0
        return Rectangle().fill(color).frame(height: ratio * height)
    }

    private func tableSection(snapshot: ProviderTokenTrendSnapshotData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("usage.token_trend.table", value: "Daily Breakdown", comment: "Daily breakdown table"))
                .font(.subheadline.weight(.semibold))

            VStack(spacing: 0) {
                headerRow
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DesignSystem.Colors.Background.elevated.opacity(0.3))

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(sortedPoints(snapshot.points), id: \.date) { point in
                            dataRow(point: point)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(DesignSystem.Colors.Background.elevated.opacity(0.5), lineWidth: 1)
            )
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            sortableHeader(title: "Date", key: .date, width: 90, alignment: .leading)
            Spacer()
            sortableHeader(title: "Total", key: .total, width: 80)
            sortableHeader(title: "Input", key: .input, width: 80)
            sortableHeader(title: "Output", key: .output, width: 80)
            sortableHeader(title: "Cache", key: .cache, width: 80)
        }
    }

    private func sortableHeader(title: String, key: SortKey, width: CGFloat, alignment: Alignment = .trailing) -> some View {
        Button {
            if sortKey == key {
                sortAscending.toggle()
            } else {
                sortKey = key
                sortAscending = key == .date
            }
        } label: {
            HStack(spacing: 4) {
                if alignment == .trailing && sortKey == key {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down").font(.system(size: 8))
                }
                Text(title)
                if alignment == .leading && sortKey == key {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down").font(.system(size: 8))
                }
            }
            .frame(width: width, alignment: alignment)
            .font(.caption2.weight(.bold))
            .foregroundStyle(sortKey == key ? DesignSystem.Colors.primary : DesignSystem.Colors.Text.secondary)
        }
        .buttonStyle(.plain)
    }

    private func dataRow(point: ProviderTokenTrendPointData) -> some View {
        let isSelected = point.date == selectedDate
        return HStack(spacing: 0) {
            Text(point.date).frame(width: 90, alignment: .leading)
            Spacer()
            cell(formatTokenCount(point.totalTokens), width: 80)
            cell(formatTokenCount(point.inputTokens), width: 80, color: DesignSystem.Colors.primary.opacity(0.8))
            cell(formatTokenCount(point.outputTokens), width: 80, color: DesignSystem.Colors.Status.success.opacity(0.8))
            cell(formatTokenCount(point.cacheReadTokens), width: 80, color: DesignSystem.Colors.Status.warning.opacity(0.8))
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? DesignSystem.Colors.primary.opacity(0.08) : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = selectedDate == point.date ? nil : point.date
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignSystem.Colors.Background.elevated.opacity(0.3))
                .frame(height: 1)
        }
    }

    private func cell(_ text: String, width: CGFloat, alignment: Alignment = .trailing, color: Color = .primary) -> some View {
        Text(text)
            .foregroundStyle(color == .primary ? DesignSystem.Colors.Text.primary : color)
            .frame(width: width, alignment: alignment)
    }

    private func loadingState() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4).fill(DesignSystem.Colors.Background.elevated.opacity(0.35)).frame(width: 52, height: 10)
                        RoundedRectangle(cornerRadius: 6).fill(DesignSystem.Colors.Background.elevated.opacity(0.42)).frame(width: 88, height: 20)
                        RoundedRectangle(cornerRadius: 4).fill(DesignSystem.Colors.Background.elevated.opacity(0.28)).frame(width: 72, height: 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(DesignSystem.Colors.Background.elevated.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .redacted(reason: .placeholder)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(DesignSystem.Colors.Status.error)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .frame(maxWidth: 240)
            Button(NSLocalizedString("generic.refresh", value: "Retry", comment: "Retry button")) { onRefresh() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title2)
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            Text(NSLocalizedString("usage.token_trend.empty", value: "No token history yet.", comment: "Empty token trend state"))
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }

    private func sortedPoints(_ points: [ProviderTokenTrendPointData]) -> [ProviderTokenTrendPointData] {
        points.sorted { lhs, rhs in
            let ordered: Bool
            switch sortKey {
            case .date: ordered = lhs.date < rhs.date
            case .total: ordered = lhs.totalTokens < rhs.totalTokens
            case .input: ordered = lhs.inputTokens < rhs.inputTokens
            case .output: ordered = lhs.outputTokens < rhs.outputTokens
            case .cache: ordered = lhs.cacheReadTokens < rhs.cacheReadTokens
            }
            return sortAscending ? ordered : !ordered
        }
    }

    private func shortDate(_ value: String) -> String {
        guard value.count >= 10 else { return value }
        return String(value.suffix(5))
    }

    private func formatTokenCount(_ value: Int?) -> String {
        guard let value else { return "-" }
        let absValue = abs(value)
        switch absValue {
        case 1_000_000_000...:
            return String(format: "%.1fB", Double(value) / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.1fM", Double(value) / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", Double(value) / 1_000)
        default:
            return "\(value)"
        }
    }
}

private extension ProviderTokenTrendSectionView {
    enum SortKey {
        case date, total, input, output, cache
    }

    struct SummaryMetric: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let detail: String
        let accentColor: Color
        let secondaryAccentColor: Color
        let targetRangeID: String
    }

    func summaryMetrics(snapshot: ProviderTokenTrendSnapshotData, selectedDate: String?) -> [SummaryMetric] {
        [
            .init(
                title: NSLocalizedString("usage.token_trend.summary.today", value: "Today", comment: "Today tokens"),
                value: formatTokenCount(snapshot.todayTokens),
                detail: selectedDate ?? NSLocalizedString("usage.token_trend.summary.latest", value: "Latest", comment: "Latest point"),
                accentColor: DesignSystem.Colors.primary,
                secondaryAccentColor: DesignSystem.Colors.primary.opacity(0.5),
                targetRangeID: "days1"
            ),
            .init(
                title: NSLocalizedString("usage.token_trend.summary.7d", value: "7 Days", comment: "7 day tokens"),
                value: formatTokenCount(snapshot.last7DaysTokens),
                detail: NSLocalizedString("usage.token_trend.summary.trailing", value: "Trailing total", comment: "Trailing total"),
                accentColor: DesignSystem.Colors.Status.success,
                secondaryAccentColor: DesignSystem.Colors.Status.success.opacity(0.5),
                targetRangeID: "days7"
            ),
            .init(
                title: NSLocalizedString("usage.token_trend.summary.30d", value: "30 Days", comment: "30 day tokens"),
                value: formatTokenCount(snapshot.last30DaysTokens),
                detail: NSLocalizedString("usage.token_trend.summary.trailing", value: "Trailing total", comment: "Trailing total"),
                accentColor: DesignSystem.Colors.Status.warning,
                secondaryAccentColor: DesignSystem.Colors.Status.warning.opacity(0.5),
                targetRangeID: "days30"
            ),
            .init(
                title: NSLocalizedString("codex.usage.range.all", value: "ALL", comment: "Codex usage trend range all"),
                value: formatTokenCount(snapshot.allDaysTokens),
                detail: NSLocalizedString("usage.token_trend.summary.trailing", value: "Trailing total", comment: "Trailing total"),
                accentColor: DesignSystem.Colors.Text.secondary,
                secondaryAccentColor: DesignSystem.Colors.Background.elevated,
                targetRangeID: "all"
            )
        ]
    }

    @ViewBuilder
    func summaryCardBackground(for item: SummaryMetric) -> some View {
        let isSelected = data.selectedRangeID == item.targetRangeID
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: isSelected
                        ? [item.accentColor.opacity(0.26), item.secondaryAccentColor.opacity(0.16)]
                        : [item.accentColor.opacity(0.16), DesignSystem.Colors.Background.elevated.opacity(0.58)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    @ViewBuilder
    func summaryCardBorder(for item: SummaryMetric) -> some View {
        let isSelected = data.selectedRangeID == item.targetRangeID
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                isSelected ? item.accentColor.opacity(0.72) : item.accentColor.opacity(0.24),
                lineWidth: isSelected ? 1.5 : 1
            )
    }
}

// MARK: - ProviderUsageEmptyStateCard

public struct ProviderUsageEmptyStateCard: View {
    @State private var viewModel: ProviderUsageEmptyStateCardViewModel

    public struct Config {
        public var title: LocalizedStringKey
        public var systemImage: String
        public var descriptionText: Text

        public init(
            title: LocalizedStringKey,
            systemImage: String,
            descriptionText: Text
        ) {
            self.title = title
            self.systemImage = systemImage
            self.descriptionText = descriptionText
        }
    }

    public init(config: Config) {
        _viewModel = State(
            initialValue: ProviderUsageEmptyStateCardViewModel(
                title: config.title,
                systemImage: config.systemImage,
                descriptionText: config.descriptionText
            )
        )
    }

    public init(
        title: LocalizedStringKey,
        systemImage: String,
        descriptionText: Text
    ) {
        self.init(
            config: Config(
                title: title,
                systemImage: systemImage,
                descriptionText: descriptionText
            )
        )
    }

    public var body: some View {
        ContentUnavailableView(
            viewModel.title,
            systemImage: viewModel.systemImage,
            description: viewModel.descriptionText
                .dsSecondaryText(font: .body)
        )
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
        .padding(24)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity, alignment: .center)
        .dsCard(
            background: DesignSystem.Colors.Background.surface,
            borderColor: DesignSystem.Colors.Component.border.opacity(DesignSystem.Colors.Opacity.high)
        )
    }
}

// MARK: - ProviderUsageLoginSheets

public struct UsageLoginSheetView: View {
    let title: String
    let url: URL?

    @Environment(\.dismiss) private var dismiss

    public struct Config {
        public var title: String
        public var url: URL?

        public init(
            title: String,
            url: URL?
        ) {
            self.title = title
            self.url = url
        }
    }

    public init(config: Config) {
        self.title = config.title
        self.url = config.url
    }

    public init(title: String, url: URL?) {
        self.init(config: Config(title: title, url: url))
    }

    public var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(title: title) {
                dismiss()
            }

            SheetDivider()

            if let url {
                ProviderLoginWebView(url: url)
            } else {
                ContentUnavailableView(
                    NSLocalizedString("usage.monitor.login", value: "Sign in…", comment: "Sign in"),
                    systemImage: "globe",
                    description: Text(NSLocalizedString("usage.monitor.unsupported.desc", value: "Usage is not configured for this provider yet.", comment: "Unsupported"))
                        .dsSecondaryText(font: .body)
                )
            }
        }
        .frame(minWidth: 900, minHeight: 700)
    }
}

public struct ProviderLoginWebView: NSViewRepresentable {
    public struct Config {
        public var url: URL

        public init(url: URL) {
            self.url = url
        }
    }

    let url: URL

    public init(config: Config) {
        self.url = config.url
    }

    public init(url: URL) {
        self.init(config: Config(url: url))
    }

    public func makeNSView(context _: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: config)
        view.load(URLRequest(url: url))
        return view
    }

    public func updateNSView(_ nsView: WKWebView, context _: Context) {
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }
}

public struct CodexLoginURLSheetView: View {
    public struct Config {
        public var mode: String
        public var url: URL?
        public var onCopy: () -> Void
        public var onOpen: () -> Void
        public var onCancel: () -> Void

        public init(
            mode: String,
            url: URL?,
            onCopy: @escaping () -> Void,
            onOpen: @escaping () -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.mode = mode
            self.url = url
            self.onCopy = onCopy
            self.onOpen = onOpen
            self.onCancel = onCancel
        }
    }

    let mode: String
    let url: URL?
    let onCopy: () -> Void
    let onOpen: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    public static var dismissActionTitle: String {
        NSLocalizedString("codex.login.sheet.cancel", value: "取消登录", comment: "Cancel login")
    }

    public init(config: Config) {
        self.mode = config.mode
        self.url = config.url
        self.onCopy = config.onCopy
        self.onOpen = config.onOpen
        self.onCancel = config.onCancel
    }

    public init(
        mode: String,
        url: URL?,
        onCopy: @escaping () -> Void,
        onOpen: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                mode: mode,
                url: url,
                onCopy: onCopy,
                onOpen: onOpen,
                onCancel: onCancel
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(NSLocalizedString("codex.login.sheet.title", value: "登录中", comment: "Codex login sheet title"))
                    .font(.headline)
                Spacer()
                Button(Self.dismissActionTitle) {
                    onCancel()
                    dismiss()
                }
            }

            Text(mode)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)

            GroupBox {
                Text(url?.absoluteString ?? "-")
                    .font(.caption)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button(NSLocalizedString("codex.login.sheet.copy", value: "复制 URL", comment: "Copy login URL")) {
                    onCopy()
                }
                Button(NSLocalizedString("codex.login.sheet.open", value: "在浏览器中打开", comment: "Open in browser")) {
                    onOpen()
                }
                Spacer()
            }
        }
        .padding(16)
        .frame(minWidth: 620, minHeight: 220)
    }
}

// MARK: - McpConfigActionsToolbarView

public struct McpConfigActionsToolbarView: View {
    public struct Config {
        public var documentationURL: URL?
        public var documentationTitle: String
        public var editTitle: String
        public var onEdit: () -> Void

        public init(
            documentationURL: URL?,
            documentationTitle: String = NSLocalizedString(
                "mcp.action.documentation",
                value: "Documentation",
                comment: "MCP documentation action title"
            ),
            editTitle: String = NSLocalizedString(
                "mcp.action.edit_config",
                value: "Edit Config",
                comment: "MCP edit config action title"
            ),
            onEdit: @escaping () -> Void
        ) {
            self.documentationURL = documentationURL
            self.documentationTitle = documentationTitle
            self.editTitle = editTitle
            self.onEdit = onEdit
        }
    }

    let documentationURL: URL?
    let documentationTitle: String
    let editTitle: String
    let onEdit: () -> Void

    public init(config: Config) {
        self.documentationURL = config.documentationURL
        self.documentationTitle = config.documentationTitle
        self.editTitle = config.editTitle
        self.onEdit = config.onEdit
    }

    public init(
        documentationURL: URL?,
        documentationTitle: String = NSLocalizedString(
            "mcp.action.documentation",
            value: "Documentation",
            comment: "MCP documentation action title"
        ),
        editTitle: String = NSLocalizedString(
            "mcp.action.edit_config",
            value: "Edit Config",
            comment: "MCP edit config action title"
        ),
        onEdit: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                documentationURL: documentationURL,
                documentationTitle: documentationTitle,
                editTitle: editTitle,
                onEdit: onEdit
            )
        )
    }

    public var body: some View {
        Menu {
            if let documentationURL {
                Link(destination: documentationURL) {
                    Label(documentationTitle, systemImage: "doc.text")
                }
            }
            Button {
                onEdit()
            } label: {
                Label(editTitle, systemImage: "pencil")
            }
        } label: {
            Label(editTitle, systemImage: "pencil")
        }
    }
}

// MARK: - McpConfigStateContainerView

public struct McpConfigStateContainerView<NoConfigView: View, NoServersView: View, NoResultsView: View, ContentView: View>: View {
    public struct Config {
        public var configExists: Bool
        public var isSearching: Bool
        public var hasFilteredServers: Bool
        public var noConfigView: () -> NoConfigView
        public var noServersView: () -> NoServersView
        public var noResultsView: () -> NoResultsView
        public var contentView: () -> ContentView

        public init(
            configExists: Bool,
            isSearching: Bool,
            hasFilteredServers: Bool,
            @ViewBuilder noConfigView: @escaping () -> NoConfigView,
            @ViewBuilder noServersView: @escaping () -> NoServersView,
            @ViewBuilder noResultsView: @escaping () -> NoResultsView,
            @ViewBuilder contentView: @escaping () -> ContentView
        ) {
            self.configExists = configExists
            self.isSearching = isSearching
            self.hasFilteredServers = hasFilteredServers
            self.noConfigView = noConfigView
            self.noServersView = noServersView
            self.noResultsView = noResultsView
            self.contentView = contentView
        }
    }

    let configExists: Bool
    let isSearching: Bool
    let hasFilteredServers: Bool
    let noConfigView: () -> NoConfigView
    let noServersView: () -> NoServersView
    let noResultsView: () -> NoResultsView
    let contentView: () -> ContentView

    public init(config: Config) {
        self.configExists = config.configExists
        self.isSearching = config.isSearching
        self.hasFilteredServers = config.hasFilteredServers
        self.noConfigView = config.noConfigView
        self.noServersView = config.noServersView
        self.noResultsView = config.noResultsView
        self.contentView = config.contentView
    }

    public init(
        configExists: Bool,
        isSearching: Bool,
        hasFilteredServers: Bool,
        @ViewBuilder noConfigView: @escaping () -> NoConfigView,
        @ViewBuilder noServersView: @escaping () -> NoServersView,
        @ViewBuilder noResultsView: @escaping () -> NoResultsView,
        @ViewBuilder contentView: @escaping () -> ContentView
    ) {
        self.init(
            config: Config(
                configExists: configExists,
                isSearching: isSearching,
                hasFilteredServers: hasFilteredServers,
                noConfigView: noConfigView,
                noServersView: noServersView,
                noResultsView: noResultsView,
                contentView: contentView
            )
        )
    }

    public var body: some View {
        if !configExists {
            noConfigView()
        } else if !hasFilteredServers && !isSearching {
            noServersView()
        } else if !hasFilteredServers {
            noResultsView()
        } else {
            contentView()
        }
    }
}

// MARK: - McpConfigStateViews

public struct McpConfigUnsupportedStateView: View {
    public struct Config {
        public var title: String
        public var systemImage: String
        public var description: String

        public init(
            title: String = NSLocalizedString(
                "mcp.not_supported",
                value: "MCP Not Supported",
                comment: "MCP unsupported title"
            ),
            systemImage: String = "exclamationmark.triangle",
            description: String = NSLocalizedString(
                "mcp.not_supported_desc",
                value: "This provider does not support MCP configuration",
                comment: "MCP unsupported description"
            )
        ) {
            self.title = title
            self.systemImage = systemImage
            self.description = description
        }
    }

    let title: String
    let systemImage: String
    let description: String

    public init(config: Config) {
        self.title = config.title
        self.systemImage = config.systemImage
        self.description = config.description
    }

    public init(
        title: String = NSLocalizedString(
            "mcp.not_supported",
            value: "MCP Not Supported",
            comment: "MCP unsupported title"
        ),
        systemImage: String = "exclamationmark.triangle",
        description: String = NSLocalizedString(
            "mcp.not_supported_desc",
            value: "This provider does not support MCP configuration",
            comment: "MCP unsupported description"
        )
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
        UnavailableStateView(
            title: title,
            systemImage: systemImage,
            description: description
        )
    }
}

public struct McpConfigActionStateView: View {
    public enum Preset {
        case noConfiguration
        case noServers
    }

    public struct Config {
        public var title: String
        public var systemImage: String
        public var description: String
        public var actionTitle: String
        public var onAction: () -> Void

        public init(
            title: String,
            systemImage: String,
            description: String,
            actionTitle: String,
            onAction: @escaping () -> Void
        ) {
            self.title = title
            self.systemImage = systemImage
            self.description = description
            self.actionTitle = actionTitle
            self.onAction = onAction
        }
    }

    let title: String
    let systemImage: String
    let description: String
    let actionTitle: String
    let onAction: () -> Void

    public init(config: Config) {
        self.title = config.title
        self.systemImage = config.systemImage
        self.description = config.description
        self.actionTitle = config.actionTitle
        self.onAction = config.onAction
    }

    public init(
        title: String,
        systemImage: String,
        description: String,
        actionTitle: String,
        onAction: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                title: title,
                systemImage: systemImage,
                description: description,
                actionTitle: actionTitle,
                onAction: onAction
            )
        )
    }

    public init(
        preset: Preset,
        onAction: @escaping () -> Void
    ) {
        let title: String
        let systemImage: String
        let description: String
        let actionTitle: String

        switch preset {
        case .noConfiguration:
            title = NSLocalizedString(
                "No Configuration",
                value: "No Configuration",
                comment: "MCP config missing title"
            )
            systemImage = "server.rack"
            description = NSLocalizedString(
                "MCP configuration file not found.",
                value: "MCP configuration file not found.",
                comment: "MCP config missing description"
            )
            actionTitle = NSLocalizedString(
                "Create Configuration",
                value: "Create Configuration",
                comment: "Create MCP config action"
            )
        case .noServers:
            title = NSLocalizedString(
                "No Servers",
                value: "No Servers",
                comment: "No MCP servers title"
            )
            systemImage = "server.rack"
            description = NSLocalizedString(
                "No MCP servers configured.",
                value: "No MCP servers configured.",
                comment: "No MCP servers description"
            )
            actionTitle = NSLocalizedString(
                "Edit Configuration",
                value: "Edit Configuration",
                comment: "Edit MCP config action"
            )
        }
        self.init(
            config: Config(
                title: title,
                systemImage: systemImage,
                description: description,
                actionTitle: actionTitle,
                onAction: onAction
            )
        )
    }

    public var body: some View {
        ActionUnavailableStateView(
            title: title,
            systemImage: systemImage,
            description: description,
            actionTitle: actionTitle
        ) {
            onAction()
        }
    }
}

public struct McpConfigNoResultsStateView: View {
    public struct Config {
        public var title: String
        public var systemImage: String
        public var description: String

        public init(
            title: String = NSLocalizedString(
                "mcp.empty.no_results.title",
                value: "No Results",
                comment: "MCP no results title"
            ),
            systemImage: String = "magnifyingglass",
            description: String = NSLocalizedString(
                "mcp.empty.no_results.desc",
                value: "No matching MCP servers found",
                comment: "MCP no results description"
            )
        ) {
            self.title = title
            self.systemImage = systemImage
            self.description = description
        }
    }

    let title: String
    let systemImage: String
    let description: String

    public init(config: Config) {
        self.title = config.title
        self.systemImage = config.systemImage
        self.description = config.description
    }

    public init(
        title: String = NSLocalizedString(
            "mcp.empty.no_results.title",
            value: "No Results",
            comment: "MCP no results title"
        ),
        systemImage: String = "magnifyingglass",
        description: String = NSLocalizedString(
            "mcp.empty.no_results.desc",
            value: "No matching MCP servers found",
            comment: "MCP no results description"
        )
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
        UnavailableStateView(
            title: title,
            systemImage: systemImage,
            description: description
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - McpConfigToolbarScaffoldView

public struct McpConfigToolbarScaffoldView<Content: View>: View {
    public struct Config {
        public var documentationURL: URL?
        public var documentationTitle: String
        public var editTitle: String
        public var onEdit: () -> Void
        public var content: () -> Content

        public init(
            documentationURL: URL?,
            documentationTitle: String = NSLocalizedString(
                "mcp.action.documentation",
                value: "Documentation",
                comment: "MCP documentation action title"
            ),
            editTitle: String = NSLocalizedString(
                "mcp.action.edit_config",
                value: "Edit Config",
                comment: "MCP edit config action title"
            ),
            onEdit: @escaping () -> Void,
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.documentationURL = documentationURL
            self.documentationTitle = documentationTitle
            self.editTitle = editTitle
            self.onEdit = onEdit
            self.content = content
        }
    }

    let documentationURL: URL?
    let documentationTitle: String
    let editTitle: String
    let onEdit: () -> Void
    let content: () -> Content

    public init(config: Config) {
        self.documentationURL = config.documentationURL
        self.documentationTitle = config.documentationTitle
        self.editTitle = config.editTitle
        self.onEdit = config.onEdit
        self.content = config.content
    }

    public init(
        documentationURL: URL?,
        documentationTitle: String = NSLocalizedString(
            "mcp.action.documentation",
            value: "Documentation",
            comment: "MCP documentation action title"
        ),
        editTitle: String = NSLocalizedString(
            "mcp.action.edit_config",
            value: "Edit Config",
            comment: "MCP edit config action title"
        ),
        onEdit: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                documentationURL: documentationURL,
                documentationTitle: documentationTitle,
                editTitle: editTitle,
                onEdit: onEdit,
                content: content
            )
        )
    }

    public var body: some View {
        content()
            .toolbar {
                ToolbarItem {
                    McpConfigActionsToolbarView(
                        documentationURL: documentationURL,
                        documentationTitle: documentationTitle,
                        editTitle: editTitle,
                        onEdit: onEdit
                    )
                }
            }
    }
}
