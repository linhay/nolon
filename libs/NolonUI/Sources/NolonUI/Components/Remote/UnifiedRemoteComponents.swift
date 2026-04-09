import NolonUIFoundation
import SwiftUI

// MARK: - RemoteRepositorySidebarComponents

public enum SyncHUDTone {
    case info
    case success
    case failure
}

public struct RepositoryFloatingAddButton: View {
    public struct Config {
        public var title: String
        public var action: () -> Void

        public init(
            title: String,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.action = action
        }
    }

    let title: String
    let action: () -> Void

    public init(config: Config) {
        self.title = config.title
        self.action = config.action
    }

    public init(
        title: String,
        action: @escaping () -> Void
    ) {
        self.init(config: Config(title: title, action: action))
    }

    public var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.onAccent)
                .frame(width: 34, height: 34)
                .background(DesignSystem.Colors.primary, in: Circle())
                .shadow(color: DesignSystem.Colors.primary.opacity(0.35), radius: 6, x: 0, y: 3)
        }
        .dsLinkButton()
        .help(title)
        .accessibilityLabel(title)
    }
}

public struct SyncHUDCardView<Icon: View>: View {
    public struct Config {
        public var title: String
        public var subtitle: String?
        public var tone: SyncHUDTone
        public var icon: () -> Icon

        public init(
            title: String,
            subtitle: String?,
            tone: SyncHUDTone,
            @ViewBuilder icon: @escaping () -> Icon
        ) {
            self.title = title
            self.subtitle = subtitle
            self.tone = tone
            self.icon = icon
        }
    }

    let title: String
    let subtitle: String?
    let tone: SyncHUDTone
    let icon: () -> Icon

    public init(config: Config) {
        self.title = config.title
        self.subtitle = config.subtitle
        self.tone = config.tone
        self.icon = config.icon
    }

    public init(
        title: String,
        subtitle: String?,
        tone: SyncHUDTone,
        @ViewBuilder icon: @escaping () -> Icon
    ) {
        self.init(
            config: Config(
                title: title,
                subtitle: subtitle,
                tone: tone,
                icon: icon
            )
        )
    }

    public var body: some View {
        HStack(spacing: 12) {
            icon()
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                    .lineLimit(2)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .dsSecondaryText(font: .system(size: 11))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .dsCard(
            background: DesignSystem.Colors.Background.elevated.opacity(0.94),
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border.opacity(tone == .failure ? 0.6 : 0.35),
            shadow: DesignSystem.CardShadow(
                color: DesignSystem.Colors.Text.primary.opacity(0.14),
                radius: 12,
                x: 0,
                y: 8
            )
        )
    }
}

public struct RepositorySyncHUDOverlay: View {
    public struct Config {
        public var isSyncing: Bool
        public var syncingRepositoryName: String?
        public var completionMessage: String?
        public var completionRepositoryName: String?
        public var completionTone: SyncHUDTone

        public init(
            isSyncing: Bool,
            syncingRepositoryName: String?,
            completionMessage: String?,
            completionRepositoryName: String?,
            completionTone: SyncHUDTone
        ) {
            self.isSyncing = isSyncing
            self.syncingRepositoryName = syncingRepositoryName
            self.completionMessage = completionMessage
            self.completionRepositoryName = completionRepositoryName
            self.completionTone = completionTone
        }
    }

    let isSyncing: Bool
    let syncingRepositoryName: String?
    let completionMessage: String?
    let completionRepositoryName: String?
    let completionTone: SyncHUDTone

    public init(config: Config) {
        self.isSyncing = config.isSyncing
        self.syncingRepositoryName = config.syncingRepositoryName
        self.completionMessage = config.completionMessage
        self.completionRepositoryName = config.completionRepositoryName
        self.completionTone = config.completionTone
    }

    public init(
        isSyncing: Bool,
        syncingRepositoryName: String?,
        completionMessage: String?,
        completionRepositoryName: String?,
        completionTone: SyncHUDTone
    ) {
        self.init(
            config: Config(
                isSyncing: isSyncing,
                syncingRepositoryName: syncingRepositoryName,
                completionMessage: completionMessage,
                completionRepositoryName: completionRepositoryName,
                completionTone: completionTone
            )
        )
    }

    public var body: some View {
        if isSyncing || completionMessage != nil {
            ZStack {
                if isSyncing {
                    SyncHUDCardView(
                        title: NSLocalizedString("Syncing repository...", comment: "Sync in progress"),
                        subtitle: syncingRepositoryName,
                        tone: .info
                    ) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.Status.info)
                    }
                } else if let completionMessage {
                    SyncHUDCardView(
                        title: completionMessage,
                        subtitle: completionRepositoryName,
                        tone: completionTone
                    ) {
                        Image(systemName: completionTone == .success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(
                                completionTone == .success
                                ? DesignSystem.Colors.Status.success
                                : DesignSystem.Colors.Status.error
                            )
                    }
                }
            }
            .padding(.top, 12)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .allowsHitTesting(false)
        }
    }
}

public struct RepositorySidebarSectionToggleRow: View {
    public struct Config {
        public var title: String
        public var isCollapsed: Bool
        public var onToggle: () -> Void

        public init(
            title: String,
            isCollapsed: Bool,
            onToggle: @escaping () -> Void
        ) {
            self.title = title
            self.isCollapsed = isCollapsed
            self.onToggle = onToggle
        }
    }

    let title: String
    let isCollapsed: Bool
    let onToggle: () -> Void

    public init(config: Config) {
        self.title = config.title
        self.isCollapsed = config.isCollapsed
        self.onToggle = config.onToggle
    }

