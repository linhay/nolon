import SwiftUI

/// 远程 MCP 卡片视图 - Grid 布局中的卡片
struct RemoteMCPCardView: View {
    let mcp: RemoteMCP
    let isInstalled: Bool
    let targetProvider: Provider?
    let providers: [Provider]
    let onInstall: (Provider) -> Void
    let onTap: () -> Void
    
    @State private var showingInstallSheet = false
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. Header: Name + Version Badge | More Menu
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mcp.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let version = mcp.latestVersion {
                        Text(version.version)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15))
                            .foregroundStyle(Color.purple)
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                moreMenu
            }
            
            // 2. Description 区
            if let summary = mcp.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
            } else {
                Spacer()
            }
            
            // 3. Configuration Info (if available)
            if let config = mcp.configuration, let command = config.command {
                HStack(spacing: 4) {
                    Image(systemName: "terminal")
                        .font(.caption2)
                    Text(command)
                        .font(.system(size: 10, design: .monospaced))
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
            }
            
            // 4. Footer: Stats & Actions
            HStack(alignment: .center) {
                // Left: Stats
                HStack(spacing: 8) {
                    if let stars = mcp.stats?.stars {
                        Label("\(stars)", systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                    if let installs = mcp.stats?.installs {
                        Label("\(installs)", systemImage: "server.rack")
                    }
                    if let downloads = mcp.stats?.downloads {
                        Label("\(downloads)", systemImage: "arrow.down.circle")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                
                Spacer()
                
                // Right: Install Action
                installActionView
            }
        }
        .padding(16)
        .frame(minHeight: 160)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .shadow(color: .black.opacity(isHovered ? 0.15 : 0.05), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            contextMenuItems
        }
        .sheet(isPresented: $showingInstallSheet) {
            MCPInstallSheet(providers: providers, mcpName: mcp.displayName) { provider in
                onInstall(provider)
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var installActionView: some View {
        if isInstalled {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("Installed")
            }
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.green)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Button {
                handleInstall()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                    Text("Install")
                }
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.1))
                .foregroundStyle(Color.purple)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            onTap()
        } label: {
            Label("View Details", systemImage: "info.circle")
        }
        
        Divider()
        
        if !isInstalled {
            Button {
                handleInstall()
            } label: {
                Label("Install", systemImage: "arrow.down.circle")
            }
        }
        
        if let config = mcp.configuration {
            Divider()
            
            if let command = config.command {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                } label: {
                    Label("Copy Command", systemImage: "doc.on.doc")
                }
            }
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
    
    private func handleInstall() {
        if let target = targetProvider {
            onInstall(target)
        } else {
            showingInstallSheet = true
        }
    }
}

/// MCP 安装选择 Sheet
private struct MCPInstallSheet: View {
    let providers: [Provider]
    let mcpName: String
    let onInstall: (Provider) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Install '\(mcpName)' to...")
                .font(.headline)
            
            List {
                ForEach(providers) { provider in
                    Button {
                        onInstall(provider)
                        dismiss()
                    } label: {
                        HStack {
                            if !provider.iconName.isEmpty {
                                Image(provider.iconName)
                                    .resizable()
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: "folder")
                                    .frame(width: 24, height: 24)
                            }
                            
                            Text(provider.name)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}
