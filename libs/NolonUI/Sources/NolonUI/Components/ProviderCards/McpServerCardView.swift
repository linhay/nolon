import SwiftUI

public enum McpServerCardCacheState: Sendable, Hashable {
    case notMigrated
    case migratedUpToDate
    case migratedNeedsUpdate
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
            HStack(alignment: .center) {
                titleContent()
                Spacer()
                moreMenu
            }

            VStack(alignment: .leading, spacing: DesignSystem.Metrics.spacingXS) {
                if let commandText, !commandText.isEmpty {
                    HighlightedText(text: commandText, query: searchText)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .dsSecondaryText(font: .caption)
                        .lineLimit(2)
                        .truncationMode(.middle)
                } else {
                    Text(NSLocalizedString("mcp.no_command", value: "No command specified", comment: "Placeholder when MCP command is missing"))
                        .font(.caption)
                        .dsSecondaryText(font: .caption)
                        .italic()
                }
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)

            HStack {
                if hasWorkflow {
                    Button {
                        onUnlinkWorkflow()
                    } label: {
                        HStack(spacing: DesignSystem.Metrics.spacingS - 2) {
                            Image(systemName: "arrow.triangle.branch")
                            Text(NSLocalizedString("mcp.workflow", value: "Workflow", comment: "Workflow badge"))
                        }
                        .fontWeight(.semibold)
                        .dsBadge(
                            foreground: DesignSystem.Colors.primary,
                            background: DesignSystem.Colors.primary.opacity(DesignSystem.Colors.Opacity.subtle),
                            horizontalPadding: 10,
                            verticalPadding: 6,
                            cornerRadius: DesignSystem.Metrics.cornerRadiusS
                        )
                    }
                    .dsLinkButton()
                } else {
                    Button {
                        onLinkWorkflow()
                    } label: {
                        HStack(spacing: DesignSystem.Metrics.spacingS - 2) {
                            Image(systemName: "plus.circle")
                            Text(NSLocalizedString("action.link_workflow", comment: "Link to Workflow"))
                        }
                        .fontWeight(.semibold)
                        .dsBadge(
                            foreground: DesignSystem.Colors.Text.secondary,
                            background: DesignSystem.Colors.Component.controlFillSubtle,
                            horizontalPadding: 10,
                            verticalPadding: 6,
                            cornerRadius: DesignSystem.Metrics.cornerRadiusS
                        )
                    }
                    .dsLinkButton()
                }

                if cacheState == .notMigrated {
                    Button(action: onMigrateToNolon) {
                        HStack(spacing: DesignSystem.Metrics.spacingS - 2) {
                            Image(systemName: "tray.and.arrow.down")
                            Text(NSLocalizedString("action.migrate", value: "Migrate", comment: "Migrate"))
                        }
                        .fontWeight(.semibold)
                        .dsBadge(
                            foreground: DesignSystem.Colors.primary,
                            background: DesignSystem.Colors.primary.opacity(DesignSystem.Colors.Opacity.subtle),
                            horizontalPadding: 10,
                            verticalPadding: 6,
                            cornerRadius: DesignSystem.Metrics.cornerRadiusS
                        )
                    }
                    .dsLinkButton()
                } else if cacheState == .migratedNeedsUpdate {
                    Button(action: onUpdateNolonCache) {
                        HStack(spacing: DesignSystem.Metrics.spacingS - 2) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(NSLocalizedString("action.update", value: "Update", comment: "Update"))
                        }
                        .fontWeight(.semibold)
                        .dsBadge(
                            foreground: DesignSystem.Colors.primary,
                            background: DesignSystem.Colors.primary.opacity(DesignSystem.Colors.Opacity.subtle),
                            horizontalPadding: 10,
                            verticalPadding: 6,
                            cornerRadius: DesignSystem.Metrics.cornerRadiusS
                        )
                    }
                    .dsLinkButton()
                }

                Button {
                    onSetEnabled(!isEnabled)
                } label: {
                    HStack(spacing: DesignSystem.Metrics.spacingS - 2) {
                        Image(systemName: isEnabled ? "pause.circle" : "play.circle")
                        Text(
                            isEnabled
                                ? NSLocalizedString("mcp.action.disable", value: "Disable", comment: "Disable MCP")
                                : NSLocalizedString("mcp.action.enable", value: "Enable", comment: "Enable MCP")
                        )
                    }
                    .fontWeight(.semibold)
                    .dsBadge(
                        foreground: isEnabled ? DesignSystem.Colors.Text.secondary : DesignSystem.Colors.primary,
                        background: isEnabled ? DesignSystem.Colors.Component.controlFillSubtle : DesignSystem.Colors.primary.opacity(DesignSystem.Colors.Opacity.subtle),
                        horizontalPadding: 10,
                        verticalPadding: 6,
                        cornerRadius: DesignSystem.Metrics.cornerRadiusS
                    )
                }
                .dsLinkButton()

                Spacer()
            }
        }
        .padding(DesignSystem.Metrics.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 140)
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
    var body: some View {
        McpServerCardView(
            commandText: "npx -y @modelcontextprotocol/server-filesystem /tmp",
            searchText: "server",
            hasWorkflow: false,
            isEnabled: true,
            cacheState: .notMigrated,
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

#Preview("MCP Server Card") {
    McpServerCardViewPreviewContainer()
}