    public init(
        title: String,
        isCollapsed: Bool,
        onToggle: @escaping () -> Void
    ) {
        self.init(config: Config(title: title, isCollapsed: isCollapsed, onToggle: onToggle))
    }

    public var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption)
                    .dsSecondaryText(font: .caption)

                Text(title)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)

                Spacer(minLength: 0)
            }
            .textCase(nil)
            .padding(.top, 6)
            .padding(.bottom, 2)
            .contentShape(Rectangle())
        }
        .dsLinkButton()
        .listRowSeparator(.hidden)
        .selectionDisabled(true)
    }
}

public struct RepositoryGitSyncStatusRow: View {
    public struct Config {
        public var isSyncing: Bool
        public var lastSyncDate: Date?
        public var notSyncedText: String

        public init(
            isSyncing: Bool,
            lastSyncDate: Date?,
            notSyncedText: String
        ) {
            self.isSyncing = isSyncing
            self.lastSyncDate = lastSyncDate
            self.notSyncedText = notSyncedText
        }
    }

    let isSyncing: Bool
    let lastSyncDate: Date?
    let notSyncedText: String

    public init(config: Config) {
        self.isSyncing = config.isSyncing
        self.lastSyncDate = config.lastSyncDate
        self.notSyncedText = config.notSyncedText
    }

    public init(
        isSyncing: Bool,
        lastSyncDate: Date?,
        notSyncedText: String
    ) {
        self.init(
            config: Config(
                isSyncing: isSyncing,
                lastSyncDate: lastSyncDate,
                notSyncedText: notSyncedText
            )
        )
    }

    public var body: some View {
        Group {
            if isSyncing {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.Status.info)
            } else if let syncDate = lastSyncDate {
                Text(syncDate, style: .time)
                    .font(.caption2)
                    .dsSecondaryText(font: .caption2)
            } else {
                Text(notSyncedText)
                    .font(.caption2)
                    .foregroundStyle(DesignSystem.Colors.Status.warning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct RepositorySidebarRowView: View {
    public struct Config {
        public var data: RepositorySidebarRowData

        public init(data: RepositorySidebarRowData) {
            self.data = data
        }
    }

    let data: RepositorySidebarRowData

    public init(config: Config) {
        self.data = config.data
    }

    public init(data: RepositorySidebarRowData) {
        self.init(config: Config(data: data))
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                if let logoName = data.logoName {
                    ProviderLogoView(name: data.title, logoName: logoName, iconSize: 16)
                } else {
                    Image(systemName: data.fallbackSystemIconName)
                        .dsSecondaryText(font: .caption)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(data.title)
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.Text.primary)

                    if data.secondaryText != nil || (data.showGitStatus && data.syncStatus != nil) {
                        HStack(spacing: 4) {
                            if let secondaryText = data.secondaryText {
                                Text(secondaryText)
                                    .font(.caption)
                                    .dsSecondaryText(font: .caption)
                                    .lineLimit(1)
                            }

                            if data.showGitStatus, let syncStatus = data.syncStatus {
                                if data.secondaryText != nil {
                                    Text("·")
                                        .font(.caption)
                                        .dsSecondaryText(font: .caption)
                                }
                                gitStatusInlineView(syncStatus)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                if data.isBuiltIn {
                    Text(data.builtInText)
                        .dsBadge(
                            foreground: DesignSystem.Colors.Text.secondary,
                            background: DesignSystem.Colors.Component.controlFillSubtle,
                            horizontalPadding: 6,
                            verticalPadding: 2
                        )
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func gitStatusInlineView(_ status: RepositorySyncStatusData) -> some View {
        switch status {
        case .syncing:
            Text(
                NSLocalizedString(
                    "repository.sync.syncing",
                    value: "Syncing",
                    comment: "Repository syncing state"
                )
            )
            .font(.caption2)
            .foregroundStyle(DesignSystem.Colors.Status.info)
        case .lastSynced(let date):
            Text(date, style: .time)
                .font(.caption2)
                .dsSecondaryText(font: .caption2)
        case .notSynced(let text):
            Text(text)
                .font(.caption2)
                .foregroundStyle(DesignSystem.Colors.Status.warning)
        }
    }
}

// MARK: - RemoteResourceDetailSheetView

public struct RemoteResourceDetailSheetView: View {
    public struct Config {
        public var data: RemoteResourceDetailData
        public var onInstall: (String) -> Void
        public var onClose: () -> Void

        public init(
            data: RemoteResourceDetailData,
            onInstall: @escaping (String) -> Void,
            onClose: @escaping () -> Void
        ) {
            self.data = data
            self.onInstall = onInstall
            self.onClose = onClose
        }
    }

    private let data: RemoteResourceDetailData
    private let onInstall: (String) -> Void
    private let onClose: () -> Void

    @State private var selectedProviderID: String?

    public init(config: Config) {
        self.data = config.data
        self.onInstall = config.onInstall
        self.onClose = config.onClose
        _selectedProviderID = State(initialValue: config.data.preferredProviderID)
    }

    public init(
        config: RemoteResourceDetailSheetConfig,
        onInstall: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                data: config.data,
                onInstall: onInstall,
                onClose: onClose
            )
        )
    }

    public init(
        data: RemoteResourceDetailData,
        onInstall: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                data: data,
                onInstall: onInstall,
                onClose: onClose
            )
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            NolonUI.SheetHeaderView(
                title: data.title,
                subtitle: data.subtitle
            ) {
                onClose()
            }

            SheetDivider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !data.stats.isEmpty {
                        statsSection
                    }
                    ForEach(data.sections, id: \.id) { section in
                        sectionView(section)
                    }
                }
                .padding(.horizontal, SheetLayout.horizontalPadding)
                .padding(.vertical, SheetLayout.contentVerticalPadding)
            }

            SheetDivider()

            footer
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.headline)

            HStack(spacing: 20) {
                ForEach(data.stats) { stat in
                    Label(stat.title, systemImage: stat.systemImage)
                        .dsIconLabelText(foreground: statColor(stat), font: .callout)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionView(_ section: RemoteResourceDetailData.Section) -> some View {
        switch section {
        case let .markdown(_, title, content):
            if !content.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)
                    Text(content)
                        .font(.body)
                        .dsSecondaryText(font: .body)
                }
            }
        case let .codeBlock(_, title, content):
            if !content.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(content)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .dsCard(
                            background: DesignSystem.Colors.Component.controlFillSubtle,
                            cornerRadius: DesignSystem.Metrics.cornerRadiusS
                        )
                }
            }
        case let .list(_, title, items, monospaced):
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(items, id: \.self) { item in
                            Text("• \(item)")
                                .font(monospaced ? .system(.caption, design: .monospaced) : .caption)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .dsCard(
                        background: DesignSystem.Colors.Component.controlFillSubtle,
                        cornerRadius: DesignSystem.Metrics.cornerRadiusS
                    )
                }
            }
        case let .kvList(_, title, items, monospaced):
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(items, id: \.self) { item in
                            Text(item)
                                .font(monospaced ? .system(.caption, design: .monospaced) : .caption)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .dsCard(
                        background: DesignSystem.Colors.Component.controlFillSubtle,
                        cornerRadius: DesignSystem.Metrics.cornerRadiusS
                    )
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            if let preferredID = data.preferredProviderID,
               let provider = data.providers.first(where: { $0.id == preferredID }) {
                Text("Install to: \(provider.name)")
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
            } else {
                Picker("Install to:", selection: $selectedProviderID) {
                    Text("Select Provider").tag(nil as String?)
                    ForEach(data.providers) { provider in
                        Text(provider.name).tag(provider.id as String?)
                    }
                }
                .labelsHidden()
            }

            Spacer()

            Button("Cancel") {
                onClose()
            }
            .dsLinkButton()
            .keyboardShortcut(.cancelAction)

            Button("Install") {
                guard let providerID = data.preferredProviderID ?? selectedProviderID else { return }
                onInstall(providerID)
                onClose()
            }
            .dsPrimaryButton()
            .keyboardShortcut(.defaultAction)
            .disabled((data.preferredProviderID ?? selectedProviderID) == nil)
        }
        .padding(.horizontal, SheetLayout.footerHorizontalPadding)
        .padding(.vertical, SheetLayout.footerVerticalPadding)
    }

    private func statColor(_ item: RemoteResourceDetailData.StatItem) -> Color {
        if item.systemImage == "star.fill" {
            return DesignSystem.Colors.Status.warning
        }
        return DesignSystem.Colors.Text.secondary
    }
}

public struct RemoteResourceDetailSheetConfig {
    public let data: RemoteResourceDetailData

