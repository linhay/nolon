import SwiftUI
internal import AnyCodable

struct McpServerCard: View {
    let mcp: MCP
    let searchText: String
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) {
                ProviderLogoView(name: mcp.name, logoName: mcpLogoName, highlightQuery: searchText, style: .horizontal, iconSize: 24)
                
                Spacer()
                
                if mcpLogoName == nil {
                    Image(systemName: "server.rack")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Command details
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
            
            // Actions
            HStack {
                Spacer()
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Edit Server")
                
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Delete Server")
            }
        }
        .padding()
        .frame(minHeight: 120)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .contextMenu {
             Button(action: onEdit) {
                 Label("Edit", systemImage: "pencil")
             }
             Button(role: .destructive, action: onDelete) {
                 Label("Delete", systemImage: "trash")
             }
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
