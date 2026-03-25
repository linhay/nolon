import SwiftUI
import ProviderCatalog
import NolonResourceKit
import Observation

@MainActor
@Observable
final class ResourceCenterWindowCoordinator {
    static let shared = ResourceCenterWindowCoordinator()
    static let windowID = "resource-center"

    struct Payload {
        let settings: ProviderSettings
        let repository: SkillRepository
        let targetProvider: Provider?
        let selectedTab: ResourceContentTabType?
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
        Group {
            if let payload = coordinator.payload {
                ResourceCenterView(
                    settings: payload.settings,
                    repository: payload.repository,
                    targetProvider: payload.targetProvider,
                    selectedTab: payload.selectedTab,
                    onClose: {
                        payload.onClose?()
                        dismiss()
                    },
                    onInstall: payload.onInstall,
                    onInstallWorkflow: payload.onInstallWorkflow,
                    onInstallMCP: payload.onInstallMCP,
                    onRegisterDeleteRequest: payload.onRegisterDeleteRequest,
                    onMakeDeleteRequestExecutor: payload.onMakeDeleteRequestExecutor
                )
                .frame(minWidth: 980, idealWidth: 1100, maxWidth: .infinity,
                       minHeight: 700, idealHeight: 760, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    NSLocalizedString("resource.center.empty.title", value: "No Resource Center Context", comment: "Resource center empty title"),
                    systemImage: "tray",
                    description: Text(
                        NSLocalizedString("resource.center.empty.desc", value: "Open Resource Center from toolbar or provider view.", comment: "Resource center empty description")
                    )
                )
            }
        }
    }
}