    public init(data: RemoteResourceDetailData) {
        self.data = data
    }
}

// MARK: - RepositoryScaffoldViews

public struct RepositorySidebarHeaderConfig {
    public let showsHeader: Bool
    public let sheetTitle: String
    public let sidebarTitle: String?

    public init(
        showsHeader: Bool = true,
        sheetTitle: String = NSLocalizedString("Sources", comment: "Sources"),
        sidebarTitle: String? = nil
    ) {
        self.showsHeader = showsHeader
        self.sheetTitle = sheetTitle
        self.sidebarTitle = sidebarTitle
    }
}

public struct RepositorySidebarSyncHUDConfig {
    public let isSyncing: Bool
    public let syncingRepositoryName: String?
    public let completionMessage: String?
    public let completionRepositoryName: String?
    public let completionTone: SyncHUDTone

    public init(
        isSyncing: Bool,
        syncingRepositoryName: String?,
        completionMessage: String?,
        completionRepositoryName: String?,
        completionTone: SyncHUDTone
    ) {
        self.isSyncing = isSyncing
        self.syncingRepositoryName = syncingRepositoryName
        self.completionMessage = completionMessage
        self.completionRepositoryName = completionRepositoryName
        self.completionTone = completionTone
    }
}

public struct RepositorySidebarListConfig {
    public let sections: [RepositorySidebarSectionData]
    public let collapsedSectionIDs: Set<String>
    public let bottomPadding: CGFloat

    public init(
        sections: [RepositorySidebarSectionData],
        collapsedSectionIDs: Set<String>,
        bottomPadding: CGFloat = 52
    ) {
        self.sections = sections
        self.collapsedSectionIDs = collapsedSectionIDs
        self.bottomPadding = bottomPadding
    }
}

public struct RepositorySidebarActionConfig {
    public let addButtonTitle: String

    public init(
        addButtonTitle: String = NSLocalizedString("Add Repository", comment: "Add Repository")
    ) {
        self.addButtonTitle = addButtonTitle
    }
}

public struct RepositorySidebarScaffoldView<RowContextMenu: View>: View {
    public struct Config {
        public var header: RepositorySidebarHeaderConfig
        public var selectedRowID: Binding<String?>
        public var list: RepositorySidebarListConfig
        public var actions: RepositorySidebarActionConfig
        public var syncHUD: RepositorySidebarSyncHUDConfig
        public var onToggleSection: (String) -> Void
        public var onDeleteRows: (String, IndexSet) -> Void
        public var onTapAddButton: () -> Void
        public var rowContextMenu: (RepositorySidebarRowData) -> RowContextMenu

