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
                        .lineLimit(1)

                    if let secondaryText = data.secondaryText {
                        Text(secondaryText)
                            .font(.caption)
                            .dsSecondaryText(font: .caption)
                            .lineLimit(1)
                    }

                    if data.showGitStatus, let syncStatus = data.syncStatus {
                        gitStatusView(syncStatus)
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
    private func gitStatusView(_ status: RepositorySyncStatusData) -> some View {
        switch status {
        case .syncing:
            RepositoryGitSyncStatusRow(
                isSyncing: true,
                lastSyncDate: nil,
                notSyncedText: ""
            )
        case .lastSynced(let date):
            RepositoryGitSyncStatusRow(
                isSyncing: false,
                lastSyncDate: date,
                notSyncedText: ""
            )
        case .notSynced(let text):
            RepositoryGitSyncStatusRow(
                isSyncing: false,
                lastSyncDate: nil,
                notSyncedText: text
            )
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

// MARK: - ResourceCatalogTabScaffolds


public struct ResourceCatalogTabEmptyStateScaffold<Content: View>: View {
    public struct Config {
        public var isEmpty: Bool
        public var searchText: String
        public var emptyState: ResourceCatalogTabEmptyStateConfig
        public var content: () -> Content

        public init(
            isEmpty: Bool,
            searchText: String,
            emptyState: ResourceCatalogTabEmptyStateConfig,
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.isEmpty = isEmpty
            self.searchText = searchText
            self.emptyState = emptyState
            self.content = content
        }
    }

    let isEmpty: Bool
    let searchText: String
    let emptyTitle: String
    let emptySystemImage: String
    let emptyDescription: String
    let noResultsTitle: String
    let noResultsSystemImage: String
    let noResultsDescription: String
    let content: () -> Content

    public init(config: Config) {
        self.isEmpty = config.isEmpty
        self.searchText = config.searchText
        self.emptyTitle = config.emptyState.emptyTitle
        self.emptySystemImage = config.emptyState.emptySystemImage
        self.emptyDescription = config.emptyState.emptyDescription
        self.noResultsTitle = config.emptyState.noResultsTitle
        self.noResultsSystemImage = config.emptyState.noResultsSystemImage
        self.noResultsDescription = config.emptyState.noResultsDescription
        self.content = config.content
    }

    public init(
        isEmpty: Bool,
        searchText: String,
        emptyState: ResourceCatalogTabEmptyStateConfig,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                isEmpty: isEmpty,
                searchText: searchText,
                emptyState: emptyState,
                content: content
            )
        )
    }

    public init(
        isEmpty: Bool,
        searchText: String,
        emptyTitle: String,
        emptySystemImage: String,
        emptyDescription: String,
        noResultsTitle: String,
        noResultsSystemImage: String = "magnifyingglass",
        noResultsDescription: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isEmpty = isEmpty
        self.searchText = searchText
        self.emptyTitle = emptyTitle
        self.emptySystemImage = emptySystemImage
        self.emptyDescription = emptyDescription
        self.noResultsTitle = noResultsTitle
        self.noResultsSystemImage = noResultsSystemImage
        self.noResultsDescription = noResultsDescription
        self.content = content
    }

    public var body: some View {
        ProviderEmptyStateScaffold(
            isEmpty: isEmpty,
            emptyTitle: searchText.isEmpty ? emptyTitle : noResultsTitle,
            emptySystemImage: searchText.isEmpty ? emptySystemImage : noResultsSystemImage,
            emptyDescription: searchText.isEmpty ? emptyDescription : noResultsDescription
        ) {
            content()
        }
    }
}

public struct ResourceCatalogTabEmptyStateConfig: Sendable, Hashable {
    public let emptyTitle: String
    public let emptySystemImage: String
    public let emptyDescription: String
    public let noResultsTitle: String
    public let noResultsSystemImage: String
    public let noResultsDescription: String

    public init(
        emptyTitle: String,
        emptySystemImage: String,
        emptyDescription: String,
        noResultsTitle: String,
        noResultsSystemImage: String,
        noResultsDescription: String
    ) {
        self.emptyTitle = emptyTitle
        self.emptySystemImage = emptySystemImage
        self.emptyDescription = emptyDescription
        self.noResultsTitle = noResultsTitle
        self.noResultsSystemImage = noResultsSystemImage
        self.noResultsDescription = noResultsDescription
    }
}

public struct ResourceCatalogTabSectionTitles: Sendable, Hashable {
    public let installedTitle: String
    public let installingTitle: String
    public let availableTitle: String

    public init(
        installedTitle: String,
        installingTitle: String,
        availableTitle: String
    ) {
        self.installedTitle = installedTitle
        self.installingTitle = installingTitle
        self.availableTitle = availableTitle
    }

    public static let standard = ResourceCatalogTabSectionTitles(
        installedTitle: NSLocalizedString("remote.section.installed", value: "Installed", comment: "Installed section"),
        installingTitle: NSLocalizedString("remote.section.installing", value: "Installing", comment: "Installing section"),
        availableTitle: NSLocalizedString("remote.section.available", value: "Available", comment: "Available section")
    )
}


public struct ResourceCatalogTabStateSectionsScaffold<
    Item: Identifiable,
    InstalledContent: View,
    InstallingContent: View,
    AvailableContent: View,
    FooterContent: View
>: View {
    public struct Config {
        public var isEmpty: Bool
        public var searchText: String
        public var emptyState: ResourceCatalogTabEmptyStateConfig
        public var sectionTitles: ResourceCatalogTabSectionTitles
        public var installedItems: [Item]
        public var installingItems: [Item]
        public var availableItems: [Item]
        public var columns: [GridItem]
        public var installedContent: (Item) -> InstalledContent
        public var installingContent: (Item) -> InstallingContent
        public var availableContent: (Item) -> AvailableContent
        public var footerContent: () -> FooterContent

        public init(
            isEmpty: Bool,
            searchText: String,
            emptyState: ResourceCatalogTabEmptyStateConfig,
            sectionTitles: ResourceCatalogTabSectionTitles,
            installedItems: [Item],
            installingItems: [Item],
            availableItems: [Item],
            columns: [GridItem],
            @ViewBuilder installedContent: @escaping (Item) -> InstalledContent,
            @ViewBuilder installingContent: @escaping (Item) -> InstallingContent,
            @ViewBuilder availableContent: @escaping (Item) -> AvailableContent,
            @ViewBuilder footerContent: @escaping () -> FooterContent
        ) {
            self.isEmpty = isEmpty
            self.searchText = searchText
            self.emptyState = emptyState
            self.sectionTitles = sectionTitles
            self.installedItems = installedItems
            self.installingItems = installingItems
            self.availableItems = availableItems
            self.columns = columns
            self.installedContent = installedContent
            self.installingContent = installingContent
            self.availableContent = availableContent
            self.footerContent = footerContent
        }
    }

    let isEmpty: Bool
    let searchText: String
    let emptyTitle: String
    let emptySystemImage: String
    let emptyDescription: String
    let noResultsTitle: String
    let noResultsDescription: String
    let installedTitle: String
    let installingTitle: String
    let availableTitle: String
    let installedItems: [Item]
    let installingItems: [Item]
    let availableItems: [Item]
    let columns: [GridItem]
    let installedContent: (Item) -> InstalledContent
    let installingContent: (Item) -> InstallingContent
    let availableContent: (Item) -> AvailableContent
    let footerContent: () -> FooterContent

    public init(config: Config) {
        self.isEmpty = config.isEmpty
        self.searchText = config.searchText
        self.emptyTitle = config.emptyState.emptyTitle
        self.emptySystemImage = config.emptyState.emptySystemImage
        self.emptyDescription = config.emptyState.emptyDescription
        self.noResultsTitle = config.emptyState.noResultsTitle
        self.noResultsDescription = config.emptyState.noResultsDescription
        self.installedTitle = config.sectionTitles.installedTitle
        self.installingTitle = config.sectionTitles.installingTitle
        self.availableTitle = config.sectionTitles.availableTitle
        self.installedItems = config.installedItems
        self.installingItems = config.installingItems
        self.availableItems = config.availableItems
        self.columns = config.columns
        self.installedContent = config.installedContent
        self.installingContent = config.installingContent
        self.availableContent = config.availableContent
        self.footerContent = config.footerContent
    }

    public init(
        isEmpty: Bool,
        searchText: String,
        emptyState: ResourceCatalogTabEmptyStateConfig,
        sectionTitles: ResourceCatalogTabSectionTitles,
        installedItems: [Item],
        installingItems: [Item],
        availableItems: [Item],
        columns: [GridItem],
        @ViewBuilder installedContent: @escaping (Item) -> InstalledContent,
        @ViewBuilder installingContent: @escaping (Item) -> InstallingContent,
        @ViewBuilder availableContent: @escaping (Item) -> AvailableContent,
        @ViewBuilder footerContent: @escaping () -> FooterContent
    ) {
        self.init(
            config: Config(
                isEmpty: isEmpty,
                searchText: searchText,
                emptyState: emptyState,
                sectionTitles: sectionTitles,
                installedItems: installedItems,
                installingItems: installingItems,
                availableItems: availableItems,
                columns: columns,
                installedContent: installedContent,
                installingContent: installingContent,
                availableContent: availableContent,
                footerContent: footerContent
            )
        )
    }

    public init(
        isEmpty: Bool,
        searchText: String,
        emptyTitle: String,
        emptySystemImage: String,
        emptyDescription: String,
        noResultsTitle: String,
        noResultsDescription: String,
        installedTitle: String,
        installingTitle: String,
        availableTitle: String,
        installedItems: [Item],
        installingItems: [Item],
        availableItems: [Item],
        columns: [GridItem],
        @ViewBuilder installedContent: @escaping (Item) -> InstalledContent,
        @ViewBuilder installingContent: @escaping (Item) -> InstallingContent,
        @ViewBuilder availableContent: @escaping (Item) -> AvailableContent,
        @ViewBuilder footerContent: @escaping () -> FooterContent
    ) {
        self.isEmpty = isEmpty
        self.searchText = searchText
        self.emptyTitle = emptyTitle
        self.emptySystemImage = emptySystemImage
        self.emptyDescription = emptyDescription
        self.noResultsTitle = noResultsTitle
        self.noResultsDescription = noResultsDescription
        self.installedTitle = installedTitle
        self.installingTitle = installingTitle
        self.availableTitle = availableTitle
        self.installedItems = installedItems
        self.installingItems = installingItems
        self.availableItems = availableItems
        self.columns = columns
        self.installedContent = installedContent
        self.installingContent = installingContent
        self.availableContent = availableContent
        self.footerContent = footerContent
    }

    public var body: some View {
        ResourceCatalogTabEmptyStateScaffold(
            isEmpty: isEmpty,
            searchText: searchText,
            emptyState: ResourceCatalogTabEmptyStateConfig(
                emptyTitle: emptyTitle,
                emptySystemImage: emptySystemImage,
                emptyDescription: emptyDescription,
                noResultsTitle: noResultsTitle,
                noResultsSystemImage: "magnifyingglass",
                noResultsDescription: noResultsDescription
            )
        ) {
            ResourceInstallStateSectionsView(
                installedTitle: installedTitle,
                installingTitle: installingTitle,
                availableTitle: availableTitle,
                installedItems: installedItems,
                installingItems: installingItems,
                availableItems: availableItems,
                columns: columns,
                installedContent: installedContent,
                installingContent: installingContent,
                availableContent: availableContent,
                footerContent: footerContent
            )
        }
    }
}


public struct ResourceCatalogStandardTabScaffold<
    Item: Identifiable,
    InstalledContent: View,
    InstallingContent: View,
    AvailableContent: View,
    FooterContent: View
>: View {
    public struct Config {
        public var isEmpty: Bool
        public var searchText: String
        public var emptyTitle: String
        public var emptySystemImage: String
        public var emptyDescription: String
        public var noResultsTitle: String
        public var noResultsDescription: String
        public var installedItems: [Item]
        public var installingItems: [Item]
        public var availableItems: [Item]
        public var columns: [GridItem]
        public var installedContent: (Item) -> InstalledContent
        public var installingContent: (Item) -> InstallingContent
        public var availableContent: (Item) -> AvailableContent
        public var footerContent: () -> FooterContent

        public init(
            isEmpty: Bool,
            searchText: String,
            emptyTitle: String,
            emptySystemImage: String,
            emptyDescription: String,
            noResultsTitle: String = NSLocalizedString("remote.search.no_results", value: "No Results", comment: "No search results"),
            noResultsDescription: String,
            installedItems: [Item],
            installingItems: [Item],
            availableItems: [Item],
            columns: [GridItem],
            @ViewBuilder installedContent: @escaping (Item) -> InstalledContent,
            @ViewBuilder installingContent: @escaping (Item) -> InstallingContent,
            @ViewBuilder availableContent: @escaping (Item) -> AvailableContent,
            @ViewBuilder footerContent: @escaping () -> FooterContent
        ) {
            self.isEmpty = isEmpty
            self.searchText = searchText
            self.emptyTitle = emptyTitle
            self.emptySystemImage = emptySystemImage
            self.emptyDescription = emptyDescription
            self.noResultsTitle = noResultsTitle
            self.noResultsDescription = noResultsDescription
            self.installedItems = installedItems
            self.installingItems = installingItems
            self.availableItems = availableItems
            self.columns = columns
            self.installedContent = installedContent
            self.installingContent = installingContent
            self.availableContent = availableContent
            self.footerContent = footerContent
        }
    }

    let isEmpty: Bool
    let searchText: String
    let emptyTitle: String
    let emptySystemImage: String
    let emptyDescription: String
    let noResultsTitle: String
    let noResultsDescription: String
    let installedItems: [Item]
    let installingItems: [Item]
    let availableItems: [Item]
    let columns: [GridItem]
    let installedContent: (Item) -> InstalledContent
    let installingContent: (Item) -> InstallingContent
    let availableContent: (Item) -> AvailableContent
    let footerContent: () -> FooterContent

    public init(config: Config) {
        self.isEmpty = config.isEmpty
        self.searchText = config.searchText
        self.emptyTitle = config.emptyTitle
        self.emptySystemImage = config.emptySystemImage
        self.emptyDescription = config.emptyDescription
        self.noResultsTitle = config.noResultsTitle
        self.noResultsDescription = config.noResultsDescription
        self.installedItems = config.installedItems
        self.installingItems = config.installingItems
        self.availableItems = config.availableItems
        self.columns = config.columns
        self.installedContent = config.installedContent
        self.installingContent = config.installingContent
        self.availableContent = config.availableContent
        self.footerContent = config.footerContent
    }

    public init(
        isEmpty: Bool,
        searchText: String,
        emptyTitle: String,
        emptySystemImage: String,
        emptyDescription: String,
        noResultsTitle: String = NSLocalizedString("remote.search.no_results", value: "No Results", comment: "No search results"),
        noResultsDescription: String,
        installedItems: [Item],
        installingItems: [Item],
        availableItems: [Item],
        columns: [GridItem],
        @ViewBuilder installedContent: @escaping (Item) -> InstalledContent,
        @ViewBuilder installingContent: @escaping (Item) -> InstallingContent,
        @ViewBuilder availableContent: @escaping (Item) -> AvailableContent,
        @ViewBuilder footerContent: @escaping () -> FooterContent
    ) {
        self.init(
            config: Config(
                isEmpty: isEmpty,
                searchText: searchText,
                emptyTitle: emptyTitle,
                emptySystemImage: emptySystemImage,
                emptyDescription: emptyDescription,
                noResultsTitle: noResultsTitle,
                noResultsDescription: noResultsDescription,
                installedItems: installedItems,
                installingItems: installingItems,
                availableItems: availableItems,
                columns: columns,
                installedContent: installedContent,
                installingContent: installingContent,
                availableContent: availableContent,
                footerContent: footerContent
            )
        )
    }

    public var body: some View {
        let emptyState = ResourceCatalogTabEmptyStateConfig(
            emptyTitle: emptyTitle,
            emptySystemImage: emptySystemImage,
            emptyDescription: emptyDescription,
            noResultsTitle: noResultsTitle,
            noResultsSystemImage: "magnifyingglass",
            noResultsDescription: noResultsDescription
        )
        ResourceCatalogTabStateSectionsScaffold(
            isEmpty: isEmpty,
            searchText: searchText,
            emptyState: emptyState,
            sectionTitles: .standard,
            installedItems: installedItems,
            installingItems: installingItems,
            availableItems: availableItems,
            columns: columns,
            installedContent: installedContent,
            installingContent: installingContent,
            availableContent: availableContent,
            footerContent: footerContent
        )
    }
}


public enum ResourceCatalogTabKind {
    case skills
    case workflows
    case mcps

    var emptyTitle: String {
        switch self {
        case .skills:
            return NSLocalizedString("skills.empty", comment: "No Skills")
        case .workflows:
            return NSLocalizedString("remote.workflows.empty", value: "No Workflows", comment: "No workflows")
        case .mcps:
            return NSLocalizedString("remote.mcps.empty", value: "No MCPs", comment: "No MCPs")
        }
    }

    var emptySystemImage: String {
        switch self {
        case .skills:
            return "square.grid.2x2"
        case .workflows:
            return "arrow.triangle.branch"
        case .mcps:
            return "server.rack"
        }
    }

    var emptyDescription: String {
        switch self {
        case .skills:
            return NSLocalizedString("skills.empty_desc", comment: "No skills in this repository")
        case .workflows:
            return NSLocalizedString(
                "remote.workflows.empty_desc",
                value: "No workflows in this repository",
                comment: "No workflows description"
            )
        case .mcps:
            return NSLocalizedString(
                "remote.mcps.empty_desc",
                value: "No MCPs in this repository",
                comment: "No MCPs description"
            )
        }
    }

    var noResultsDescription: String {
        switch self {
        case .skills:
            return NSLocalizedString(
                "remote.search.no_results_desc",
                value: "No matching skills found",
                comment: "No search results description"
            )
        case .workflows:
            return NSLocalizedString(
                "remote.search.no_results_desc",
                value: "No matching workflows found",
                comment: "No search results description"
            )
        case .mcps:
            return NSLocalizedString(
                "remote.search.no_results_desc",
                value: "No matching MCPs found",
                comment: "No search results description"
            )
        }
    }

    var emptyState: ResourceCatalogTabEmptyStateConfig {
        ResourceCatalogTabEmptyStateConfig(
            emptyTitle: emptyTitle,
            emptySystemImage: emptySystemImage,
            emptyDescription: emptyDescription,
            noResultsTitle: NSLocalizedString("remote.search.no_results", value: "No Results", comment: "No search results"),
            noResultsSystemImage: "magnifyingglass",
            noResultsDescription: noResultsDescription
        )
    }
}

public struct ResourceCatalogKindTabScaffold<
    Item: Identifiable,
    InstalledContent: View,
    InstallingContent: View,
    AvailableContent: View,
    FooterContent: View
>: View {
    public struct Config {
        public var kind: ResourceCatalogTabKind
        public var isEmpty: Bool
        public var searchText: String
        public var emptyDescription: String?
        public var noResultsDescription: String?
        public var installedItems: [Item]
        public var installingItems: [Item]
        public var availableItems: [Item]
        public var columns: [GridItem]
        public var installedContent: (Item) -> InstalledContent
        public var installingContent: (Item) -> InstallingContent
        public var availableContent: (Item) -> AvailableContent
        public var footerContent: () -> FooterContent

        public init(
            kind: ResourceCatalogTabKind,
            isEmpty: Bool,
            searchText: String,
            emptyDescription: String? = nil,
            noResultsDescription: String? = nil,
            installedItems: [Item],
            installingItems: [Item],
            availableItems: [Item],
            columns: [GridItem],
            @ViewBuilder installedContent: @escaping (Item) -> InstalledContent,
            @ViewBuilder installingContent: @escaping (Item) -> InstallingContent,
            @ViewBuilder availableContent: @escaping (Item) -> AvailableContent,
            @ViewBuilder footerContent: @escaping () -> FooterContent
        ) {
            self.kind = kind
            self.isEmpty = isEmpty
            self.searchText = searchText
            self.emptyDescription = emptyDescription
            self.noResultsDescription = noResultsDescription
            self.installedItems = installedItems
            self.installingItems = installingItems
            self.availableItems = availableItems
            self.columns = columns
            self.installedContent = installedContent
            self.installingContent = installingContent
            self.availableContent = availableContent
            self.footerContent = footerContent
        }
    }

    let kind: ResourceCatalogTabKind
    let isEmpty: Bool
    let searchText: String
    let emptyDescription: String
    let noResultsDescription: String
    let installedItems: [Item]
    let installingItems: [Item]
    let availableItems: [Item]
    let columns: [GridItem]
    let installedContent: (Item) -> InstalledContent
    let installingContent: (Item) -> InstallingContent
    let availableContent: (Item) -> AvailableContent
    let footerContent: () -> FooterContent

    public init(config: Config) {
        self.kind = config.kind
        self.isEmpty = config.isEmpty
        self.searchText = config.searchText
        self.emptyDescription = config.emptyDescription ?? config.kind.emptyDescription
        self.noResultsDescription = config.noResultsDescription ?? config.kind.noResultsDescription
        self.installedItems = config.installedItems
        self.installingItems = config.installingItems
        self.availableItems = config.availableItems
        self.columns = config.columns
        self.installedContent = config.installedContent
        self.installingContent = config.installingContent
        self.availableContent = config.availableContent
        self.footerContent = config.footerContent
    }

    public init(
        kind: ResourceCatalogTabKind,
        isEmpty: Bool,
        searchText: String,
        emptyDescription: String? = nil,
        noResultsDescription: String? = nil,
        installedItems: [Item],
        installingItems: [Item],
        availableItems: [Item],
        columns: [GridItem],
        @ViewBuilder installedContent: @escaping (Item) -> InstalledContent,
        @ViewBuilder installingContent: @escaping (Item) -> InstallingContent,
        @ViewBuilder availableContent: @escaping (Item) -> AvailableContent,
        @ViewBuilder footerContent: @escaping () -> FooterContent
    ) {
        self.init(
            config: Config(
                kind: kind,
                isEmpty: isEmpty,
                searchText: searchText,
                emptyDescription: emptyDescription,
                noResultsDescription: noResultsDescription,
                installedItems: installedItems,
                installingItems: installingItems,
                availableItems: availableItems,
                columns: columns,
                installedContent: installedContent,
                installingContent: installingContent,
                availableContent: availableContent,
                footerContent: footerContent
            )
        )
    }

    public var body: some View {
        ResourceCatalogStandardTabScaffold(
            isEmpty: isEmpty,
            searchText: searchText,
            emptyTitle: kind.emptyTitle,
            emptySystemImage: kind.emptySystemImage,
            emptyDescription: emptyDescription,
            noResultsDescription: noResultsDescription,
            installedItems: installedItems,
            installingItems: installingItems,
            availableItems: availableItems,
            columns: columns,
            installedContent: installedContent,
            installingContent: installingContent,
            availableContent: availableContent,
            footerContent: footerContent
        )
    }
}


// MARK: - UnifiedRemoteCoreScaffolds

public struct ResourceCatalogMainScaffoldView<Content: View>: View {
    public struct Config {
        public var hasRepository: Bool
        public var hasSelectedTab: Bool
        public var placeholders: ResourceCatalogMainPlaceholderConfig
        public var content: () -> Content

        public init(
            hasRepository: Bool,
            hasSelectedTab: Bool,
            placeholders: ResourceCatalogMainPlaceholderConfig,
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.hasRepository = hasRepository
            self.hasSelectedTab = hasSelectedTab
            self.placeholders = placeholders
            self.content = content
        }
    }

    let hasRepository: Bool
    let hasSelectedTab: Bool
    let noRepositoryTitle: String
    let noRepositorySystemImage: String
    let noTabTitle: String
    let noTabSystemImage: String
    let content: () -> Content

    public init(config: Config) {
        self.hasRepository = config.hasRepository
        self.hasSelectedTab = config.hasSelectedTab
        self.noRepositoryTitle = config.placeholders.noRepositoryTitle
        self.noRepositorySystemImage = config.placeholders.noRepositorySystemImage
        self.noTabTitle = config.placeholders.noTabTitle
        self.noTabSystemImage = config.placeholders.noTabSystemImage
        self.content = config.content
    }

    public init(
        hasRepository: Bool,
        hasSelectedTab: Bool,
        placeholders: ResourceCatalogMainPlaceholderConfig,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                hasRepository: hasRepository,
                hasSelectedTab: hasSelectedTab,
                placeholders: placeholders,
                content: content
            )
        )
    }

    public init(
        hasRepository: Bool,
        hasSelectedTab: Bool,
        noRepositoryTitle: String = NSLocalizedString(
            "detail.no_repository",
            comment: "Select a Repository"
        ),
        noRepositorySystemImage: String = "tray",
        noTabTitle: String = NSLocalizedString(
            "detail.select_tab",
            comment: "Select a Tab"
        ),
        noTabSystemImage: String = "list.bullet",
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                hasRepository: hasRepository,
                hasSelectedTab: hasSelectedTab,
                placeholders: ResourceCatalogMainPlaceholderConfig(
                    noRepositoryTitle: noRepositoryTitle,
                    noRepositorySystemImage: noRepositorySystemImage,
                    noTabTitle: noTabTitle,
                    noTabSystemImage: noTabSystemImage
                ),
                content: content
            )
        )
    }

    public var body: some View {
        Group {
            if !hasRepository {
                ResourceCatalogPlaceholderView(
                    title: noRepositoryTitle,
                    systemImage: noRepositorySystemImage
                )
            } else if !hasSelectedTab {
                ResourceCatalogPlaceholderView(
                    title: noTabTitle,
                    systemImage: noTabSystemImage
                )
            } else {
                content()
            }
        }
    }
}

