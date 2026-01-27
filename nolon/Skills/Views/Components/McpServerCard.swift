import SwiftUI
internal import AnyCodable

/// MCP Server 卡片视图 - Grid 布局中的卡片
struct McpServerCard: View {
    let mcp: MCP
    let hasWorkflow: Bool
    let searchText: String
    let onLinkWorkflow: () -> Void
    let onUnlinkWorkflow: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. 标题 | 更多菜单
            HStack(alignment: .center) {
                ProviderLogoView(
                    name: mcp.name,
                    logoName: mcpLogoName,
                    highlightQuery: searchText,
                    style: .horizontal,
                    iconSize: 24
                )
                
                Spacer()
                
                moreMenu
            }
            
            // 2. 命令详情 (替代描述区)
            VStack(alignment: .leading, spacing: 4) {
                if let dict = mcp.json.value as? [String: Any],
                   let command = dict["command"] as? String {
                    HighlightedText(text: command, query: searchText)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                } else {
                    Text("No command specified")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
            
            // 3. 操作区: 工作流 圆角矩形按钮 + 编辑/删除
            HStack {
                if hasWorkflow {
                    Button {
                        onUnlinkWorkflow()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.branch")
                            Text("Workflow")
                        }
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        onLinkWorkflow()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                            Text(NSLocalizedString("action.link_workflow", comment: "Link to Workflow"))
                        }
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.12))
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .frame(minHeight: 140)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(12)
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
            Text(NSLocalizedString("action.delete_confirm_message_mcp", value: "Are you sure you want to delete this MCP server? This will remove its configuration.", comment: "MCP Delete confirmation message"))
        }
    }
    
    @ViewBuilder
    private var contextMenuItems: some View {
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
        }
        
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            Label(NSLocalizedString("action.delete", comment: "Delete"), systemImage: "trash")
        }
    }
    
    private var moreMenu: some View {
        Menu {
            contextMenuItems
        } label: {
            Image(systemName: "ellipsis")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
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