        public init(
            header: RepositorySidebarHeaderConfig = RepositorySidebarHeaderConfig(),
            selectedRowID: Binding<String?>,
            list: RepositorySidebarListConfig,
            actions: RepositorySidebarActionConfig = RepositorySidebarActionConfig(),
            syncHUD: RepositorySidebarSyncHUDConfig,
            onToggleSection: @escaping (String) -> Void,
            onDeleteRows: @escaping (String, IndexSet) -> Void,
            onTapAddButton: @escaping () -> Void,
            @ViewBuilder rowContextMenu: @escaping (RepositorySidebarRowData) -> RowContextMenu
        ) {
            self.header = header
            self.selectedRowID = selectedRowID
            self.list = list
            self.actions = actions
            self.syncHUD = syncHUD
            self.onToggleSection = onToggleSection
            self.onDeleteRows = onDeleteRows
            self.onTapAddButton = onTapAddButton
            self.rowContextMenu = rowContextMenu
        }
    }

    let header: RepositorySidebarHeaderConfig
    @Binding var selectedRowID: String?
    let list: RepositorySidebarListConfig
    let actions: RepositorySidebarActionConfig
    let syncHUD: RepositorySidebarSyncHUDConfig
    let onToggleSection: (String) -> Void
    let onDeleteRows: (String, IndexSet) -> Void
    let onTapAddButton: () -> Void
    let rowContextMenu: (RepositorySidebarRowData) -> RowContextMenu

    public init(config: Config) {
        self.header = config.header
        self._selectedRowID = config.selectedRowID
        self.list = config.list
        self.actions = config.actions
        self.syncHUD = config.syncHUD
        self.onToggleSection = config.onToggleSection
        self.onDeleteRows = config.onDeleteRows
        self.onTapAddButton = config.onTapAddButton
        self.rowContextMenu = config.rowContextMenu
    }

    public init(
        header: RepositorySidebarHeaderConfig = RepositorySidebarHeaderConfig(),
        selectedRowID: Binding<String?>,
        list: RepositorySidebarListConfig,
        actions: RepositorySidebarActionConfig = RepositorySidebarActionConfig(),
        syncHUD: RepositorySidebarSyncHUDConfig,
        onToggleSection: @escaping (String) -> Void,
        onDeleteRows: @escaping (String, IndexSet) -> Void,
        onTapAddButton: @escaping () -> Void,
        @ViewBuilder rowContextMenu: @escaping (RepositorySidebarRowData) -> RowContextMenu
    ) {
        self.init(
            config: Config(
                header: header,
                selectedRowID: selectedRowID,
                list: list,
                actions: actions,
                syncHUD: syncHUD,
                onToggleSection: onToggleSection,
                onDeleteRows: onDeleteRows,
                onTapAddButton: onTapAddButton,
                rowContextMenu: rowContextMenu
            )
        )
    }

    public init(
        showsHeader: Bool = true,
        sheetTitle: String = NSLocalizedString("Sources", comment: "Sources"),
        sidebarTitle: String? = nil,
        selectedRowID: Binding<String?>,
        sections: [RepositorySidebarSectionData],
        collapsedSectionIDs: Set<String>,
        addButtonTitle: String = NSLocalizedString("Add Repository", comment: "Add Repository"),
        isSyncing: Bool,
        syncingRepositoryName: String?,
        syncCompletionMessage: String?,
        syncCompletionRepositoryName: String?,
        syncCompletionTone: SyncHUDTone,
        onToggleSection: @escaping (String) -> Void,
        onDeleteRows: @escaping (String, IndexSet) -> Void,
        onTapAddButton: @escaping () -> Void,
        @ViewBuilder rowContextMenu: @escaping (RepositorySidebarRowData) -> RowContextMenu
    ) {
        self.init(
            header: RepositorySidebarHeaderConfig(
                showsHeader: showsHeader,
                sheetTitle: sheetTitle,
                sidebarTitle: sidebarTitle
            ),
            selectedRowID: selectedRowID,
            list: RepositorySidebarListConfig(
                sections: sections,
                collapsedSectionIDs: collapsedSectionIDs
            ),
            actions: RepositorySidebarActionConfig(
                addButtonTitle: addButtonTitle
            ),
            syncHUD: RepositorySidebarSyncHUDConfig(
                isSyncing: isSyncing,
                syncingRepositoryName: syncingRepositoryName,
                completionMessage: syncCompletionMessage,
                completionRepositoryName: syncCompletionRepositoryName,
                completionTone: syncCompletionTone
            ),
            onToggleSection: onToggleSection,
            onDeleteRows: onDeleteRows,
            onTapAddButton: onTapAddButton,
            rowContextMenu: rowContextMenu
        )
    }

    public var body: some View {
        SidebarHeaderScaffold(
            showsSheetHeader: header.showsHeader,
            sheetTitle: header.sheetTitle,
            sidebarTitle: header.sidebarTitle
        ) {
            RepositorySidebarListView(
                selectedRowID: $selectedRowID,
                list: list,
                onToggleSection: onToggleSection,
                onDeleteRows: onDeleteRows,
                rowContextMenu: rowContextMenu
            )
        }
        .bottomTrailingOverlay(isPresented: true, trailing: 12, bottom: 12) {
            RepositoryFloatingAddButton(
                title: actions.addButtonTitle,
                action: onTapAddButton
            )
        }
        .overlay(alignment: .top) {
            RepositorySyncHUDOverlay(
                isSyncing: syncHUD.isSyncing,
                syncingRepositoryName: syncHUD.syncingRepositoryName,
                completionMessage: syncHUD.completionMessage,
                completionRepositoryName: syncHUD.completionRepositoryName,
                completionTone: syncHUD.completionTone
            )
        }
    }
}


public struct RepositorySidebarListView<RowContextMenu: View>: View {
    public struct Config {
        public var selectedRowID: Binding<String?>
        public var list: RepositorySidebarListConfig
        public var onToggleSection: (String) -> Void
        public var onDeleteRows: (String, IndexSet) -> Void
        public var rowContextMenu: (RepositorySidebarRowData) -> RowContextMenu

