import SwiftUI
import NolonResourceKit
import ProviderCatalog
import NolonUI

struct RemoteLocalSkillDetailView: View {
    @State private var viewModel: SkillDetailViewModel
    let skill: RemoteSkill
    let localPath: String

    init(skill: RemoteSkill, localPath: String) {
        self.skill = skill
        self.localPath = localPath
        self._viewModel = State(initialValue: SkillDetailViewModel(remoteSkill: resolvedSkill(skill: skill, localPath: localPath)))
    }

    var body: some View {
        NolonUI.SkillDetailView(
            viewModel: viewModel.makeNolonUIViewModel(
                providers: ProviderSettings.shared.providers,
                currentProvider: nil,
                onClose: {}
            )
        )
        .task {
            await viewModel.loadData(checkProviders: ProviderSettings.shared.providers, currentProvider: nil)
        }
    }

    private static func resolvedSkill(skill: RemoteSkill, localPath: String) -> RemoteSkill {
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
