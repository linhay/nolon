import SwiftUI
internal import AnyCodable
import NolonUI
import NolonUIFoundation
import ProviderCatalog
import STFilePath
import NolonResourceKit

struct ProviderMcpGridView: View {
    let provider: Provider?
    let viewModel: ProviderDetailGridViewModel
    let columns: [GridItem]
    let markerBaseItems: [PageMarkerItem]

    @State private var editingConfig: EditingConfig?
    @State private var migrationAlert: MessageAlertData?

    private var template: ProviderTemplate? {
        guard
            let provider,
            let templateId = provider.templateId
        else { return nil }
        return ProviderTemplate(rawValue: templateId)
    }

    private var supportsNativeMcpConfig: Bool {
        template?.supportsNativeMcpConfig == true
    }

    private var configPath: URL? {
        template?.defaultMcpConfigPath
    }

    private var mcpUnsupportedSystemImage: String {
        provider == nil ? "exclamationmark.triangle" : "server.rack"
    }

    private var mcpUnsupportedDescription: String {
        if provider == nil || template == nil {
            return NSLocalizedString("mcp.not_supported_desc", comment: "This provider does not support MCP configuration")
        }
        return NSLocalizedString(
            "provider.mcp.not_supported_native",
            value: "This provider does not expose a native MCP configuration file.",
            comment: "Provider does not expose native MCP config"
        )
    }
    