        public init(
            selectedRowID: Binding<String?>,
            list: RepositorySidebarListConfig,
            onToggleSection: @escaping (String) -> Void,
            onDeleteRows: @escaping (String, IndexSet) -> Void,
            @ViewBuilder rowContextMenu: @escaping (RepositorySidebarRowData) -> RowContextMenu
        ) {
            self.selectedRowID = selectedRowID
            self.list = list
            self.onToggleSection = onToggleSection
            self.onDeleteRows = onDeleteRows
            self.rowContextMenu = rowContextMenu
        }
    }

    @Binding var selectedRowID: String?

    let list: RepositorySidebarListConfig
    let onToggleSection: (String) -> Void
    let onDeleteRows: (String, IndexSet) -> Void
    let rowContextMenu: (RepositorySidebarRowData) -> RowContextMenu

    public init(config: Config) {
        self._selectedRowID = config.selectedRowID
        self.list = config.list
        self.onToggleSection = config.onToggleSection
        self.onDeleteRows = config.onDeleteRows
        self.rowContextMenu = config.rowContextMenu
    }

    public init(
        selectedRowID: Binding<String?>,
        list: RepositorySidebarListConfig,
        onToggleSection: @escaping (String) -> Void,
        onDeleteRows: @escaping (String, IndexSet) -> Void,
        @ViewBuilder rowContextMenu: @escaping (RepositorySidebarRowData) -> RowContextMenu
    ) {
        self.init(
            config: Config(
                selectedRowID: selectedRowID,
                list: list,
                onToggleSection: onToggleSection,
                onDeleteRows: onDeleteRows,
                rowContextMenu: rowContextMenu
            )
        )
    }

    public init(
        selectedRowID: Binding<String?>,
        sections: [RepositorySidebarSectionData],
        collapsedSectionIDs: Set<String>,
        bottomPadding: CGFloat = 52,
        onToggleSection: @escaping (String) -> Void,
        onDeleteRows: @escaping (String, IndexSet) -> Void,
        @ViewBuilder rowContextMenu: @escaping (RepositorySidebarRowData) -> RowContextMenu
    ) {
        self.init(
            selectedRowID: selectedRowID,
            list: RepositorySidebarListConfig(
                sections: sections,
                collapsedSectionIDs: collapsedSectionIDs,
                bottomPadding: bottomPadding
            ),
            onToggleSection: onToggleSection,
            onDeleteRows: onDeleteRows,
            rowContextMenu: rowContextMenu
        )
    }

