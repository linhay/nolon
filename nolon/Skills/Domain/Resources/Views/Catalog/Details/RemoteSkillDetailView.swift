import SwiftUI
import ProviderCatalog
import NolonResourceKit
import NolonUI

struct RemoteSkillDetailView: View {
    @State private var viewModel: SkillDetailViewModel
    let skill: RemoteSkill
    let providers: [Provider]
    var targetProvider: Provider? = nil
    var isInstalled: Bool = false
    let onInstall: (Provider) -> Void

    init(
        skill: RemoteSkill,
        providers: [Provider],
        targetProvider: Provider? = nil,
        isInstalled: Bool = false,
        onInstall: @escaping (Provider) -> Void
    ) {
        self.skill = skill
        self.providers = providers
        self.targetProvider = targetProvider
        self.isInstalled = isInstalled
        self.onInstall = onInstall
        self._viewModel = State(
            initialValue: SkillDetailViewModel(
                remoteSkill: skill,
                onInstall: { _, provider in
                    onInstall(provider)
                }
            )
        )
    }

    var body: some View {
        NolonUI.SkillDetailView(
            viewModel: viewModel.makeNolonUIViewModel(
                providers: targetProvider.map { [$0] } ?? providers,
                currentProvider: nil,
                onClose: {}
            )
        )
        .task {
            await viewModel.loadData(
                checkProviders: targetProvider.map { [$0] } ?? providers,
                currentProvider: nil
            )
        }
    }
}
