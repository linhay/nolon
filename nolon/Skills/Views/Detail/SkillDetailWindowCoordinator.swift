import SwiftUI
import ProviderCatalog
import NolonResourceKit
import Observation

@MainActor
@Observable
final class SkillDetailWindowCoordinator {
    static let shared = SkillDetailWindowCoordinator()
    static let windowID = "skill-detail"

    enum Payload {
        case local(LocalPayload)
        case remote(RemotePayload)
    }

    struct LocalPayload {
        let skill: Skill
        let provider: Provider?
        let settings: ProviderSettings
    }

    struct RemotePayload {
        let skill: RemoteSkill
        let providers: [Provider]
        let targetProvider: Provider?
        let onInstall: (Provider) -> Void
    }

    var payload: Payload?

    private init() {}

    func presentLocal(skill: Skill, provider: Provider?, settings: ProviderSettings) {
        payload = .local(
            .init(
                skill: skill,
                provider: provider,
                settings: settings
            )
        )
    }

    func presentRemote(
        skill: RemoteSkill,
        providers: [Provider],
        targetProvider: Provider?,
        onInstall: @escaping (Provider) -> Void
    ) {
        payload = .remote(
            .init(
                skill: skill,
                providers: providers,
                targetProvider: targetProvider,
                onInstall: onInstall
            )
        )
    }
}

struct SkillDetailWindowRootView: View {
    @State private var coordinator = SkillDetailWindowCoordinator.shared

    var body: some View {
        Group {
            switch coordinator.payload {
            case .local(let payload):
                SkillDetailView(
                    skill: payload.skill,
                    provider: payload.provider,
                    settings: payload.settings
                )
            case .remote(let payload):
                SkillDetailView(
                    remoteSkill: payload.skill,
                    providers: payload.providers,
                    targetProvider: payload.targetProvider,
                    onInstall: payload.onInstall
                )
            case .none:
                ContentUnavailableView(
                    NSLocalizedString("detail.skill.empty.title", value: "No Skill Selected", comment: "Skill detail empty title"),
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(
                        NSLocalizedString("detail.skill.empty.desc", value: "Select a skill to view details.", comment: "Skill detail empty description")
                    )
                )
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}
