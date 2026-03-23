import SwiftUI
import ProviderCatalog
import NolonResourceKit
import NolonUI

/// Skill 卡片视图 - Grid 布局中的卡片
struct SkillCardView: View {
    let skill: Skill
    let provider: Provider
    var hasWorkflow: Bool = false
    let searchText: String
    let onReveal: () -> Void
    let onUninstall: () async -> Void
    let onLinkWorkflow: () -> Void
    let onUnlinkWorkflow: () -> Void
    var onMigrate: () async -> Void = {}
    let onTap: () -> Void

    var body: some View {
        NolonUI.SkillCardView(
            name: skill.name,
            description: skill.description,
            version: skill.version,
            isOrphaned: skill.installationState == .orphaned,
            hasWorkflow: hasWorkflow,
            referenceCount: skill.referenceCount,
            scriptCount: skill.scriptCount,
            searchText: searchText,
            onReveal: onReveal,
            onUninstall: onUninstall,
            onLinkWorkflow: onLinkWorkflow,
            onUnlinkWorkflow: onUnlinkWorkflow,
            onMigrate: onMigrate,
            onTap: onTap
        ) {
            debugPageMarkerMenuItem(
                [
                    PageMarkerItem(title: provider.displayName),
                    PageMarkerItem(title: NSLocalizedString("tab.skills", comment: "Skills")),
                    PageMarkerItem(title: skill.name)
                ]
            )
        }
    }
}
