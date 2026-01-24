import SwiftUI
internal import AnyCodable

struct McpServerCard: View {
    let mcp: MCP
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mcp.name)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "server.rack") // Or a specific icon for server
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            // Command details
            if let dict = mcp.json.value as? [String: Any],
               let command = dict["command"] as? String {
                Text(command)
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
}