public struct ResourceCatalogMainPlaceholderConfig {
    public let noRepositoryTitle: String
    public let noRepositorySystemImage: String
    public let noTabTitle: String
    public let noTabSystemImage: String

    public init(
        noRepositoryTitle: String = NSLocalizedString(
            "detail.no_repository",
            comment: "Select a Repository"
        ),
        noRepositorySystemImage: String = "tray",
        noTabTitle: String = NSLocalizedString(
            "detail.select_tab",
            comment: "Select a Tab"
        ),
        noTabSystemImage: String = "list.bullet"
    ) {
        self.noRepositoryTitle = noRepositoryTitle
        self.noRepositorySystemImage = noRepositorySystemImage
        self.noTabTitle = noTabTitle
        self.noTabSystemImage = noTabSystemImage
    }
}

public struct ResourceCatalogSheetsPresenter<
    Content: View,
    WorkflowItem: Identifiable,
    MCPItem: Identifiable,
    DeleteItem: Identifiable,
    WorkflowSheet: View,
    MCPSheet: View,
    DeleteSheet: View
>: View {
    public struct Config {
        public var selectedWorkflow: Binding<WorkflowItem?>
        public var selectedMCP: Binding<MCPItem?>
        public var deleteRequest: Binding<DeleteItem?>
        public var content: () -> Content
        public var workflowSheet: (WorkflowItem) -> WorkflowSheet
        public var mcpSheet: (MCPItem) -> MCPSheet
        public var deleteSheet: (DeleteItem) -> DeleteSheet

        public init(
            selectedWorkflow: Binding<WorkflowItem?>,
            selectedMCP: Binding<MCPItem?>,
            deleteRequest: Binding<DeleteItem?>,
            @ViewBuilder content: @escaping () -> Content,
            @ViewBuilder workflowSheet: @escaping (WorkflowItem) -> WorkflowSheet,
            @ViewBuilder mcpSheet: @escaping (MCPItem) -> MCPSheet,
            @ViewBuilder deleteSheet: @escaping (DeleteItem) -> DeleteSheet
        ) {
            self.selectedWorkflow = selectedWorkflow
            self.selectedMCP = selectedMCP
            self.deleteRequest = deleteRequest
            self.content = content
            self.workflowSheet = workflowSheet
            self.mcpSheet = mcpSheet
            self.deleteSheet = deleteSheet
        }
    }

    @Binding var selectedWorkflow: WorkflowItem?
    @Binding var selectedMCP: MCPItem?
    @Binding var deleteRequest: DeleteItem?
    let content: () -> Content
    let workflowSheet: (WorkflowItem) -> WorkflowSheet
    let mcpSheet: (MCPItem) -> MCPSheet
    let deleteSheet: (DeleteItem) -> DeleteSheet

    public init(config: Config) {
        self._selectedWorkflow = config.selectedWorkflow
        self._selectedMCP = config.selectedMCP
        self._deleteRequest = config.deleteRequest
        self.content = config.content
        self.workflowSheet = config.workflowSheet
        self.mcpSheet = config.mcpSheet
        self.deleteSheet = config.deleteSheet
    }

    public init(
        selectedWorkflow: Binding<WorkflowItem?>,
        selectedMCP: Binding<MCPItem?>,
        deleteRequest: Binding<DeleteItem?>,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder workflowSheet: @escaping (WorkflowItem) -> WorkflowSheet,
        @ViewBuilder mcpSheet: @escaping (MCPItem) -> MCPSheet,
        @ViewBuilder deleteSheet: @escaping (DeleteItem) -> DeleteSheet
    ) {
        self.init(
            config: Config(
                selectedWorkflow: selectedWorkflow,
                selectedMCP: selectedMCP,
                deleteRequest: deleteRequest,
                content: content,
                workflowSheet: workflowSheet,
                mcpSheet: mcpSheet,
                deleteSheet: deleteSheet
            )
        )
    }

    public var body: some View {
        content()
            .sheet(item: $selectedWorkflow) { workflow in
                workflowSheet(workflow)
            }
            .sheet(item: $selectedMCP) { mcp in
                mcpSheet(mcp)
            }
            .sheet(item: $deleteRequest) { request in
                deleteSheet(request)
            }
    }
}

