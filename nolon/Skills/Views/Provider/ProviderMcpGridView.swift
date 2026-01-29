import SwiftUI
import STFilePath

struct ProviderMcpGridView: View {
    let provider: Provider?
    let viewModel: ProviderDetailGridViewModel
    let columns: [GridItem]

    @State private var editingMcp: MCP?
    
    var body: some View {
        if let provider = provider,
           let templateId = provider.templateId,
           let template = ProviderTemplate(rawValue: templateId) {
            
            let configPath = template.defaultMcpConfigPath
            let isToml = configPath.pathExtension.lowercased() == "toml"
            let exists = STFile(configPath).isExists
            
            if !exists {
                ContentUnavailableView {
                    Label("No Configuration", systemImage: "server.rack")
                } description: {
                    Text("MCP configuration file not found.")
                } actions: {
                    Button("Create Configuration") {
                        // Create directory if needed
                        STFolder(configPath.deletingLastPathComponent()).createIfNotExists()
                        // Create minimal config based on extension
                        if configPath.pathExtension.lowercased() == "toml" {
                            let template = """
                            model = ""
                            
                            [mcp_servers]
                            """
                            try? STFile(configPath).overlay(with: template)
                        } else {
                            try? STFile(configPath).overlay(with: "{}")
                        }
                        NSWorkspace.shared.selectFile(configPath.path, inFileViewerRootedAtPath: "")
                        // Reload data
                        Task { await viewModel.loadData() }
                    }
                }
            } else if viewModel.filteredMcps.isEmpty && viewModel.searchText.isEmpty {
                ContentUnavailableView {
                    Label("No Servers", systemImage: "server.rack")
                } description: {
                    Text("No MCP servers configured.")
                } actions: {
                    Button("Edit Configuration") {
                        NSWorkspace.shared.selectFile(configPath.path, inFileViewerRootedAtPath: "")
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
                             NSWorkspace.shared.selectFile(configPath.path, inFileViewerRootedAtPath: "")
                         }) {
                             Label("Edit Config", systemImage: "pencil")
                         }
                     }
                }
            } else if viewModel.filteredMcps.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No matching MCP servers found")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.filteredMcps) { mcp in
                        McpServerCard(
                            mcp: mcp,
                            hasWorkflow: viewModel.mcpWorkflowIds.contains(mcp.name),
                            searchText: viewModel.searchText,
                            onLinkWorkflow: { viewModel.linkMcpToWorkflow(mcp) },
                            onUnlinkWorkflow: { viewModel.unlinkMcpFromWorkflow(mcp) },
                            onSetEnabled: { enabled in
                                Task { await viewModel.setMCPEnabled(mcp, enabled: enabled, for: provider) }
                            },
                            onEdit: {
                                editingMcp = mcp
                            },
                            onDelete: {
                                Task { await viewModel.deleteMCP(named: mcp.name, for: provider) }
                            }
                        )
                    }
                }
                .sheet(item: $editingMcp) { mcp in
                    McpEditorView(mcp: mcp, isToml: isToml) { updated in
                        Task { await viewModel.updateMCP(updated, for: provider) }
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
                             NSWorkspace.shared.selectFile(configPath.path, inFileViewerRootedAtPath: "")
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
            )
        }
    }
}

#Preview {
    ProviderMcpGridView(provider: nil, viewModel: ProviderDetailGridViewModel(provider: nil, settings: .shared), columns: [GridItem(.flexible())])
}
