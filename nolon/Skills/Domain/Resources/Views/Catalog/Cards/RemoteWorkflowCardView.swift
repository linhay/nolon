import SwiftUI
import ProviderCatalog
import AppKit
import NolonResourceKit
import NolonUI
import NolonUIFoundation

/// 资源中心 Workflow 卡片视图 - Grid 布局中的卡片
struct RemoteWorkflowCardView: View, DebugPageLocatable {
    let workflow: RemoteWorkflow
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
            .init(title: "Workflow Card"),
            .init(title: workflow.displayName)
        ]
    }
    
    var body: some View {
        NolonUI.ResourceWorkflowCardView(
            name: workflow.displayName,
            version: workflow.latestVersion?.version,
            summary: workflow.summary,
            metaItems: mappedMetaItems,
            isInstalled: isInstalled,
            isInstalling: isInstalling,
            installErrorMessage: installErrorMessage,
            isSelected: isSelected,
            isDeleting: isDeleting,
            onTap: onTap,
            onInstall: handleInstall,
            onRetry: handleInstall,
            onRevealInFinder: revealInFinderAction,
            onDeleteRequest: onDeleteRequest
        ) {
            Divider()
            ResourceCopyTitleMenuItem(titleToCopy: workflow.displayName) { title in
                ResourceCardCopySupport.copyTitle(title)
            }
            debugPageMarkerMenuItem(debugPageMarkerItems)
        }
        .textSelection(.disabled)
        .debugCardLocator(debugPageMarkerItems)
        .installProviderSelectionSheet(
            isPresented: $showingInstallSheet,
            itemName: workflow.displayName,
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
        ResourceCardMetaBuilder.workflowItems(workflow)
    }

    private var revealInFinderAction: (() -> Void)? {
        guard let revealURL = revealInFinderURL else {
            return nil
        }

        return {
            NSWorkspace.shared.activateFileViewerSelecting([revealURL])
        }
    }

    private var revealInFinderURL: URL? {
        var candidates: [URL] = []

        if isInstalled, let provider = targetProvider {
            let providerWorkflowPath = (provider.workflowPath as NSString).expandingTildeInPath
            let mdPath = (providerWorkflowPath as NSString).appendingPathComponent("\(workflow.slug).md")
            candidates.append(URL(fileURLWithPath: mdPath))
            let legacyPath = (providerWorkflowPath as NSString).appendingPathComponent(workflow.slug)
            candidates.append(URL(fileURLWithPath: legacyPath))
        }

        if let localPath = workflow.localPath {
            candidates.append(URL(fileURLWithPath: (localPath as NSString).expandingTildeInPath))
        }

        let globalWorkflowPath = NolonManager.shared.userWorkflowsURL.appendingPathComponent("\(workflow.slug).md")
        candidates.append(globalWorkflowPath)
        candidates.append(NolonManager.shared.userWorkflowsURL.appendingPathComponent(workflow.slug))

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