public struct ResourceCatalogGridSection<Data: RandomAccessCollection, CardContent: View>: View where Data.Element: Identifiable {
    public struct Config {
        public var title: String
        public var items: Data
        public var columns: [GridItem]
        public var spacing: CGFloat
        public var cardContent: (Data.Element) -> CardContent

        public init(
            title: String,
            items: Data,
            columns: [GridItem],
            spacing: CGFloat = 16,
            @ViewBuilder cardContent: @escaping (Data.Element) -> CardContent
        ) {
            self.title = title
            self.items = items
            self.columns = columns
            self.spacing = spacing
            self.cardContent = cardContent
        }
    }

    let title: String
    let items: Data
    let columns: [GridItem]
    let spacing: CGFloat
    let cardContent: (Data.Element) -> CardContent

    public init(config: Config) {
        self.title = config.title
        self.items = config.items
        self.columns = config.columns
        self.spacing = config.spacing
        self.cardContent = config.cardContent
    }

    public init(
        title: String,
        items: Data,
        columns: [GridItem],
        spacing: CGFloat = 16,
        @ViewBuilder cardContent: @escaping (Data.Element) -> CardContent
    ) {
        self.init(
            config: Config(
                title: title,
                items: items,
                columns: columns,
                spacing: spacing,
                cardContent: cardContent
            )
        )
    }

