import SwiftUI
import ProviderCatalog
import NolonResourceKit
import Observation
import NolonUI
import NolonUIFoundation
import AppKit

@MainActor
@Observable
final class ResourceCenterWindowCoordinator {
    static let shared = ResourceCenterWindowCoordinator()
    static let windowID = "resource-center"

    struct Payload {
        let settings: ProviderSettings
        let repository: SkillRepository
        let targetProvider: Provider?
        let selectedTab: ResourceCenterTabID?
        let onInstall: (RemoteSkill, Provider) -> Void
        let onInstallWorkflow: ((RemoteWorkflow, Provider) -> Void)?
        let onInstallMCP: ((RemoteMCP, Provider) -> Void)?
        let onRegisterDeleteRequest: ((String, RemoteContentType, Int?, Bool, String?) -> Int)?
        let onMakeDeleteRequestExecutor: ((Int) -> ResourceCatalogGridViewModel.DeleteRequestExecutor)?
        let onClose: (() -> Void)?
    }

    var payload: Payload?

    private init() {}

    func present(payload: Payload) {
        self.payload = payload
    }
}

struct ResourceCenterWindowRootView: View {
    @State private var coordinator = ResourceCenterWindowCoordinator.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NolonUI.WindowEmptyStateScaffold.resourceCenterEmptyState(
            hasContent: coordinator.payload != nil,
            minWidth: 980,
            minHeight: 700
        ) {
            if let payload = coordinator.payload {
                ResourceCenterView(
                    settings: payload.settings,
                    repository: payload.repository,
                    targetProvider: payload.targetProvider,
                    selectedTab: payload.selectedTab,
                    onClose: {
                        payload.onClose?()
                        dismiss()
                        NSApp.keyWindow?.performClose(nil)
                    },
                    onInstall: payload.onInstall,
                    onInstallWorkflow: payload.onInstallWorkflow,
                    onInstallMCP: payload.onInstallMCP,
                    onRegisterDeleteRequest: payload.onRegisterDeleteRequest,
                    onMakeDeleteRequestExecutor: payload.onMakeDeleteRequestExecutor
                )
                .frame(
                    minWidth: 980,
                    idealWidth: 1100,
                    maxWidth: .infinity,
                    minHeight: 700,
                    idealHeight: 760,
                    maxHeight: .infinity
                )
            } else {
                EmptyView()
            }
        }
    }
}
