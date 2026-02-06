import SwiftUI
import ProviderCatalog
import AppKit

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
                            .dsBadge(
                                foreground: DesignSystem.Colors.secondary,
                                background: DesignSystem.Colors.secondary.opacity(0.15),
                                horizontalPadding: 6,
                                verticalPadding: 2
                            )
                    }
                }
                
                Spacer()
                
                moreMenu
            }
            
            // 2. Description 区
            if let summary = mcp.summary {
                Text(summary)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
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
                .dsBadge(
                    foreground: DesignSystem.Colors.Text.secondary,
                    background: DesignSystem.Colors.Component.controlFillSubtle,
                    horizontalPadding: 6,
                    verticalPadding: 3,
                    cornerRadius: DesignSystem.Metrics.cornerRadiusXS
                )
            }
            
            // 4. Footer: Stats & Actions
            HStack(alignment: .center) {
                // Left: Stats
                HStack(spacing: 8) {
                    if let stars = mcp.stats?.stars {
                        Label("\(stars)", systemImage: "star.fill")
                            .dsIconLabelText(foreground: DesignSystem.Colors.Status.warning, font: .caption2)
                    }
                    if let installs = mcp.stats?.installs {
                        Label("\(installs)", systemImage: "server.rack")
                            .dsIconLabelText()
                    }
                    if let downloads = mcp.stats?.downloads {
                        Label("\(downloads)", systemImage: "arrow.down.circle")
                            .dsIconLabelText()
                    }
                }
                
                Spacer()
                
                // Right: Install Action
                installActionView
            }
        }
        .padding(16)
        .frame(minHeight: 160)
        .dsCard()
        .contentShape(Rectangle())
        .shadow(color: DesignSystem.Colors.Shadow.floating.opacity(isHovered ? 0.75 : 0.25), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
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
            .fontWeight(.semibold)
            .dsBadge(
                foreground: DesignSystem.Colors.Status.success,
                background: DesignSystem.Colors.Status.success.opacity(0.10)
            )
        } else {
            Button {
                handleInstall()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                    Text("Install")
                }
                .fontWeight(.bold)
                .dsBadge(
                    foreground: DesignSystem.Colors.secondary,
                    background: DesignSystem.Colors.secondary.opacity(0.10),
                    horizontalPadding: 10,
                    verticalPadding: 6
                )
            }
            .dsLinkButton()
        }
    }
    
    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            onTap()
        } label: {
            Label("View Details", systemImage: "info.circle")
                .dsIconLabelButton()
        }

        if let revealURL = revealInFinderURL {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([revealURL])
            } label: {
                Label(NSLocalizedString("action.show_in_finder", comment: "Show in Finder"), systemImage: "folder")
                    .dsIconLabelButton()
            }
        }

        if !isInstalled {
            Divider()
            Button {
                handleInstall()
            } label: {
                Label("Install", systemImage: "arrow.down.circle")
                    .dsIconLabelButton()
            }
        }

        if let config = mcp.configuration, let command = config.command {
            Divider()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            } label: {
                Label("Copy Command", systemImage: "doc.on.doc")
                    .dsIconLabelButton()
            }
        }
    }
    
    private var moreMenu: some View {
        Menu {
            contextMenuItems
        } label: {
            Image(systemName: "ellipsis")
                .dsIconButton()
        }
        .dsBorderlessMenu()
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

    private var revealInFinderURL: URL? {
        var candidates: [URL] = []

        if let localPath = mcp.localPath {
            candidates.append(URL(fileURLWithPath: (localPath as NSString).expandingTildeInPath))
        }

        if let provider = targetProvider,
           let templateId = provider.templateId,
           let template = ProviderTemplate(rawValue: templateId) {
            let configPath = template.defaultMcpConfigPath
            candidates.append(configPath)
        }

        candidates.append(NolonManager.shared.mcpsURL.appendingPathComponent("\(mcp.slug).json"))
        candidates.append(NolonManager.shared.mcpsURL.appendingPathComponent(mcp.slug))

        return candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) })
    }
}

/// MCP 安装选择 Sheet
private struct MCPInstallSheet: View {
    let providers: [Provider]
    let mcpName: String
    let onInstall: (Provider) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(
                title: NSLocalizedString("Install", comment: "Install"),
                subtitle: mcpName
            ) {
                dismiss()
            }

            SheetDivider()

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
                    .dsLinkButton()
                }
            }
            .sheetScrollContentPadding()

            SheetDivider()

            HStack(spacing: 12) {
                Button(NSLocalizedString("Cancel", comment: "Cancel")) {
                    dismiss()
                }
                .dsLinkButton()
                .keyboardShortcut(.cancelAction)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, SheetLayout.footerHorizontalPadding)
            .padding(.vertical, SheetLayout.footerVerticalPadding)
        }
        .frame(width: 420, height: 520)
    }
}