    public var body: some View {
        if !items.isEmpty {
            ResourceCatalogSectionBlock(title: title, count: items.count) {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(items) { item in
                        cardContent(item)
                    }
                }
            }
        }
    }
}

public struct RepositoryRowContextMenuView<TrailingContent: View>: View {
    public struct Config {
        public var syncTitle: String
        public var revealTitle: String
        public var editTitle: String
        public var removeTitle: String
        public var onSync: (() -> Void)?
        public var onRevealInFinder: (() -> Void)?
        public var onEdit: (() -> Void)?
        public var onRemove: (() -> Void)?
        public var trailingContent: () -> TrailingContent

        public init(
            syncTitle: String = "Sync",
            revealTitle: String = "Reveal in Finder",
            editTitle: String = "Edit",
            removeTitle: String = "Remove",
            onSync: (() -> Void)? = nil,
            onRevealInFinder: (() -> Void)? = nil,
            onEdit: (() -> Void)? = nil,
            onRemove: (() -> Void)? = nil,
            @ViewBuilder trailingContent: @escaping () -> TrailingContent
        ) {
            self.syncTitle = syncTitle
            self.revealTitle = revealTitle
            self.editTitle = editTitle
            self.removeTitle = removeTitle
            self.onSync = onSync
            self.onRevealInFinder = onRevealInFinder
            self.onEdit = onEdit
            self.onRemove = onRemove
            self.trailingContent = trailingContent
        }
    }

