import SwiftUI
import ProviderCatalog
import NolonResourceKit
import NolonUI

struct SkillDetailView: View, DebugPageLocatable {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SkillDetailViewModel
    private let providers: [Provider]
    private let currentProvider: Provider?

    init(skill: Skill, provider: Provider?, settings: ProviderSettings) {
        self.currentProvider = provider
        self.providers = settings.providers
        self._viewModel = State(initialValue: SkillDetailViewModel(skill: skill, settings: settings))
    }

    init(
        remoteSkill: RemoteSkill,
        providers: [Provider],
        targetProvider: Provider? = nil,
        onInstall: @escaping (Provider) -> Void
    ) {
        self.currentProvider = nil
        self.providers = targetProvider.map { [$0] } ?? providers
        self._viewModel = State(
            initialValue: SkillDetailViewModel(
                remoteSkill: remoteSkill,
                onInstall: { _, provider in
                    onInstall(provider)
                }
            )
        )
    }

    var debugPageMarkerItems: [PageMarkerItem] {
        [
            PageMarkerItem(title: "Skill Detail"),
            PageMarkerItem(title: viewModel.title)
        ]
    }
    
    var body: some View {
        NolonUI.SkillDetailScaffold(onClose: { dismiss() }) {
                SkillDetailSidebar(
                    viewModel: viewModel,
                    providers: providers,
                    currentProvider: currentProvider
                )
        } content: {
                SkillDetailContent(viewModel: viewModel)
        }
        .task {
            await viewModel.loadData(checkProviders: providers, currentProvider: currentProvider)
        }
        .debugPageMarkerContextMenu(debugPageMarkerItems, withDivider: false) {
            EmptyView()
        }
        .debugPageLocator(debugPageMarkerItems)
    }
}
