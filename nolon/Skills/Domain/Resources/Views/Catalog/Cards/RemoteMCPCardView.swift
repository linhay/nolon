import SwiftUI
import ProviderCatalog
import AppKit
import NolonResourceKit
import NolonUI
import NolonUIFoundation

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
            Divider()
            ResourceCopyTitleMenuItem(titleToCopy: mcp.displayName) { title in
                ResourceCardCopySupport.copyTitle(title)
            }
            debugPageMarkerMenuItem(debugPageMarkerItems)
        }
        .textSelection(.disabled)
        .debugCardLocator(debugPageMarkerItems)
        .installProviderSelectionSheet(
            isPresented: $showingInstallSheet,
            itemName: mcp.displayName,
            providers: providerOptions
        ) { providerID in
            guard let provider = providers.first(where: { $0.id == providerID }) else {
                return
            }
            onInstall(provider)
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
        ResourceCardMetaBuilder.mcpItems(mcp)
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

    private var providerOptions: [SkillInstallProviderOption] {
        providers.map { provider in
            SkillInstallProviderOption(
                id: provider.id,
                name: provider.name,
                iconName: provider.iconName
            )
        }
    }
}