    let syncTitle: String
    let revealTitle: String
    let editTitle: String
    let removeTitle: String
    let onSync: (() -> Void)?
    let onRevealInFinder: (() -> Void)?
    let onEdit: (() -> Void)?
    let onRemove: (() -> Void)?
    let trailingContent: () -> TrailingContent

    public init(config: Config) {
        self.syncTitle = config.syncTitle
        self.revealTitle = config.revealTitle
        self.editTitle = config.editTitle
        self.removeTitle = config.removeTitle
        self.onSync = config.onSync
        self.onRevealInFinder = config.onRevealInFinder
        self.onEdit = config.onEdit
        self.onRemove = config.onRemove
        self.trailingContent = config.trailingContent
    }

    public init(
        syncTitle: String = "Sync",
        revealTitle: String = "Reveal in Finder",
        editTitle: String = "Edit",
        removeTitle: String = "Remove",
        onSync: (() -> Void)? = nil,
        onRevealInFinder: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onRemove: (() -> Void)? = nil,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent
    ) {
        self.init(
            config: Config(
                syncTitle: syncTitle,
                revealTitle: revealTitle,
                editTitle: editTitle,
                removeTitle: removeTitle,
                onSync: onSync,
                onRevealInFinder: onRevealInFinder,
                onEdit: onEdit,
                onRemove: onRemove,
                trailingContent: trailingContent
            )
        )
    }

    public var body: some View {
        if let onSync {
            Button {
                onSync()
            } label: {
                Label(syncTitle, systemImage: "arrow.triangle.2.circlepath")
                    .dsIconLabelButton()
            }
        }

        if let onRevealInFinder {
            Button {
                onRevealInFinder()
            } label: {
                Label(revealTitle, systemImage: "folder")
                    .dsIconLabelButton()
            }
        }

        if let onEdit {
            Button {
                onEdit()
            } label: {
                Label(editTitle, systemImage: "pencil")
                    .dsIconLabelButton()
            }
        }

        if let onRemove {
            Divider()
            ContextMenuDestructiveButton(
                title: removeTitle,
                systemImage: "trash"
            ) {
                onRemove()
            }
        }

        trailingContent()
    }
}

private struct RemoteDetailSheetFrameModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.frame(
            minWidth: 920,
            idealWidth: 1100,
            maxWidth: .infinity,
            minHeight: 620,
            idealHeight: 720,
            maxHeight: .infinity
        )
    }
}

public extension View {
    func remoteDetailSheetFrame() -> some View {
        modifier(RemoteDetailSheetFrameModifier())
    }
}

// MARK: - UnifiedResourceCatalogSupportViews

public struct CircularIconActionButton: View {
    public struct Config {
        public var systemImage: String
        public var help: String
        public var action: () -> Void

        public init(
            systemImage: String,
            help: String,
            action: @escaping () -> Void
        ) {
            self.systemImage = systemImage
            self.help = help
            self.action = action
        }
    }

    let systemImage: String
    let help: String
    let action: () -> Void

    public init(config: Config) {
        self.systemImage = config.systemImage
        self.help = config.help
        self.action = config.action
    }

