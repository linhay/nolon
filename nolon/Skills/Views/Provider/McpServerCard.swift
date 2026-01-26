import SwiftUI
internal import AnyCodable

struct McpServerCard: View {
    let mcp: MCP
    var hasWorkflow: Bool = false
    let searchText: String
    let onDelete: () -> Void
    let onEdit: () -> Void
    var onLinkWorkflow: () -> Void = {}
    var onUnlinkWorkflow: () -> Void = {}
    var onToggleEnabled: () -> Void = {}
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. Header: Title | Menu
            HStack(alignment: .center) {
                ProviderLogoView(name: mcp.name, logoName: mcpLogoName, highlightQuery: searchText, style: .horizontal, iconSize: 20)
                
                Spacer()
                
                moreMenu
            }
            
            // 2. Version: (Hidden for MCP)
            
            // 3. Description: Command details
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
            
            Spacer(minLength: 0)
            
            // 4. Action Area: Rounded rectangle buttons
            HStack(spacing: 8) {
                Button {
                    hasWorkflow ? onUnlinkWorkflow() : onLinkWorkflow()
                } label: {
                    Label("Workflow", systemImage: "arrow.triangle.branch")
                }
                .buttonStyle(.bordered)
                .tint(hasWorkflow ? .blue : .secondary)
                .controlSize(.small)
                
                // Toggle Button
                if let disabled = mcp.disabled {
                    Button {
                        onToggleEnabled()
                    } label: {
                        Label(!disabled ? "Enabled" : "Disabled", systemImage: !disabled ? "bolt.fill" : "bolt.slash")
                    }
                    .buttonStyle(.bordered)
                    .tint(!disabled ? .accentColor : .secondary)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .background(mcp.disabled == true ? Color.secondary.opacity(0.04) : Color.secondary.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .opacity(mcp.disabled == true ? 0.7 : 1.0)
        .contentShape(Rectangle())
        .contextMenu {
             Button(action: onEdit) {
                 Label("Edit", systemImage: "pencil")
             }
             
             if hasWorkflow {
                 Button(role: .destructive, action: onUnlinkWorkflow) {
                     Label("Delete Workflow", systemImage: "link.badge.plus")
                 }
             } else {
                 Button(action: onLinkWorkflow) {
                     Label("Link to Workflow", systemImage: "link")
                 }
             }
             
             Divider()
             
             Button(role: .destructive, action: onDelete) {
                 Label("Delete", systemImage: "trash")
             }
        }
    }
    
    private var moreMenu: some View {
        Menu {
             Button(action: onEdit) {
                 Label("Edit", systemImage: "pencil")
             }
             
             if hasWorkflow {
                 Button(role: .destructive, action: onUnlinkWorkflow) {
                     Label("Delete Workflow", systemImage: "link.badge.plus")
                 }
             } else {
                 Button(action: onLinkWorkflow) {
                     Label("Link to Workflow", systemImage: "link")
                 }
             }
             
             Divider()
             
             Button(role: .destructive, action: onDelete) {
                 Label("Delete", systemImage: "trash")
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
