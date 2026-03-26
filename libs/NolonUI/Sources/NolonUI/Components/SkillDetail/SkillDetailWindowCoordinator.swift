import SwiftUI
import ProviderCatalog
import NolonResourceKit
import Observation

@MainActor
@Observable
public final class SkillDetailWindowCoordinator {
    public static let shared = SkillDetailWindowCoordinator()
    public static let windowID = "skill-detail"

    public enum Payload {
        case local(LocalPayload)
        case remote(RemotePayload)
    }

    public struct LocalPayload {
        public let skill: Skill
        public let provider: Provider?
        public let settings: ProviderSettings

        public init(skill: Skill, provider: Provider?, settings: ProviderSettings) {
            self.skill = skill
            self.provider = provider
            self.settings = settings
        }
    }

    public struct RemotePayload {
        public let skill: RemoteSkill
        public let providers: [Provider]
        public let targetProvider: Provider?
        public let onInstall: (Provider) -> Void

        public init(
            skill: RemoteSkill,
            providers: [Provider],
            targetProvider: Provider?,
            onInstall: @escaping (Provider) -> Void
        ) {
            self.skill = skill
            self.providers = providers
            self.targetProvider = targetProvider
            self.onInstall = onInstall
        }
    }

    public var payload: Payload?

    private init() {}

    public func presentLocal(skill: Skill, provider: Provider?, settings: ProviderSettings) {
        payload = .local(
            .init(
                skill: skill,
                provider: provider,
                settings: settings
            )
        )
    }

    public func presentRemote(
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

public struct SkillDetailWindowRootView: View {
    @State private var coordinator = SkillDetailWindowCoordinator.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dismissWindow) private var dismissWindow

    public init() {}

    public var body: some View {
        Group {
            switch coordinator.payload {
            case .local(let payload):
                SkillDetailView(
                    skill: payload.skill,
                    provider: payload.provider,
                    settings: payload.settings,
                    onClose: {
                        closeWindow()
                    }
                )
            case .remote(let payload):
                SkillDetailView(
                    remoteSkill: payload.skill,
                    providers: payload.providers,
                    targetProvider: payload.targetProvider,
                    onClose: {
                        closeWindow()
                    },
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

    private func closeWindow() {
        dismissWindow(id: SkillDetailWindowCoordinator.windowID)
        dismiss()
    }
}
