import SwiftUI
import ProviderCatalog
import AppKit
import NolonResourceKit
import NolonUI
import NolonUIFoundation

/// 资源中心技能卡片视图 - Grid 布局中的卡片
struct RemoteSkillCardView: View, DebugPageLocatable {
    let skill: RemoteSkill
    let isInstalled: Bool
    let isInstalling: Bool
    let installErrorMessage: String?
    let isSelected: Bool = false
    let targetProvider: Provider?
    let providers: [Provider]
    let onInstall: (Provider) -> Void
    let onDeleteRequest: (() -> Void)?
    let isDeleting: Bool
    let onTap: () -> Void
    
    @State private var showingInstallSheet = false

    var debugPageMarkerItems: [PageMarkerItem] {
        [
            .init(title: "Skill Card"),
            .init(title: skill.displayName)
        ]
    }
    
    var body: some View {
        NolonUI.ResourceSkillCardView(
            name: skill.displayName,
            version: skill.latestVersion?.version,
            summary: skill.summary,
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
            if UITestSupport.shouldExposeDirectDeleteButton,
               (isInstalled || UITestSupport.isEnabled),
               !isDeleting,
               onDeleteRequest != nil {
                Button(role: .destructive) {
                    handleUITestDirectDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("uitest.direct-delete.skill.\(skill.slug)")
            }
        } extraContextMenu: {
            Divider()
            ResourceCopyTitleMenuItem(titleToCopy: skill.displayName) { title in
                ResourceCardCopySupport.copyTitle(title)
            }
            debugPageMarkerMenuItem(debugPageMarkerItems)
        }
        .textSelection(.disabled)
        .debugCardLocator(debugPageMarkerItems)
        .installProviderSelectionSheet(
            isPresented: $showingInstallSheet,
            itemName: skill.displayName,
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

    private func handleUITestDirectDelete() {
        onDeleteRequest?()
    }

    private var mappedMetaItems: [NolonUI.ResourceCardMetaItem] {
        ResourceCardMetaBuilder.skillItems(skill)
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
            let providerSkillsPath = (provider.defaultSkillsPath as NSString).expandingTildeInPath
            let path = (providerSkillsPath as NSString).appendingPathComponent(skill.slug)
            candidates.append(URL(fileURLWithPath: path))
        }

        if let localPath = skill.localPath {
            candidates.append(URL(fileURLWithPath: (localPath as NSString).expandingTildeInPath))
        }

        if isInstalled {
            candidates.append(NolonManager.shared.skillsURL.appendingPathComponent(skill.slug))
        }

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
