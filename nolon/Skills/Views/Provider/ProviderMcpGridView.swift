import SwiftUI
import ProviderCatalog
import STFilePath

struct ProviderMcpGridView: View {
    let provider: Provider?
    let viewModel: ProviderDetailGridViewModel
    let columns: [GridItem]

    @State private var editingConfig: EditingConfig?
    @State private var migrationAlert: MigrationAlert?
    
    var body: some View {
        Group {
            if let provider = provider,
               let templateId = provider.templateId,
               let template = ProviderTemplate(rawValue: templateId) {
            
            let configPath = template.defaultMcpConfigPath
            let isToml = configPath.pathExtension.lowercased() == "toml"
            let exists = STFile(configPath).isExists
            
            if !exists {
                ContentUnavailableView {
                    Label {
                        Text("No Configuration")
                            .dsEmptyStateTitle()
                    } icon: {
                        Image(systemName: "server.rack")
                            .dsEmptyStateIcon()
                    }
                } description: {
                    Text("MCP configuration file not found.")
                        .dsSecondaryText(font: .body)
                } actions: {
                    Button("Create Configuration") {
                        // Create directory if needed
                        _ = STFolder(configPath.deletingLastPathComponent()).createIfNotExists()
                        // Create minimal config based on extension
                        if configPath.pathExtension.lowercased() == "toml" {
                            let template = """
                            model = ""
                            
                            [mcp_servers]
                            """
                            try? STFile(configPath).overlay(with: template)
                        } else {
                            if template.rawValue == "opencode" {
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
                        // Reload data
                        Task { await viewModel.loadData() }
                    }
                    .dsIconLabelButton()
                }
            } else if viewModel.filteredMcps.isEmpty && viewModel.searchText.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text("No Servers")
                            .dsEmptyStateTitle()
                    } icon: {
                        Image(systemName: "server.rack")
                            .dsEmptyStateIcon()
                    }
                } description: {
                    Text("No MCP servers configured.")
                        .dsSecondaryText(font: .body)
                } actions: {
                    Button("Edit Configuration") {
                        editingConfig = EditingConfig(
                            configURL: configPath,
                            format: isToml ? .toml : .json,
                            highlightKey: nil
                        )
                    }
                    .dsIconLabelButton()
                }
                .toolbar {
                     if let url = template.mcpDocumentationURL {
                         ToolbarItem {
                             Link(destination: url) {
                                 Label("Documentation", systemImage: "doc.text")
                                    .dsIconLabelButton()
                             }
                         }
                     }
                     ToolbarItem {
                         Button(action: {
                             editingConfig = EditingConfig(
                                 configURL: configPath,
                                 format: isToml ? .toml : .json,
                                 highlightKey: nil
                             )
                         }) {
                             Label("Edit Config", systemImage: "pencil")
                                .dsIconLabelButton()
                         }
                     }
                }
            } else if viewModel.filteredMcps.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No matching MCP servers found")
                        .dsSecondaryText(font: .body)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.filteredMcps) { mcp in
                        let cacheState = viewModel.mcpCacheStates[mcp.name] ?? .notMigrated
                        McpServerCard(
                            mcp: mcp,
                            hasWorkflow: viewModel.mcpWorkflowIds.contains(mcp.name),
                            searchText: viewModel.searchText,
                            cacheState: cacheState,
                            onLinkWorkflow: { viewModel.linkMcpToWorkflow(mcp) },
                            onUnlinkWorkflow: { viewModel.unlinkMcpFromWorkflow(mcp) },
                            onSetEnabled: { enabled in
                                Task { await viewModel.setMCPEnabled(mcp, enabled: enabled, for: provider) }
                            },
                            onMigrateToNolon: {
                                Task {
                                    do {
                                        try await viewModel.migrateMcpToGlobalCache(mcp)
                                        migrationAlert = MigrationAlert(
                                            title: NSLocalizedString("action.migrate", value: "Migrate", comment: "Migrate"),
                                            message: NSLocalizedString(
                                                "mcp.migration.single.success",
                                                value: "Migrated.",
                                                comment: "MCP single migration success"
                                            )
                                        )
                                    } catch {
                                        migrationAlert = MigrationAlert(
                                            title: NSLocalizedString("action.migrate", value: "Migrate", comment: "Migrate"),
                                            message: error.localizedDescription
                                        )
                                    }
                                }
                            },
                            onUpdateNolonCache: {
                                Task {
                                    do {
                                        try await viewModel.updateCachedMcpIfNeeded(mcp)
                                        migrationAlert = MigrationAlert(
                                            title: NSLocalizedString("action.update", value: "Update", comment: "Update"),
                                            message: NSLocalizedString(
                                                "mcp.migration.single.updated",
                                                value: "Updated.",
                                                comment: "MCP single cache update success"
                                            )
                                        )
                                    } catch {
                                        migrationAlert = MigrationAlert(
                                            title: NSLocalizedString("action.update", value: "Update", comment: "Update"),
                                            message: error.localizedDescription
                                        )
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
                                Task { await viewModel.deleteMCP(named: mcp.name, for: provider) }
                            }
                        )
                        .onTapGesture {
                            editingConfig = EditingConfig(
                                configURL: configPath,
                                format: isToml ? .toml : .json,
                                highlightKey: mcp.name
                            )
                        }
                    }
                }
                .toolbar {
                     if let url = template.mcpDocumentationURL {
                         ToolbarItem {
                             Link(destination: url) {
                                 Label("Documentation", systemImage: "doc.text")
                             }
                         }
                     }
                     ToolbarItem {
                         Button(action: {
                             editingConfig = EditingConfig(
                                 configURL: configPath,
                                 format: isToml ? .toml : .json,
                                 highlightKey: nil
                             )
                         }) {
                             Label("Edit Config", systemImage: "pencil")
                         }
                     }
                }
            }
            } else {
             ContentUnavailableView(
                NSLocalizedString("mcp.not_supported", comment: "MCP Not Supported"),
                systemImage: "exclamationmark.triangle",
                description: Text(NSLocalizedString("mcp.not_supported_desc", comment: "This provider does not support MCP configuration"))
                    .dsSecondaryText(font: .body)
            )
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
        .alert(migrationAlert?.title ?? "", isPresented: Binding(get: { migrationAlert != nil }, set: { if !$0 { migrationAlert = nil } })) {
            Button(NSLocalizedString("action.ok", value: "OK", comment: "OK action")) {}
        } message: {
            Text(migrationAlert?.message ?? "")
        }
    }
}

private struct EditingConfig: Identifiable {
    let id = UUID()
    let configURL: URL
    let format: WebCodeEditorFormat
    let highlightKey: String?
}

private struct MigrationAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    ProviderMcpGridView(provider: nil, viewModel: ProviderDetailGridViewModel(provider: nil, settings: .shared), columns: [GridItem(.flexible())])
}
