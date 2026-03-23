import SwiftUI
import ProviderCatalog
import AppKit
import NolonResourceKit
import NolonUI

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
        NolonUI.ResourceMcpCardView(
            name: mcp.displayName,
            version: mcp.latestVersion?.version,
            summary: mcp.summary,
            metaItems: mappedMetaItems,
            command: mcp.configuration?.command,
            isInstalled: isInstalled,
            isInstalling: isInstalling,
            installErrorMessage: installErrorMessage,
            isSelected: isSelected,
            isDeleting: isDeleting,
            onTap: onTap,
            onInstall: handleInstall,
            onRetry: handleInstall,
            onRevealInFinder: revealInFinderAction,
            onDeleteRequest: onDeleteRequest,
            onCopyCommand: copyCommandAction
        ) {
            debugPageMarkerMenuItem(debugPageMarkerItems)
        }
        .debugCardLocator(debugPageMarkerItems)
        .sheet(isPresented: $showingInstallSheet) {
            MCPInstallSheet(providers: providers, mcpName: mcp.displayName) { provider in
                onInstall(provider)
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

    private var mappedMetaItems: [NolonUI.ResourceCardMetaItem] {
        ResourceCardMetaBuilder.mcpItems(mcp).map { item in
            switch item {
            case let .stars(value):
                return .stars(value)
            case let .downloads(value):
                return .downloads(value)
            case let .usages(value):
                return .usages(value)
            case let .installs(value):
                return .installs(value)
            case let .command(value):
                return .command(value)
            }
        }
    }

    private var revealInFinderAction: (() -> Void)? {
        guard let revealURL = revealInFinderURL else {
            return nil
        }

        return {
            NSWorkspace.shared.activateFileViewerSelecting([revealURL])
        }
    }

    private var copyCommandAction: (() -> Void)? {
        guard let command = mcp.configuration?.command else {
            return nil
        }

        return {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
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
                    .buttonStyle(.plain)
                }
            }
            .sheetScrollContentPadding()

            SheetDivider()

            HStack(spacing: 12) {
                Button(NSLocalizedString("Cancel", comment: "Cancel")) {
                    dismiss()
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, SheetLayout.footerHorizontalPadding)
            .padding(.vertical, SheetLayout.footerVerticalPadding)
        }
        .frame(width: 420, height: 520)
    }
}
