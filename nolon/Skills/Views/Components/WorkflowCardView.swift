import SwiftUI

/// Workflow 信息模型
struct WorkflowInfo: Identifiable, Hashable {
    let id: String  // 文件名
    let name: String
    let description: String
    let path: String
    
    static func parse(from url: URL) -> WorkflowInfo? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        
        let fileName = url.deletingPathExtension().lastPathComponent
        var description = ""
        
        // Parse YAML frontmatter for description
        if content.hasPrefix("---") {
            let parts = content.components(separatedBy: "---")
            if parts.count >= 3 {
                let frontmatter = parts[1]
                for line in frontmatter.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("description:") {
                        description = trimmed
                            .replacingOccurrences(of: "description:", with: "")
                            .trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
            }
        }
        
        return WorkflowInfo(
            id: fileName,
            name: fileName,
            description: description.isEmpty ? "No description" : description,
            path: url.path
        )
    }
}

/// Workflow 卡片视图
struct WorkflowCardView: View {
    let workflow: WorkflowInfo
    let onReveal: () -> Void
    let onDelete: () async -> Void
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Name
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workflow.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Label("Workflow", systemImage: "arrow.triangle.branch")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                moreMenu
            }
            
            // Description
            Text(workflow.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            
            Spacer(minLength: 0)
        }
        .padding()
        .frame(minHeight: 120)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private var moreMenu: some View {
        Menu {
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
                Task { await onDelete() }
            } label: {
                Label(
                    NSLocalizedString("action.delete", comment: "Delete"),
                    systemImage: "trash"
                )
            }
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
