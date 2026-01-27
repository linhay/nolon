import SwiftUI

/// Workflow 来源类型
enum WorkflowSource: String, CaseIterable {
    case skill      // 从技能生成的
    case user       // 用户自定义的
    case mcp        // MCP 相关的
    case unknown    // 未知
    
    var displayName: String {
        switch self {
        case .skill: return NSLocalizedString("workflow.source.skill", value: "Skill", comment: "Source: Skill")
        case .user: return NSLocalizedString("workflow.source.user", value: "User", comment: "Source: User")
        case .mcp: return NSLocalizedString("workflow.source.mcp", value: "MCP", comment: "Source: MCP")
        case .unknown: return NSLocalizedString("workflow.source.unknown", value: "Unknown", comment: "Source: Unknown")
        }
    }
    
    var color: Color {
        switch self {
        case .skill: return .blue
        case .user: return .orange
        case .mcp: return .purple
        case .unknown: return .secondary
        }
    }
}

/// Workflow 信息模型
struct WorkflowInfo: Identifiable, Hashable {
    let id: String  // 文件名
    let name: String
    let description: String
    let path: String
    let source: WorkflowSource
    
    static func parse(from url: URL) -> WorkflowInfo? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        
        let path = url.path
        let resolvedPath = url.resolvingSymlinksInPath().path
        let fileName = url.deletingPathExtension().lastPathComponent
        var description = ""
        
        // Determine source based on path
        let source: WorkflowSource
        let nolon = NolonManager.shared
        if resolvedPath.hasPrefix(nolon.generatedWorkflowsPath) {
            source = .skill
        } else if resolvedPath.hasPrefix(nolon.mcpsWorkflowsPath) {
            source = .mcp
        } else if resolvedPath.hasPrefix(nolon.userWorkflowsPath) {
            source = .user
        } else if path.contains("Skills/Workflows") || path.contains(".gemini/workflows") {
            // Also check for common provider internal paths if needed
            source = .skill
        } else {
            source = .unknown
        }
        
        // Parse YAML frontmatter for description
        let metadata = SkillParser.parseMetadata(from: content)
        description = metadata["description"] ?? ""
        
        return WorkflowInfo(
            id: fileName,
            name: fileName,
            description: description.isEmpty ? "No description" : description,
            path: path,
            source: source
        )
    }
}

/// Workflow 卡片视图
struct WorkflowCardView: View {
    let workflow: WorkflowInfo
    let searchText: String
    let onReveal: () -> Void
    let onDelete: () async -> Void
    let onTap: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. 标题 (Name + Source Badge) | 更多菜单
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    HighlightedText(text: workflow.name, query: searchText)
                        .font(.headline)
                        .lineLimit(1)
                    
                    sourceBadge
                }
                
                Spacer()
                
                moreMenu
            }
            
            // 2. 描述区
            HighlightedText(text: workflow.description, query: searchText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxHeight: .infinity, alignment: .topLeading)
            
            // 3. 操作区
            HStack {
                Label("Workflow", systemImage: "arrow.triangle.branch")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
        }
        .padding(16)
        .frame(minHeight: 140)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            contextMenuItems
        }
        .confirmationDialog(
            NSLocalizedString("action.delete_confirm_title", value: "Confirm Delete", comment: "Delete confirmation title"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("action.delete", comment: "Delete"), role: .destructive) {
                Task { await onDelete() }
            }
            Button(NSLocalizedString("action.cancel", value: "Cancel", comment: "Cancel action"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("action.delete_confirm_message", value: "Are you sure you want to delete this workflow? This action cannot be undone.", comment: "Delete confirmation message"))
        }
    }
    
    @ViewBuilder
    private var sourceBadge: some View {
        Text(workflow.source.displayName)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(workflow.source.color.opacity(0.15))
            .foregroundStyle(workflow.source.color)
            .clipShape(Capsule())
    }
    
    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            onReveal()
        } label: {
            Label(
                NSLocalizedString("action.show_in_finder", comment: "Show in Finder"),
                systemImage: "folder"
            )
        }
        
        Divider()
        
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            Label(
                NSLocalizedString("action.delete", comment: "Delete"),
                systemImage: "trash"
            )
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
}