    public init(
        systemImage: String,
        help: String,
        action: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                systemImage: systemImage,
                help: help,
                action: action
            )
        )
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(.white.opacity(0.1))
                        .background(
                            Circle()
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

public struct ResourceCatalogToolbarView: View {
    public struct Config {
        public var searchText: Binding<String>
        public var isSearching: Bool
        public var config: ResourceCatalogToolbarConfig
        public var onRefresh: (() -> Void)?
        public var onClose: (() -> Void)?

        public init(
            searchText: Binding<String>,
            isSearching: Bool,
            config: ResourceCatalogToolbarConfig = ResourceCatalogToolbarConfig(),
            onRefresh: (() -> Void)? = nil,
            onClose: (() -> Void)? = nil
        ) {
            self.searchText = searchText
            self.isSearching = isSearching
            self.config = config
            self.onRefresh = onRefresh
            self.onClose = onClose
        }
    }

    @Binding var searchText: String
    let isSearching: Bool
    let searchPlaceholder: String
    let onRefresh: (() -> Void)?
    let onClose: (() -> Void)?

    public init(config: Config) {
        self._searchText = config.searchText
        self.isSearching = config.isSearching
        self.searchPlaceholder = config.config.searchPlaceholder
        self.onRefresh = config.onRefresh
        self.onClose = config.onClose
    }

    public init(
        searchText: Binding<String>,
        isSearching: Bool,
        config: ResourceCatalogToolbarConfig,
        onRefresh: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.init(
            config: Config(
                searchText: searchText,
                isSearching: isSearching,
                config: config,
                onRefresh: onRefresh,
                onClose: onClose
            )
        )
    }

    public init(
        searchText: Binding<String>,
        isSearching: Bool,
        searchPlaceholder: String = NSLocalizedString(
            "remote.search.placeholder",
            value: "Search",
            comment: "Search placeholder"
        ),
        onRefresh: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.init(
            config: Config(
                searchText: searchText,
                isSearching: isSearching,
                config: ResourceCatalogToolbarConfig(searchPlaceholder: searchPlaceholder),
                onRefresh: onRefresh,
                onClose: onClose
            )
        )
    }

    public var body: some View {
        HStack(spacing: 12) {
            SearchField(
                config: .init(
                    placeholder: searchPlaceholder,
                    text: $searchText,
                    showSearching: isSearching
                )
            )
            .frame(maxWidth: .infinity)

            if let onRefresh {
                CircularIconActionButton(
                    systemImage: "arrow.clockwise",
                    help: NSLocalizedString("Refresh", comment: "Refresh"),
                    action: onRefresh
                )
            }
            if let onClose {
                ResourceCenterCloseButton(action: onClose)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

public struct ResourceCatalogToolbarConfig {
    public let searchPlaceholder: String

    public init(
        searchPlaceholder: String = NSLocalizedString(
            "remote.search.placeholder",
            value: "Search",
            comment: "Search placeholder"
        )
    ) {
        self.searchPlaceholder = searchPlaceholder
    }
}

public struct ResourceCatalogSectionBlock<Content: View>: View {
    public struct Config {
        public var header: ResourceCatalogSectionHeaderConfig
        public var content: () -> Content

        public init(
            header: ResourceCatalogSectionHeaderConfig,
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.header = header
            self.content = content
        }
    }

    let title: String
    let count: Int
    let content: () -> Content

    public init(config: Config) {
        self.title = config.header.title
        self.count = config.header.count
        self.content = config.content
    }

    public init(
        config: ResourceCatalogSectionHeaderConfig,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(config: Config(header: config, content: content))
    }

    public init(
        title: String,
        count: Int,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                header: ResourceCatalogSectionHeaderConfig(title: title, count: count),
                content: content
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .dsBadge(
                        foreground: DesignSystem.Colors.Text.secondary,
                        background: DesignSystem.Colors.Component.controlFillSubtle
                    )
                Spacer()
            }
            .padding(.top, 2)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct ResourceCatalogSectionHeaderConfig {
    public let title: String
    public let count: Int

    public init(title: String, count: Int) {
        self.title = title
        self.count = count
    }
}

public struct InlineWarningBannerView: View {
    public struct Config {
        public var message: String
        public var retryTitle: String
        public var onRetry: () -> Void

        public init(
            message: String,
            retryTitle: String,
            onRetry: @escaping () -> Void
        ) {
            self.message = message
            self.retryTitle = retryTitle
            self.onRetry = onRetry
        }
    }

    let message: String
    let retryTitle: String
    let onRetry: () -> Void

    public init(config: Config) {
        self.message = config.message
        self.retryTitle = config.retryTitle
        self.onRetry = config.onRetry
    }

    public init(
        config: InlineWarningBannerConfig,
        onRetry: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                message: config.message,
                retryTitle: config.retryTitle,
                onRetry: onRetry
            )
        )
    }

    public init(
        message: String,
        retryTitle: String,
        onRetry: @escaping () -> Void
    ) {
        self.init(config: Config(message: message, retryTitle: retryTitle, onRetry: onRetry))
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignSystem.Colors.Status.warning)
            Text(message)
                .font(.callout)
                .dsSecondaryText(font: .callout)
                .lineLimit(2)
            Spacer()
            Button(retryTitle) {
                onRetry()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .dsCard(
            background: DesignSystem.Colors.Status.warning.opacity(0.10),
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Status.warning.opacity(0.28),
            borderWidth: 1
        )
        .padding(.horizontal)
    }
}

public struct InlineWarningBannerConfig {
    public let message: String
    public let retryTitle: String

    public init(
        message: String,
        retryTitle: String
    ) {
        self.message = message
        self.retryTitle = retryTitle
    }
}

public struct ResourceCatalogPlaceholderView: View {
    public struct Config {
        public var title: String
        public var systemImage: String

        public init(
            title: String,
            systemImage: String
        ) {
            self.title = title
            self.systemImage = systemImage
        }
    }

    let title: String
    let systemImage: String

    public init(config: Config) {
        self.title = config.title
        self.systemImage = config.systemImage
    }

    public init(config: ResourceCatalogPlaceholderConfig) {
        self.init(config: Config(title: config.title, systemImage: config.systemImage))
    }

    public init(title: String, systemImage: String) {
        self.init(config: Config(title: title, systemImage: systemImage))
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

public struct ResourceCatalogPlaceholderConfig {
    public let title: String
    public let systemImage: String

    public init(
        title: String,
        systemImage: String
    ) {
        self.title = title
        self.systemImage = systemImage
    }
}

public struct CenteredLoadingIndicatorView: View {
    public struct Config {
        public init() {}
    }

    public init(config: Config) {
        _ = config
    }

    public init() {
        self.init(config: Config())
    }

    public var body: some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(DesignSystem.Colors.Status.info)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public struct ResourceCatalogErrorStateView: View {
    public struct Config {
        public var data: ResourceCatalogErrorStateConfig
        public var onCopyMessage: () -> Void
        public var onRetry: () -> Void

        public init(
            data: ResourceCatalogErrorStateConfig,
            onCopyMessage: @escaping () -> Void,
            onRetry: @escaping () -> Void
        ) {
            self.data = data
            self.onCopyMessage = onCopyMessage
            self.onRetry = onRetry
        }
    }

    let title: String
    let message: String
    let retryTitle: String
    let onCopyMessage: () -> Void
    let onRetry: () -> Void

    public init(config: Config) {
        self.title = config.data.title
        self.message = config.data.message
        self.retryTitle = config.data.retryTitle
        self.onCopyMessage = config.onCopyMessage
        self.onRetry = config.onRetry
    }

    public init(
        config: ResourceCatalogErrorStateConfig,
        onCopyMessage: @escaping () -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                data: config,
                onCopyMessage: onCopyMessage,
                onRetry: onRetry
            )
        )
    }

    public init(
        title: String,
        message: String,
        retryTitle: String,
        onCopyMessage: @escaping () -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
        self.onCopyMessage = onCopyMessage
        self.onRetry = onRetry
    }

    public var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
                    .dsEmptyStateErrorTitle()
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .dsEmptyStateIcon(color: DesignSystem.Colors.Status.error)
            }
        } description: {
            Button {
                onCopyMessage()
            } label: {
                Text(message)
                    .dsSecondaryText(font: .body)
            }
            .buttonStyle(.plain)
        } actions: {
            Button {
                onRetry()
            } label: {
                Text(retryTitle)
            }
            .buttonStyle(.bordered)
        }
    }
}

public struct ResourceCatalogErrorStateConfig {
    public let title: String
    public let message: String
    public let retryTitle: String

    public init(
        title: String,
        message: String,
        retryTitle: String
    ) {
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
    }
}

public struct ResourceCatalogBodyStateContainerView<Content: View>: View {
    public struct Config {
        public var isLoading: Bool
        public var hasAnyContent: Bool
        public var errorMessage: String?
        public var errorConfig: ResourceCatalogLoadErrorConfig
        public var onCopyError: (String) -> Void
        public var onRetry: () -> Void
        public var content: () -> Content

        public init(
            isLoading: Bool,
            hasAnyContent: Bool,
            errorMessage: String?,
            errorConfig: ResourceCatalogLoadErrorConfig,
            onCopyError: @escaping (String) -> Void,
            onRetry: @escaping () -> Void,
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.isLoading = isLoading
            self.hasAnyContent = hasAnyContent
            self.errorMessage = errorMessage
            self.errorConfig = errorConfig
            self.onCopyError = onCopyError
            self.onRetry = onRetry
            self.content = content
        }
    }

    let isLoading: Bool
    let hasAnyContent: Bool
    let errorMessage: String?
    let loadErrorTitle: String
    let retryTitle: String
    let onCopyError: (String) -> Void
    let onRetry: () -> Void
    let content: () -> Content

    public init(config: Config) {
        self.isLoading = config.isLoading
        self.hasAnyContent = config.hasAnyContent
        self.errorMessage = config.errorMessage
        self.loadErrorTitle = config.errorConfig.title
        self.retryTitle = config.errorConfig.retryTitle
        self.onCopyError = config.onCopyError
        self.onRetry = config.onRetry
        self.content = config.content
    }

    public init(
        isLoading: Bool,
        hasAnyContent: Bool,
        errorMessage: String?,
        errorConfig: ResourceCatalogLoadErrorConfig,
        onCopyError: @escaping (String) -> Void,
        onRetry: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                isLoading: isLoading,
                hasAnyContent: hasAnyContent,
                errorMessage: errorMessage,
                errorConfig: errorConfig,
                onCopyError: onCopyError,
                onRetry: onRetry,
                content: content
            )
        )
    }

    public init(
        isLoading: Bool,
        hasAnyContent: Bool,
        errorMessage: String?,
        loadErrorTitle: String = NSLocalizedString(
            "remote.error.title",
            value: "Error Loading Data",
            comment: "Remote load error title"
        ),
        retryTitle: String = NSLocalizedString(
            "remote.retry",
            value: "Retry",
            comment: "Retry"
        ),
        onCopyError: @escaping (String) -> Void,
        onRetry: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            config: Config(
                isLoading: isLoading,
                hasAnyContent: hasAnyContent,
                errorMessage: errorMessage,
                errorConfig: ResourceCatalogLoadErrorConfig(
                    title: loadErrorTitle,
                    retryTitle: retryTitle
                ),
                onCopyError: onCopyError,
                onRetry: onRetry,
                content: content
            )
        )
    }

    public var body: some View {
        if isLoading && !hasAnyContent {
            CenteredLoadingIndicatorView()
        } else if let error = errorMessage, !hasAnyContent {
            ResourceCatalogErrorStateView(
                config: ResourceCatalogErrorStateConfig(
                    title: loadErrorTitle,
                    message: error,
                    retryTitle: retryTitle
                ),
                onCopyMessage: {
                    onCopyError(error)
                },
                onRetry: onRetry
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 10) {
                if let error = errorMessage, !error.isEmpty {
                    InlineWarningBannerView(
                        message: error,
                        retryTitle: retryTitle,
                        onRetry: onRetry
                    )
                }
                content()
            }
        }
    }
}