    public var body: some View {
        List(selection: $selectedRowID) {
            ForEach(list.sections) { section in
                Section {
                    RepositorySidebarSectionToggleRow(
                        title: section.title,
                        isCollapsed: list.collapsedSectionIDs.contains(section.id)
                    ) {
                        onToggleSection(section.id)
                    }

                    if !list.collapsedSectionIDs.contains(section.id) {
                        ForEach(section.rows) { row in
                            RepositorySidebarRowView(data: row)
                                .tag(Optional(row.id))
                                .contextMenu {
                                    rowContextMenu(row)
                                }
                        }
                        .onDelete { offsets in
                            onDeleteRows(section.id, offsets)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .animation(.snappy(duration: 0.2), value: list.collapsedSectionIDs)
        .padding(.bottom, list.bottomPadding)
    }
}


public struct RepositoryEditorSheetScaffoldView<Content: View, Footer: View>: View {
    public struct Config {
        public var isBlocking: Bool
        public var blockingMessage: String
        public var content: () -> Content
        public var footer: () -> Footer

        public init(
            isBlocking: Bool,
            blockingMessage: String = NSLocalizedString(
                "repository.editor.blocking.adding",
                value: "Adding repository...",
                comment: "Repository editor blocking message while adding"
            ),
            @ViewBuilder content: @escaping () -> Content,
            @ViewBuilder footer: @escaping () -> Footer
        ) {
            self.isBlocking = isBlocking
            self.blockingMessage = blockingMessage
            self.content = content
            self.footer = footer
        }

        public init(
            config: RepositoryEditorBlockingConfig,
            @ViewBuilder content: @escaping () -> Content,
            @ViewBuilder footer: @escaping () -> Footer
        ) {
            self.isBlocking = config.isBlocking
            self.blockingMessage = config.blockingMessage
            self.content = content
            self.footer = footer
        }
    }

    let isBlocking: Bool
    let blockingMessage: String
    let content: () -> Content
    let footer: () -> Footer

    public init(config: Config) {
        self.isBlocking = config.isBlocking
        self.blockingMessage = config.blockingMessage
        self.content = config.content
        self.footer = config.footer
    }

    public init(
        config: RepositoryEditorBlockingConfig,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.init(config: Config(config: config, content: content, footer: footer))
    }

    public init(
        isBlocking: Bool,
        blockingMessage: String = NSLocalizedString(
            "repository.editor.blocking.adding",
            value: "Adding repository...",
            comment: "Repository editor blocking message while adding"
        ),
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.init(
            config: Config(
                isBlocking: isBlocking,
                blockingMessage: blockingMessage,
                content: content,
                footer: footer
            )
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                content()
                    .padding(.horizontal, SheetLayout.horizontalPadding)
                    .padding(.top, SheetLayout.contentVerticalPadding)
                    .padding(.bottom, SheetLayout.contentBottomPadding)
            }

            SheetDivider()

            footer()
        }
        .frame(width: 640, height: 600)
        .textSelection(.enabled)
        .dsGlassPanel()
        .overlay {
            if isBlocking {
                BlockingProgressOverlayView(message: blockingMessage)
            }
        }
    }
}

public struct RepositoryEditorBlockingConfig {
    public let isBlocking: Bool
    public let blockingMessage: String

    public init(
        isBlocking: Bool,
        blockingMessage: String = NSLocalizedString(
            "repository.editor.blocking.adding",
            value: "Adding repository...",
            comment: "Repository editor blocking message while adding"
        )
    ) {
        self.isBlocking = isBlocking
        self.blockingMessage = blockingMessage
    }
}


public struct RepositoryEditorFormContentView: View {
    public struct Config {
        public var templateOptions: [RepositoryTemplateOptionItem]
        public var selectedTemplateID: Binding<String>
        public var isTemplateSelectionDisabled: Bool
        public var detailData: RepositoryTemplateDetailData
        public var gitURL: Binding<String>
        public var onPasteGitURL: () -> Void
        public var onTapSelectLocalFolder: () -> Void
        public var onDropLocalFolderURLs: ([URL]) -> Bool

        public init(
            templateOptions: [RepositoryTemplateOptionItem],
            selectedTemplateID: Binding<String>,
            isTemplateSelectionDisabled: Bool,
            detailData: RepositoryTemplateDetailData,
            gitURL: Binding<String>,
            onPasteGitURL: @escaping () -> Void,
            onTapSelectLocalFolder: @escaping () -> Void,
            onDropLocalFolderURLs: @escaping ([URL]) -> Bool
        ) {
            self.templateOptions = templateOptions
            self.selectedTemplateID = selectedTemplateID
            self.isTemplateSelectionDisabled = isTemplateSelectionDisabled
            self.detailData = detailData
            self.gitURL = gitURL
            self.onPasteGitURL = onPasteGitURL
            self.onTapSelectLocalFolder = onTapSelectLocalFolder
            self.onDropLocalFolderURLs = onDropLocalFolderURLs
        }

        public init(
            config: RepositoryEditorFormConfig,
            selectedTemplateID: Binding<String>,
            gitURL: Binding<String>,
            onPasteGitURL: @escaping () -> Void,
            onTapSelectLocalFolder: @escaping () -> Void,
            onDropLocalFolderURLs: @escaping ([URL]) -> Bool
        ) {
            self.templateOptions = config.templateOptions
            self.selectedTemplateID = selectedTemplateID
            self.isTemplateSelectionDisabled = config.isTemplateSelectionDisabled
            self.detailData = config.detailData
            self.gitURL = gitURL
            self.onPasteGitURL = onPasteGitURL
            self.onTapSelectLocalFolder = onTapSelectLocalFolder
            self.onDropLocalFolderURLs = onDropLocalFolderURLs
        }
    }

    let templateOptions: [RepositoryTemplateOptionItem]
    @Binding var selectedTemplateID: String
    let isTemplateSelectionDisabled: Bool
    let detailData: RepositoryTemplateDetailData
    @Binding var gitURL: String
    let onPasteGitURL: () -> Void
    let onTapSelectLocalFolder: () -> Void
    let onDropLocalFolderURLs: ([URL]) -> Bool

    public init(config: Config) {
        self.templateOptions = config.templateOptions
        self._selectedTemplateID = config.selectedTemplateID
        self.isTemplateSelectionDisabled = config.isTemplateSelectionDisabled
        self.detailData = config.detailData
        self._gitURL = config.gitURL
        self.onPasteGitURL = config.onPasteGitURL
        self.onTapSelectLocalFolder = config.onTapSelectLocalFolder
        self.onDropLocalFolderURLs = config.onDropLocalFolderURLs
    }

    public init(
        config: RepositoryEditorFormConfig,
        selectedTemplateID: Binding<String>,
        gitURL: Binding<String>,
        onPasteGitURL: @escaping () -> Void,
        onTapSelectLocalFolder: @escaping () -> Void,
        onDropLocalFolderURLs: @escaping ([URL]) -> Bool
    ) {
        self.init(
            config: Config(
                config: config,
                selectedTemplateID: selectedTemplateID,
                gitURL: gitURL,
                onPasteGitURL: onPasteGitURL,
                onTapSelectLocalFolder: onTapSelectLocalFolder,
                onDropLocalFolderURLs: onDropLocalFolderURLs
            )
        )
    }

    public init(
        templateOptions: [RepositoryTemplateOptionItem],
        selectedTemplateID: Binding<String>,
        isTemplateSelectionDisabled: Bool,
        detailData: RepositoryTemplateDetailData,
        gitURL: Binding<String>,
        onPasteGitURL: @escaping () -> Void,
        onTapSelectLocalFolder: @escaping () -> Void,
        onDropLocalFolderURLs: @escaping ([URL]) -> Bool
    ) {
        self.init(
            config: Config(
                templateOptions: templateOptions,
                selectedTemplateID: selectedTemplateID,
                isTemplateSelectionDisabled: isTemplateSelectionDisabled,
                detailData: detailData,
                gitURL: gitURL,
                onPasteGitURL: onPasteGitURL,
                onTapSelectLocalFolder: onTapSelectLocalFolder,
                onDropLocalFolderURLs: onDropLocalFolderURLs
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            RepositoryTemplateSelectionView(
                options: templateOptions,
                selectedID: $selectedTemplateID,
                disabled: isTemplateSelectionDisabled
            )

            templateDetailSection
        }
    }

    @ViewBuilder
    private var templateDetailSection: some View {
        switch detailData.templateKind {
        case .clawdhub:
            FormSectionBlockView(title: detailData.detailsSectionTitle) {
                RepositoryReadOnlyFieldView(value: detailData.clawdhubBaseURL)
                FormSecondaryHintText(detailData.clawdhubHint)
            }
        case .localFolder:
            FormSectionBlockView(title: detailData.skillsFolderSectionTitle) {
                FolderDropPickerCardView(
                    displayText: detailData.localFolderDisplayText,
                    placeholderText: detailData.localFolderPlaceholderText,
                    hintText: detailData.localFolderHintText,
                    onTap: onTapSelectLocalFolder,
                    onDropURLs: onDropLocalFolderURLs
                )
                FormSecondaryHintText(detailData.localFolderSecondaryHint)
            }
        case .git:
            VStack(alignment: .leading, spacing: 20) {
                FormSectionBlockView(title: detailData.gitRepositorySectionTitle) {
                    RepositoryGitURLInputRowView(
                        gitURL: $gitURL,
                        providerDisplayName: detailData.gitProviderDisplayName,
                        providerLogoName: detailData.gitProviderLogoName,
                        onPaste: onPasteGitURL
                    )

                    FormSecondaryHintText(detailData.gitSupportHint)
                }

                FormSecondaryHintText(detailData.gitSyncHint)
            }
        }
    }
}

public struct RepositoryEditorFormConfig {
    public let templateOptions: [RepositoryTemplateOptionItem]
    public let isTemplateSelectionDisabled: Bool
    public let detailData: RepositoryTemplateDetailData

    public init(
        templateOptions: [RepositoryTemplateOptionItem],
        isTemplateSelectionDisabled: Bool,
        detailData: RepositoryTemplateDetailData
    ) {
        self.templateOptions = templateOptions
        self.isTemplateSelectionDisabled = isTemplateSelectionDisabled
        self.detailData = detailData
    }
}


public struct RepositoryEditorFooterView: View {
    public struct Config {
        public var data: RepositoryEditorFooterData
        public var onCancel: () -> Void
        public var onPrimary: () -> Void

        public init(
            data: RepositoryEditorFooterData,
            onCancel: @escaping () -> Void,
            onPrimary: @escaping () -> Void
        ) {
            self.data = data
            self.onCancel = onCancel
            self.onPrimary = onPrimary
        }
    }

    let data: RepositoryEditorFooterData
    let onCancel: () -> Void
    let onPrimary: () -> Void

    public init(config: Config) {
        self.data = config.data
        self.onCancel = config.onCancel
        self.onPrimary = config.onPrimary
    }

    public init(
        data: RepositoryEditorFooterData,
        onCancel: @escaping () -> Void,
        onPrimary: @escaping () -> Void
    ) {
        self.init(config: Config(data: data, onCancel: onCancel, onPrimary: onPrimary))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let errorMessage = data.errorMessage {
                Text(errorMessage)
                    .dsErrorText(font: .system(size: 12))
                    .lineLimit(2)
                    .textSelection(.enabled)
                    .padding(.horizontal, SheetLayout.footerHorizontalPadding)
            }

            SheetActionFooterView(
                cancelTitle: data.cancelTitle,
                primaryTitle: data.primaryTitle,
                isPrimaryDisabled: data.isPrimaryDisabled,
                onCancel: onCancel,
                onPrimary: onPrimary
            )
        }
    }
}


private struct RepositorySidebarSheetPresenterModifier<
    AddSheetContent: View,
    DirectoryPickerSheetContent: View,
    TokenInputSheetContent: View,
    EditingItem: Identifiable,
    EditSheetContent: View
>: ViewModifier {
    @Binding var isAddingRepositoryPresented: Bool
    let addRepositorySheet: () -> AddSheetContent
    @Binding var isDirectoryPickerPresented: Bool
    let directoryPickerSheet: () -> DirectoryPickerSheetContent
    @Binding var isTokenInputPresented: Bool
    let tokenInputSheet: () -> TokenInputSheetContent
    @Binding var editingItem: EditingItem?
    let editRepositorySheet: (EditingItem) -> EditSheetContent

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isAddingRepositoryPresented) {
                addRepositorySheet()
            }
            .sheet(isPresented: $isDirectoryPickerPresented) {
                directoryPickerSheet()
            }
            .sheet(isPresented: $isTokenInputPresented) {
                tokenInputSheet()
            }
            .sheet(item: $editingItem) { item in
                editRepositorySheet(item)
            }
    }
}

public extension View {
    func repositorySidebarSheetPresenters<
        AddSheetContent: View,
        DirectoryPickerSheetContent: View,
        TokenInputSheetContent: View,
        EditingItem: Identifiable,
        EditSheetContent: View
    >(
        isAddingRepositoryPresented: Binding<Bool>,
        @ViewBuilder addRepositorySheet: @escaping () -> AddSheetContent,
        isDirectoryPickerPresented: Binding<Bool>,
        @ViewBuilder directoryPickerSheet: @escaping () -> DirectoryPickerSheetContent,
        isTokenInputPresented: Binding<Bool>,
        @ViewBuilder tokenInputSheet: @escaping () -> TokenInputSheetContent,
        editingItem: Binding<EditingItem?>,
        @ViewBuilder editRepositorySheet: @escaping (EditingItem) -> EditSheetContent
    ) -> some View {
        modifier(
            RepositorySidebarSheetPresenterModifier(
                isAddingRepositoryPresented: isAddingRepositoryPresented,
                addRepositorySheet: addRepositorySheet,
                isDirectoryPickerPresented: isDirectoryPickerPresented,
                directoryPickerSheet: directoryPickerSheet,
                isTokenInputPresented: isTokenInputPresented,
                tokenInputSheet: tokenInputSheet,
                editingItem: editingItem,
                editRepositorySheet: editRepositorySheet
            )
        )
    }
}


// MARK: - ResourceCatalogLoadMoreViews

public struct ResourceCatalogLoadMoreFooterView<Content: View>: View {
    public struct Config {
        public var content: () -> Content

        public init(@ViewBuilder content: @escaping () -> Content) {
            self.content = content
        }
    }

    let content: () -> Content

    public init(config: Config) {
        self.content = config.content
    }

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.init(config: Config(content: content))
    }

    public var body: some View {
        HStack {
            Spacer(minLength: 0)
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

public struct ResourceCatalogLoadMoreStateView: View {
    public struct Config {
        public var isEnabled: Bool
        public var loadMoreErrorMessage: String?
        public var canLoadMore: Bool
        public var isLoadingMore: Bool
        public var isLoading: Bool
        public var hasAnyContent: Bool
        public var retryTitle: String
        public var loadMoreTitle: String
        public var loadingTitle: String
        public var endTitle: String
        public var onLoadMore: () -> Void

        public init(
            isEnabled: Bool,
            loadMoreErrorMessage: String?,
            canLoadMore: Bool,
            isLoadingMore: Bool,
            isLoading: Bool,
            hasAnyContent: Bool,
            retryTitle: String = NSLocalizedString("remote.retry", value: "Retry", comment: "Retry"),
            loadMoreTitle: String = NSLocalizedString("remote.load_more", value: "Load More", comment: "Load more"),
            loadingTitle: String = NSLocalizedString("remote.load_more.loading", value: "Loading...", comment: "Loading more indicator"),
            endTitle: String = NSLocalizedString("remote.load_more.end", value: "You have reached the end.", comment: "End of list"),
            onLoadMore: @escaping () -> Void
        ) {
            self.isEnabled = isEnabled
            self.loadMoreErrorMessage = loadMoreErrorMessage
            self.canLoadMore = canLoadMore
            self.isLoadingMore = isLoadingMore
            self.isLoading = isLoading
            self.hasAnyContent = hasAnyContent
            self.retryTitle = retryTitle
            self.loadMoreTitle = loadMoreTitle
            self.loadingTitle = loadingTitle
            self.endTitle = endTitle
            self.onLoadMore = onLoadMore
        }
    }

    let isEnabled: Bool
    let loadMoreErrorMessage: String?
    let canLoadMore: Bool
    let isLoadingMore: Bool
    let isLoading: Bool
    let hasAnyContent: Bool
    let retryTitle: String
    let loadMoreTitle: String
    let loadingTitle: String
    let endTitle: String
    let onLoadMore: () -> Void

    public init(config: Config) {
        self.isEnabled = config.isEnabled
        self.loadMoreErrorMessage = config.loadMoreErrorMessage
        self.canLoadMore = config.canLoadMore
        self.isLoadingMore = config.isLoadingMore
        self.isLoading = config.isLoading
        self.hasAnyContent = config.hasAnyContent
        self.retryTitle = config.retryTitle
        self.loadMoreTitle = config.loadMoreTitle
        self.loadingTitle = config.loadingTitle
        self.endTitle = config.endTitle
        self.onLoadMore = config.onLoadMore
    }

    public init(
        isEnabled: Bool,
        loadMoreErrorMessage: String?,
        canLoadMore: Bool,
        isLoadingMore: Bool,
        isLoading: Bool,
        hasAnyContent: Bool,
        retryTitle: String = NSLocalizedString("remote.retry", value: "Retry", comment: "Retry"),
        loadMoreTitle: String = NSLocalizedString("remote.load_more", value: "Load More", comment: "Load more"),
        loadingTitle: String = NSLocalizedString("remote.load_more.loading", value: "Loading...", comment: "Loading more indicator"),
        endTitle: String = NSLocalizedString("remote.load_more.end", value: "You have reached the end.", comment: "End of list"),
        onLoadMore: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                isEnabled: isEnabled,
                loadMoreErrorMessage: loadMoreErrorMessage,
                canLoadMore: canLoadMore,
                isLoadingMore: isLoadingMore,
                isLoading: isLoading,
                hasAnyContent: hasAnyContent,
                retryTitle: retryTitle,
                loadMoreTitle: loadMoreTitle,
                loadingTitle: loadingTitle,
                endTitle: endTitle,
                onLoadMore: onLoadMore
            )
        )
    }

    public var body: some View {
        if !isEnabled {
            EmptyView()
        } else if let message = loadMoreErrorMessage, !message.isEmpty {
            ResourceCatalogLoadMoreFooterView {
                VStack(spacing: 8) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Status.error)
                        .multilineTextAlignment(.center)
                    Button(action: onLoadMore) {
                        Text(retryTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .frame(maxWidth: 220)
                }
            }
        } else if canLoadMore {
            ResourceCatalogLoadMoreFooterView {
                Button(action: onLoadMore) {
                    HStack(spacing: 8) {
                        if isLoadingMore {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DesignSystem.Colors.Status.info)
                        }
                        Text(isLoadingMore ? loadingTitle : loadMoreTitle)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingMore)
                .frame(maxWidth: 240)
                .onAppear {
                    guard !isLoadingMore else { return }
                    onLoadMore()
                }
            }
        } else if !isLoading && hasAnyContent {
            ResourceCatalogLoadMoreFooterView {
                Text(endTitle)
                    .dsSecondaryText(font: .callout)
            }
        }
    }
}
