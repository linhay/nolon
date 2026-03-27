import SwiftUI
import ProviderCatalog
import NolonResourceKit
import Observation
import NolonUI

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
        NolonUI.WindowEmptyStateScaffold.skillDetailEmptyState(
            hasContent: coordinator.payload != nil,
            minWidth: 900,
            minHeight: 600
        ) {
            switch coordinator.payload {
            case .local(let payload):
                LocalSkillDetailWindowScene(payload: payload, onClose: closeWindow)
            case .remote(let payload):
                RemoteSkillDetailWindowScene(payload: payload, onClose: closeWindow)
            case .none:
                EmptyView()
            }
        }
    }

    private func closeWindow() {
        dismissWindow(id: SkillDetailWindowCoordinator.windowID)
        dismiss()
    }
}

@MainActor
private struct LocalSkillDetailWindowScene: View {
    @State private var viewModel: SkillDetailViewModel
    private let providers: [Provider]
    private let currentProvider: Provider?
    private let onClose: () -> Void

    init(payload: SkillDetailWindowCoordinator.LocalPayload, onClose: @escaping () -> Void) {
        self.providers = payload.settings.providers
        self.currentProvider = payload.provider
        self.onClose = onClose
        self._viewModel = State(initialValue: SkillDetailViewModel(skill: payload.skill, settings: payload.settings))
    }

    var body: some View {
        NolonUI.SkillDetailView(
            viewModel: viewModel.makeNolonUIViewModel(
                providers: providers,
                currentProvider: currentProvider,
                onClose: onClose
            )
        )
        .task {
            await viewModel.loadData(checkProviders: providers, currentProvider: currentProvider)
        }
    }
}

@MainActor
private struct RemoteSkillDetailWindowScene: View {
    @State private var viewModel: SkillDetailViewModel
    private let providers: [Provider]
    private let onClose: () -> Void

    init(payload: SkillDetailWindowCoordinator.RemotePayload, onClose: @escaping () -> Void) {
        self.providers = payload.targetProvider.map { [$0] } ?? payload.providers
        self.onClose = onClose
        self._viewModel = State(
            initialValue: SkillDetailViewModel(
                remoteSkill: payload.skill,
                onInstall: { _, provider in
                    payload.onInstall(provider)
                }
            )
        )
    }

    var body: some View {
        NolonUI.SkillDetailView(
            viewModel: viewModel.makeNolonUIViewModel(
                providers: providers,
                currentProvider: nil,
                onClose: onClose
            )
        )
        .task {
            await viewModel.loadData(checkProviders: providers, currentProvider: nil)
        }
    }
}
