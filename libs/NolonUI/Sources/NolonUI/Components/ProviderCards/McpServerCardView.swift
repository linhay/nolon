import SwiftUI

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

    @State private var showingDeleteConfirmation = false

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

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Metrics.spacingM) {
            headerRow
            commandRow
            statusRow
            Divider()
            actionRow
        }
        .padding(DesignSystem.Metrics.spacingL)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .providerTabCardStyle()
        .contentShape(Rectangle())
        .contextMenu {
            contextMenuItems
        }
        .confirmationDialog(
            NSLocalizedString("action.delete_confirm_title_mcp", value: "Confirm Delete MCP", comment: "MCP Delete confirmation title"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("action.delete", comment: "Delete"), role: .destructive) {
                onDelete()
            }
            Button(NSLocalizedString("action.cancel", value: "Cancel", comment: "Cancel action"), role: .cancel) {}
        } message: {
            Text(
                NSLocalizedString(
                    "action.delete_confirm_message_mcp",
                    value: "Are you sure you want to delete this MCP server? This will remove its configuration.",
                    comment: "MCP Delete confirmation message"
                )
            )
        }
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
        HStack(alignment: .center, spacing: DesignSystem.Metrics.spacingS) {
            titleContent()
            Spacer(minLength: DesignSystem.Metrics.spacingS)
            moreMenu
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
        let icon = hasWorkflow ? "link.badge.minus" : "link.badge.plus"

        if primaryAction == .none {
            Button {
                hasWorkflow ? onUnlinkWorkflow() : onLinkWorkflow()
            } label: {
                Image(systemName: icon)
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
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(title)
            .accessibilityLabel(title)
        }
    }

    private var maintenanceAction: McpServerMaintenanceAction {
        Self.resolveMaintenanceAction(for: cacheState)
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
                    systemImage: "link.badge.plus"
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

        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            Label(NSLocalizedString("action.delete", comment: "Delete"), systemImage: "trash")
                .dsIconLabelButton()
        }

        extraContextMenu()
    }

    private var moreMenu: some View {
        Menu {
            contextMenuItems
        } label: {
            Image(systemName: "ellipsis")
                .dsIconButton()
        }
        .dsBorderlessMenu()
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

private struct McpServerCardViewPreviewContainer: View {
    let hasWorkflow: Bool
    let isEnabled: Bool
    let cacheState: McpServerCardCacheState

    var body: some View {
        McpServerCardView(
            commandText: "npx -y @modelcontextprotocol/server-filesystem /tmp",
            searchText: "server",
            hasWorkflow: hasWorkflow,
            isEnabled: isEnabled,
            cacheState: cacheState,
            onLinkWorkflow: {},
            onUnlinkWorkflow: {},
            onSetEnabled: { _ in },
            onMigrateToNolon: {},
            onUpdateNolonCache: {},
            onEdit: {},
            onDelete: {}
        ) {
            Label("filesystem", systemImage: "server.rack")
        } extraContextMenu: {
            EmptyView()
        }
        .frame(width: 360)
        .padding(16)
    }
}

#Preview("MCP On") {
    McpServerCardViewPreviewContainer(
        hasWorkflow: true,
        isEnabled: true,
        cacheState: .migratedUpToDate
    )
}

#Preview("MCP Migrate") {
    McpServerCardViewPreviewContainer(
        hasWorkflow: false,
        isEnabled: false,
        cacheState: .notMigrated
    )
}

#Preview("MCP Update") {
    McpServerCardViewPreviewContainer(
        hasWorkflow: false,
        isEnabled: true,
        cacheState: .migratedNeedsUpdate
    )
}
