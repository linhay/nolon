import SwiftUI
import ProviderCatalog
import NolonResourceKit
import NolonUI
import NolonUIFoundation

/// View for managing skills by provider
@MainActor
public struct ProviderSkillsView: View {
    @State private var viewModel = ProviderSkillsViewModel()
    let onRefresh: () async -> Void

    public init(
        repository: SkillRepository,
        installer: SkillInstaller,
        onRefresh: @escaping () async -> Void
    ) {
        self.onRefresh = onRefresh
    }

    public var body: some View {
        NolonUI.NavigationTopContentScaffold {
            NolonUI.ProviderSkillsTopControlsView(
                providers: providerOptions,
                selectedProviderIndex: $viewModel.selectedProviderIndex,
                showsMigrationBanner: viewModel.hasOrphanedSkills,
                onMigrateAll: {
                    Task {
                        await viewModel.migrateAll()
                    }
                }
            )
        } content: {
            NolonUI.PaddedScrollContainer {
                NolonUI.ProviderGridContentScaffold(
                    isEmpty: viewModel.providerStates.isEmpty,
                    columns: [GridItem(.adaptive(minimum: 200, maximum: 280))],
                    spacing: 16
                ) {
                        ForEach(viewModel.providerStates, id: \.skillName) { state in
                            NolonUI.ProviderSkillCardView(
                                state: providerSkillCardInfo(from: state),
                                hasUpdate: viewModel.skillHasUpdate(state.skillName),
                                onUninstall: { await viewModel.uninstallSkill(at: state.path) },
                                onMigrate: { await viewModel.migrateSkill(skillName: state.skillName) },
                                onRepair: { await viewModel.repairSymlink(skillName: state.skillName) },
                                onDelete: { await viewModel.deletePath(state.path) },
                                onUpdate: {
                                    if let update = viewModel.availableUpdates.first(where: { $0.id == state.skillName }) {
                                        await viewModel.performUpdate(update)
                                    }
                                }
                            )
                        }
                }
            }
        }
        .task(id: viewModel.selectedProviderIndex) {
             viewModel.onRefreshHandler = onRefresh
             await viewModel.loadProviderStates()
             await viewModel.checkForUpdates()
        }
        .messageAlert(
            title: NSLocalizedString("generic.error", comment: "Error"),
            message: $viewModel.errorMessage
        )
    }

    private var providerOptions: [ProviderSkillsOption] {
        viewModel.settings.providers.map {
            ProviderSkillsOption(id: $0.id, title: $0.displayName)
        }
    }

    private func providerSkillCardInfo(from state: ProviderSkillState) -> NolonUIFoundation.ProviderSkillCardInfo {
        let mappedState: NolonUIFoundation.ProviderSkillCardState
        switch state.state {
        case .installed:
            mappedState = .installed
        case .orphaned:
            mappedState = .orphaned
        case .broken:
            mappedState = .broken
        }

        return NolonUIFoundation.ProviderSkillCardInfo(
            skillName: state.skillName,
            state: mappedState,
            path: state.path
        )
    }
}
