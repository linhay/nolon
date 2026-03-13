import SwiftUI
import ProviderCatalog
import AppKit
import NolonResourceKit

/// 资源中心 MCP 卡片视图 - Grid 布局中的卡片
struct RemoteMCPCardView: View, DebugPageLocatable {
    let mcp: RemoteMCP
    let isInstalled: Bool
    let isInstalling: Bool
    let installErrorMessage: String?
    let isSelected: Bool
    let targetProvider: Provider?
    let providers: [Provider]
    let onInstall: (Provider) -> Void
    let onDeleteRequest: (() -> Void)?
    let isDeleting: Bool
    let onTap: () -> Void
    
    @State private var showingInstallSheet = false

    var debugPageMarkerItems: [PageMarkerItem] {
        [
            .init(title: "MCP Card"),
            .init(title: mcp.displayName)
        ]
    }
    
    var body: some View {
        ResourceCardShell(
            minHeight: 160,
            isSelected: isSelected,
            locatorItems: debugPageMarkerItems,
            onTap: onTap,
            headerContent: { headerView },
            summaryContent: { summaryView },
            metaContent: { metaView },
            actionContent: { installActionView },
            menuContent: { contextMenuItems }
        )
        .sheet(isPresented: $showingInstallSheet) {
            MCPInstallSheet(providers: providers, mcpName: mcp.displayName) { provider in
                onInstall(provider)
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(mcp.displayName)
                .font(.headline.weight(.semibold))
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
    }

    @ViewBuilder
    private var summaryView: some View {
        if let summary = mcp.summary {
            Text(summary)
                .dsSecondaryText(font: .subheadline)
                .lineSpacing(2)
                .lineLimit(3)
                .frame(maxHeight: .infinity, alignment: .topLeading)
        } else {
            Spacer()
        }
    }

    @ViewBuilder
    private var metaView: some View {
        let items = ResourceCardMetaBuilder.mcpItems(mcp)
        if items.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    metaLabel(for: item)
                }
            }
        }
    }

    private var installActionView: some View {
        ResourceInstallStateView(
            isInstalled: isInstalled,
            isInstalling: isInstalling,
            errorMessage: installErrorMessage,
            onInstall: handleInstall,
            onRetry: handleInstall
        )
    }
    
    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            onTap()
        } label: {
            Label(NSLocalizedString("View Details", comment: "View resource details"), systemImage: "info.circle")
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

        if !isInstalled && !isInstalling {
            Divider()
            Button {
                handleInstall()
            } label: {
                Label(NSLocalizedString("action.install", value: "Install", comment: "Install action"), systemImage: "arrow.down.circle")
                    .dsIconLabelButton()
            }
        }

        if isInstalled && !isDeleting {
            Divider()
            Button(role: .destructive) {
                onDeleteRequest?()
            } label: {
                Label(NSLocalizedString("action.delete", value: "Delete", comment: "Delete action"), systemImage: "trash")
                    .dsIconLabelButton()
            }
            .disabled(onDeleteRequest == nil)
        }

        if let config = mcp.configuration, let command = config.command {
            Divider()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            } label: {
                Label(NSLocalizedString("Copy Command", comment: "Copy command"), systemImage: "doc.on.doc")
                    .dsIconLabelButton()
            }
        }
    }
    
    private func handleInstall() {
        if let target = targetProvider {
            onInstall(target)
        } else {
            showingInstallSheet = true
        }
    }

    @ViewBuilder
    private func metaLabel(for item: ResourceCardMetaItem) -> some View {
        switch item {
        case let .stars(value):
            Label("\(value)", systemImage: "star.fill")
                .dsIconLabelText(foreground: DesignSystem.Colors.Status.warning, font: .caption2)
        case let .downloads(value):
            Label("\(value)", systemImage: "arrow.down.circle")
                .dsIconLabelText()
        case let .usages(value):
            Label("\(value)", systemImage: "arrow.triangle.branch")
                .dsIconLabelText()
        case let .installs(value):
            Label("\(value)", systemImage: "server.rack")
                .dsIconLabelText()
        case let .command(value):
            HStack(spacing: 4) {
                Image(systemName: "terminal")
                    .font(.caption2)
                Text(value)
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .dsBadge(
                foreground: DesignSystem.Colors.Text.secondary,
                background: DesignSystem.Colors.Component.controlFillSubtle,
                horizontalPadding: 6,
                verticalPadding: 3,
                cornerRadius: DesignSystem.Metrics.cornerRadiusXS
            )
            .frame(maxWidth: 160, alignment: .leading)
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