public struct ResourceCatalogLoadErrorConfig {
    public let title: String
    public let retryTitle: String

    public init(
        title: String = NSLocalizedString(
            "remote.error.title",
            value: "Error Loading Data",
            comment: "Remote load error title"
        ),
        retryTitle: String = NSLocalizedString(
            "remote.retry",
            value: "Retry",
            comment: "Retry"
        )
    ) {
        self.title = title
        self.retryTitle = retryTitle
    }
}

public struct ResourceCatalogGridOverlayScaffold<Content: View, Overlay: View>: View {
    public struct Config {
        public var contentPadding: EdgeInsets
        public var showOverlay: Bool
        public var content: () -> Content
        public var overlay: () -> Overlay

        public init(
            contentPadding: EdgeInsets,
            showOverlay: Bool,
            @ViewBuilder content: @escaping () -> Content,
            @ViewBuilder overlay: @escaping () -> Overlay
        ) {
            self.contentPadding = contentPadding
            self.showOverlay = showOverlay
            self.content = content
            self.overlay = overlay
        }
    }

    let contentPadding: EdgeInsets
    let showOverlay: Bool
    let content: () -> Content
    let overlay: () -> Overlay

    public init(config: Config) {
        self.contentPadding = config.contentPadding
        self.showOverlay = config.showOverlay
        self.content = config.content
        self.overlay = config.overlay
    }

    public init(
        config: ResourceCatalogGridOverlayConfig,
        showOverlay: Bool,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) {
        self.init(
            config: Config(
                contentPadding: config.contentPadding,
                showOverlay: showOverlay,
                content: content,
                overlay: overlay
            )
        )
    }

    public init(
        contentPadding: EdgeInsets = EdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16),
        showOverlay: Bool,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder overlay: @escaping () -> Overlay
    ) {
        self.init(
            config: Config(
                contentPadding: contentPadding,
                showOverlay: showOverlay,
                content: content,
                overlay: overlay
            )
        )
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PaddedScrollContainer(
                padding: contentPadding
            ) {
                content()
            }
        }
        .bottomTrailingOverlay(isPresented: showOverlay) {
            overlay()
        }
    }
}

public struct ResourceCatalogGridOverlayConfig {
    public let contentPadding: EdgeInsets

    public init(
        contentPadding: EdgeInsets = EdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
    ) {
        self.contentPadding = contentPadding
    }
}

// MARK: - UnifiedResourceInstallStateViews

enum ResourceInstallState: Equatable {
    case installed
    case installing
    case failed(message: String)
    case installable

    static func resolve(isInstalled: Bool, isInstalling: Bool, errorMessage: String?) -> ResourceInstallState {
        if isInstalled {
            return .installed
        }

        if isInstalling {
            return .installing
        }

        if let errorMessage, !errorMessage.isEmpty {
            return .failed(message: errorMessage)
        }

        return .installable
    }
}

public struct ResourceInstallStateView: View {
    public struct Config {
        public var isInstalled: Bool
        public var isInstalling: Bool
        public var errorMessage: String?
        public var onInstall: () -> Void
        public var onRetry: () -> Void

        public init(
            isInstalled: Bool,
            isInstalling: Bool,
            errorMessage: String?,
            onInstall: @escaping () -> Void,
            onRetry: @escaping () -> Void
        ) {
            self.isInstalled = isInstalled
            self.isInstalling = isInstalling
            self.errorMessage = errorMessage
            self.onInstall = onInstall
            self.onRetry = onRetry
        }
    }

    @State private var viewModel = ResourceInstallStateViewViewModel()
    private let state: ResourceInstallState
    private let onInstall: () -> Void
    private let onRetry: () -> Void

    public init(config: Config) {
        self.state = ResourceInstallState.resolve(
            isInstalled: config.isInstalled,
            isInstalling: config.isInstalling,
            errorMessage: config.errorMessage
        )
        self.onInstall = config.onInstall
        self.onRetry = config.onRetry
    }

