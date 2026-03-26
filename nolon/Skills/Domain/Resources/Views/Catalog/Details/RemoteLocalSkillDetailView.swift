import SwiftUI
import NolonResourceKit
import ProviderCatalog
import NolonUI

struct RemoteLocalSkillDetailView: View {
    let skill: RemoteSkill
    let localPath: String

    var body: some View {
        SkillDetailView(
            remoteSkill: resolvedSkill,
            providers: ProviderSettings.shared.providers
        ) { _ in }
    }

    private var resolvedSkill: RemoteSkill {
        RemoteSkill(
            slug: skill.slug,
            displayName: skill.displayName,
            summary: skill.summary,
            latestVersion: skill.latestVersion?.version,
            updatedAt: Date(timeIntervalSince1970: skill.updatedAt),
            downloads: skill.stats?.downloads,
            stars: skill.stats?.stars,
            localPath: localPath
        )
    }
}