    var body: some View {
        Group {
            if let configPath {
                let isToml = configPath.pathExtension.lowercased() == "toml"
                let exists = STFile(configPath).isExists

                NolonUI.ProviderMcpConfigScaffoldView(
                    supportsNativeConfig: supportsNativeMcpConfig,
                    configExists: exists,
                    isSearching: !viewModel.searchText.isEmpty,
                    hasFilteredServers: !viewModel.filteredMcps.isEmpty,
                    unsupportedSystemImage: mcpUnsupportedSystemImage,
                    unsupportedDescription: mcpUnsupportedDescription
                ) {
                    NolonUI.McpConfigActionStateView(
                        preset: .noConfiguration
                    ) {
                        _ = STFolder(configPath.deletingLastPathComponent()).createIfNotExists()
                        if isToml {
                            let template = """
                            model = ""

                            [mcp_servers]
                            """
                            try? STFile(configPath).overlay(with: template)
                        } else {
                            if template?.rawValue == "opencode" {
                                let template = """
                                {
                                  "mcp": {}
                                }
                                """
                                try? STFile(configPath).overlay(with: template)
                            } else {
                                try? STFile(configPath).overlay(with: "{}")
                            }
                        }
                        editingConfig = EditingConfig(
                            configURL: configPath,
                            format: isToml ? .toml : .json,
                            highlightKey: nil
                        )
                        Task { await viewModel.loadData() }
                    }
                } noServersView: {
                    NolonUI.McpConfigToolbarScaffoldView(
                        documentationURL: template?.mcpDocumentationURL,
                        onEdit: {
                            editingConfig = EditingConfig(
                                configURL: configPath,
                                format: isToml ? .toml : .json,
                                highlightKey: nil
                            )
                        }
                    ) {
                        NolonUI.McpConfigActionStateView(
                            preset: .noServers
                        ) {
                            editingConfig = EditingConfig(
                                configURL: configPath,
                                format: isToml ? .toml : .json,
                                highlightKey: nil
                            )
                        }
                    }
                } noResultsView: {
                    NolonUI.McpConfigNoResultsStateView()
                } contentView: {
                    NolonUI.McpConfigToolbarScaffoldView(
                        documentationURL: template?.mcpDocumentationURL,
                        onEdit: {
                            editingConfig = EditingConfig(
                                configURL: configPath,
                                format: isToml ? .toml : .json,
                                highlightKey: nil
                            )
                        }
                    ) {
                        NolonUI.AdaptiveCardGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.filteredMcps) { mcp in
                            let cacheState = (viewModel.mcpCacheStates[mcp.name] ?? .notMigrated).uiCacheState
                            NolonUI.McpServerCardView(
                                commandText: mcpCommandText(mcp),
                                searchText: viewModel.searchText,
                                hasWorkflow: viewModel.mcpWorkflowIds.contains(mcp.name),
                                isEnabled: mcp.isEnabled,
                                cacheState: cacheState,
                                onLinkWorkflow: { viewModel.linkMcpToWorkflow(mcp) },
                                onUnlinkWorkflow: { viewModel.unlinkMcpFromWorkflow(mcp) },
                                onSetEnabled: { enabled in
                                    guard let provider else { return }
                                    Task { await viewModel.setMCPEnabled(mcp, enabled: enabled, for: provider) }
                                },
                                onMigrateToNolon: {
                                    Task {
                                        do {
                                            try await viewModel.migrateMcpToGlobalCache(mcp)
                                            migrationAlert = .migrate(
                                                message: NSLocalizedString(
                                                    "mcp.migration.single.success",
                                                    value: "Migrated.",
                                                    comment: "MCP single migration success"
                                                )
                                            )
                                        } catch {
                                            migrationAlert = .migrate(message: error.localizedDescription)
                                        }
                                    }
                                },
                                onUpdateNolonCache: {
                                    Task {
                                        do {
                                            try await viewModel.updateCachedMcpIfNeeded(mcp)
                                            migrationAlert = .update(
                                                message: NSLocalizedString(
                                                    "mcp.migration.single.updated",
                                                    value: "Updated.",
                                                    comment: "MCP single cache update success"
                                                )
                                            )
                                        } catch {
                                            migrationAlert = .update(message: error.localizedDescription)
                                        }
                                    }
                                },
                                onEdit: {
                                    editingConfig = EditingConfig(
                                        configURL: configPath,
                                        format: isToml ? .toml : .json,
                                        highlightKey: mcp.name
                                    )
                                },
                                onDelete: {
                                    guard let provider else { return }
                                    Task { await viewModel.deleteMCP(named: mcp.name, for: provider) }
                                }
                            ) {
                                NolonUI.ProviderLogoView(
                                    name: mcp.name,
                                    logoName: mcpLogoName(mcp),
                                    highlightQuery: viewModel.searchText,
                                    style: .horizontal,
                                    iconSize: 24
                                )
                            } extraContextMenu: {
                                debugPageMarkerMenuItem(
                                    markerBaseItems + [PageMarkerItem(title: mcp.name)]
                                )
                            }
                            .debugCardLocator(markerBaseItems + [PageMarkerItem(title: mcp.name)])
                            .onTapGesture {
                                editingConfig = EditingConfig(
                                    configURL: configPath,
                                    format: isToml ? .toml : .json,
                                    highlightKey: mcp.name
                                )
                            }
                        }
                        }
                    }
                }
            } else {
                NolonUI.McpConfigUnsupportedStateView()
            }
        }
        .sheet(item: $editingConfig) { config in
            McpConfigEditorView(
                configURL: config.configURL,
                format: config.format,
                highlightKey: config.highlightKey
            ) { _ in
                await viewModel.loadData()
            }
        }
        .messageAlert(
            alert: $migrationAlert
        )
    }
}

private struct EditingConfig: Identifiable {
    let id = UUID()
    let configURL: URL
    let format: NolonUI.WebCodeEditorFormat
    let highlightKey: String?
}

private func mcpCommandText(_ mcp: MCP) -> String? {
    guard let dict = mcp.json.value as? [String: Any] else { return nil }
    return dict["command"] as? String
}

private extension ProviderDetailGridViewModel.McpCacheState {
    var uiCacheState: McpServerCardCacheState {
        switch self {
        case .notMigrated:
            return .notMigrated
        case .migratedUpToDate:
            return .migratedUpToDate
        case .migratedNeedsUpdate:
            return .migratedNeedsUpdate
        }
    }
}

private func mcpLogoName(_ mcp: MCP) -> String? {
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

#Preview {
    ProviderMcpGridView(
        provider: nil,
        viewModel: ProviderDetailGridViewModel(provider: nil, settings: .shared),
        columns: [GridItem(.flexible())],
        markerBaseItems: []
    )
}