    public init(
        isInstalled: Bool,
        isInstalling: Bool,
        errorMessage: String?,
        onInstall: @escaping () -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                isInstalled: isInstalled,
                isInstalling: isInstalling,
                errorMessage: errorMessage,
                onInstall: onInstall,
                onRetry: onRetry
            )
        )
    }

    public var body: some View {
        switch state {
        case .installed:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text(NSLocalizedString("remote.status.installed", value: "Installed", comment: "Remote installed status"))
            }
            .fontWeight(.medium)
            .dsBadge(
                foreground: DesignSystem.Colors.Status.success,
                background: DesignSystem.Colors.Status.success.opacity(0.10)
            )

        case .installing:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text(NSLocalizedString("remote.status.installing", value: "Installing", comment: "Remote installing status"))
            }
            .fontWeight(.medium)
            .dsBadge(
                foreground: DesignSystem.Colors.secondary,
                background: DesignSystem.Colors.secondary.opacity(0.10)
            )

        case let .failed(message):
            Button {
                onRetry()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise.circle")
                    Text(NSLocalizedString("remote.retry", value: "Retry", comment: "Retry"))
                }
                .fontWeight(.semibold)
                .dsBadge(
                    foreground: DesignSystem.Colors.Status.error,
                    background: DesignSystem.Colors.Status.error.opacity(0.10),
                    horizontalPadding: 10,
                    verticalPadding: 6
                )
            }
            .dsLinkButton()
            .help(message)

        case .installable:
            Button {
                onInstall()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                    Text(NSLocalizedString("action.install", value: "Install", comment: "Install action"))
                }
                .fontWeight(.semibold)
                .dsBadge(
                    foreground: DesignSystem.Colors.primary,
                    background: DesignSystem.Colors.primary.opacity(0.10),
                    horizontalPadding: 10,
                    verticalPadding: 6
                )
            }
            .dsLinkButton()
        }
    }
}

public struct ResourceInstallStateSectionsView<
    Item: Identifiable,
    InstalledContent: View,
    InstallingContent: View,
    AvailableContent: View,
    FooterContent: View
>: View {
    public struct Config {
        public var installedTitle: String
        public var installingTitle: String
        public var availableTitle: String
        public var installedItems: [Item]
        public var installingItems: [Item]
        public var availableItems: [Item]
        public var columns: [GridItem]
        public var installedContent: (Item) -> InstalledContent
        public var installingContent: (Item) -> InstallingContent
        public var availableContent: (Item) -> AvailableContent
        public var footerContent: () -> FooterContent

        public init(
            installedTitle: String,
            installingTitle: String,
            availableTitle: String,
            installedItems: [Item],
            installingItems: [Item],
            availableItems: [Item],
            columns: [GridItem],
            @ViewBuilder installedContent: @escaping (Item) -> InstalledContent,
            @ViewBuilder installingContent: @escaping (Item) -> InstallingContent,
            @ViewBuilder availableContent: @escaping (Item) -> AvailableContent,
            @ViewBuilder footerContent: @escaping () -> FooterContent
        ) {
            self.installedTitle = installedTitle
            self.installingTitle = installingTitle
            self.availableTitle = availableTitle
            self.installedItems = installedItems
            self.installingItems = installingItems
            self.availableItems = availableItems
            self.columns = columns
            self.installedContent = installedContent
            self.installingContent = installingContent
            self.availableContent = availableContent
            self.footerContent = footerContent
        }

        public init(
            sectionTitles: ResourceCatalogTabSectionTitles,
            installedItems: [Item],
            installingItems: [Item],
            availableItems: [Item],
            columns: [GridItem],
            @ViewBuilder installedContent: @escaping (Item) -> InstalledContent,
            @ViewBuilder installingContent: @escaping (Item) -> InstallingContent,
            @ViewBuilder availableContent: @escaping (Item) -> AvailableContent,
            @ViewBuilder footerContent: @escaping () -> FooterContent
        ) {
            self.installedTitle = sectionTitles.installedTitle
            self.installingTitle = sectionTitles.installingTitle
            self.availableTitle = sectionTitles.availableTitle
            self.installedItems = installedItems
            self.installingItems = installingItems
            self.availableItems = availableItems
            self.columns = columns
            self.installedContent = installedContent
            self.installingContent = installingContent
            self.availableContent = availableContent
            self.footerContent = footerContent
        }
    }

    let installedTitle: String
    let installingTitle: String
    let availableTitle: String
    let installedItems: [Item]
    let installingItems: [Item]
    let availableItems: [Item]
    let columns: [GridItem]
    let installedContent: (Item) -> InstalledContent
    let installingContent: (Item) -> InstallingContent
    let availableContent: (Item) -> AvailableContent
    let footerContent: () -> FooterContent

    public init(config: Config) {
        self.installedTitle = config.installedTitle
        self.installingTitle = config.installingTitle
        self.availableTitle = config.availableTitle
        self.installedItems = config.installedItems
        self.installingItems = config.installingItems
        self.availableItems = config.availableItems
        self.columns = config.columns
        self.installedContent = config.installedContent
        self.installingContent = config.installingContent
        self.availableContent = config.availableContent
        self.footerContent = config.footerContent
    }

    public init(
        sectionTitles: ResourceCatalogTabSectionTitles,
        installedItems: [Item],
        installingItems: [Item],
        availableItems: [Item],
        columns: [GridItem],
        @ViewBuilder installedContent: @escaping (Item) -> InstalledContent,
        @ViewBuilder installingContent: @escaping (Item) -> InstallingContent,
        @ViewBuilder availableContent: @escaping (Item) -> AvailableContent,
        @ViewBuilder footerContent: @escaping () -> FooterContent
    ) {
        self.init(
            config: Config(
                sectionTitles: sectionTitles,
                installedItems: installedItems,
                installingItems: installingItems,
                availableItems: availableItems,
                columns: columns,
                installedContent: installedContent,
                installingContent: installingContent,
                availableContent: availableContent,
                footerContent: footerContent
            )
        )
    }

    public init(
        installedTitle: String,
        installingTitle: String,
        availableTitle: String,
        installedItems: [Item],
        installingItems: [Item],
        availableItems: [Item],
        columns: [GridItem],
        @ViewBuilder installedContent: @escaping (Item) -> InstalledContent,
        @ViewBuilder installingContent: @escaping (Item) -> InstallingContent,
        @ViewBuilder availableContent: @escaping (Item) -> AvailableContent,
        @ViewBuilder footerContent: @escaping () -> FooterContent
    ) {
        self.init(
            config: Config(
                installedTitle: installedTitle,
                installingTitle: installingTitle,
                availableTitle: availableTitle,
                installedItems: installedItems,
                installingItems: installingItems,
                availableItems: availableItems,
                columns: columns,
                installedContent: installedContent,
                installingContent: installingContent,
                availableContent: availableContent,
                footerContent: footerContent
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ResourceCatalogGridSection(
                title: installedTitle,
                items: installedItems,
                columns: columns
            ) { item in
                installedContent(item)
            }
            ResourceCatalogGridSection(
                title: installingTitle,
                items: installingItems,
                columns: columns
            ) { item in
                installingContent(item)
            }
            ResourceCatalogGridSection(
                title: availableTitle,
                items: availableItems,
                columns: columns
            ) { item in
                availableContent(item)
            }
            footerContent()
        }
    }
}
