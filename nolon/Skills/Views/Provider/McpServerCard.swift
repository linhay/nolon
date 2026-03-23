import SwiftUI
internal import AnyCodable
import NolonResourceKit
import NolonUI

/// MCP Server 卡片视图 - Grid 布局中的卡片
struct McpServerCard: View {
    let mcp: MCP
    let hasWorkflow: Bool
    let searchText: String
    let cacheState: ProviderDetailGridViewModel.McpCacheState
    let onLinkWorkflow: () -> Void
    let onUnlinkWorkflow: () -> Void
    let onSetEnabled: (Bool) -> Void
    let onMigrateToNolon: () -> Void
    let onUpdateNolonCache: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        NolonUI.McpServerCardView(
            commandText: commandText,
            searchText: searchText,
            hasWorkflow: hasWorkflow,
            isEnabled: mcp.isEnabled,
            cacheState: mappedCacheState,
            onLinkWorkflow: onLinkWorkflow,
            onUnlinkWorkflow: onUnlinkWorkflow,
            onSetEnabled: onSetEnabled,
            onMigrateToNolon: onMigrateToNolon,
            onUpdateNolonCache: onUpdateNolonCache,
            onEdit: onEdit,
            onDelete: onDelete
        ) {
            ProviderLogoView(
                name: mcp.name,
                logoName: mcpLogoName,
                highlightQuery: searchText,
                style: .horizontal,
                iconSize: 24
            )
        } extraContextMenu: {
            debugPageMarkerMenuItem(
                [
                    PageMarkerItem(title: "MCP Servers"),
                    PageMarkerItem(title: mcp.name)
                ]
            )
        }
    }

    private var commandText: String? {
        guard let dict = mcp.json.value as? [String: Any] else { return nil }
        return dict["command"] as? String
    }

    private var mappedCacheState: NolonUI.McpServerCardCacheState {
        switch cacheState {
        case .notMigrated:
            return .notMigrated
        case .migratedUpToDate:
            return .migratedUpToDate
        case .migratedNeedsUpdate:
            return .migratedNeedsUpdate
        }
    }

    private var mcpLogoName: String? {
        let name = mcp.name.lowercased()
        if name.contains("playwright") { return "playwright" }
        if name.contains("github") { return "github" }
        if name.contains("gitlab") { return "gitlab" }
        if name.contains("google") { return "google" }
        if name.contains("brave") { return "brave" }
        if name.contains("exa") { return "exa" }
        if name.contains("sqlite") { return "sqlite" }
        if name.contains("postgres") { return "postgresql" }
        if name.contains("docker") { return "docker" }
        if name.contains("slack") { return "slack" }
        return nil
    }
}
