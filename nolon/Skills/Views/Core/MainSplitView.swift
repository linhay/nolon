import SwiftUI
import ProviderCatalog
import CodexProvider
import Combine
import OSLog
import STFilePath
import NolonResourceKit

/// Main three-column split view for the app
/// Left 1: Provider sidebar (collapsible)
/// Left 2: Skills list for current provider
/// Left 3: Skill detail view
@MainActor
@Observable
final class MainSplitViewModel {
    fileprivate static let logger = Logger(subsystem: "com.nolon", category: "MainSplitView")

    var settings = ProviderSettings.shared
    var repository = SkillRepository()
    private(set) var installer: SkillInstaller?
    private var resourceMonitor: ProviderResourceMonitor?
    private let remoteInstallOrchestrator = RemoteInstallOrchestrator()

    var selectedProviderId: Provider.ID?
    var selectedTab: ProviderContentTabType? = .skills
    var columnVisibility: NavigationSplitViewVisibility = .all
    
    var showingSettings = false
    var showingResourceCenter = false
    var refreshTrigger: Int = 0
    
    var selectedProvider: Provider? {
        settings.providers.first { $0.id == selectedProviderId }
    }
    
    @MainActor
    func setup() {
        installer = SkillInstaller(repository: repository, settings: settings)
        resourceMonitor = ProviderResourceMonitor { [weak self] in
            self?.refreshTrigger += 1
        }
        updateResourceMonitoring()
        Task {
            _ = try? await CodexBinaryManager.shared.discoverXcodeAgentVersions()
            _ = await CodexBinaryManager.shared.checkForRustReleaseUpdateIfNeeded(force: false)
        }
    }

    @MainActor
    func updateResourceMonitoring() {
        guard let provider = selectedProvider else {
            resourceMonitor?.stop()
            return
        }
        resourceMonitor?.startWatching(provider: provider)
    }

    @MainActor
    func installRemoteSkill(_ skill: RemoteSkill, to provider: Provider) async {
        guard let installer = installer else { return }

        do {
            try await remoteInstallOrchestrator.installSkill(
                skill,
                to: provider,
                installer: installer,
                remoteBaseURL: currentRemoteBaseURL()
            )
            refreshTrigger += 1
        } catch {
            Self.logger.error("Failed to install remote skill: \(String(describing: error), privacy: .public)")
            // Ideally show an alert here
        }
    }
    
    @MainActor
    func installRemoteWorkflow(_ workflow: RemoteWorkflow, to provider: Provider) async {
        do {
            guard let installer else { return }
            try await remoteInstallOrchestrator.installWorkflow(
                workflow,
                to: provider,
                installer: installer,
                remoteBaseURL: currentRemoteBaseURL()
            )
            refreshTrigger += 1
        } catch {
            Self.logger.error("Failed to install workflow: \(String(describing: error), privacy: .public)")
            // Ideally show an alert here
        }
    }
    
    @MainActor
    func installRemoteMCP(_ mcp: RemoteMCP, to provider: Provider) async {
        do {
            try await remoteInstallOrchestrator.installMCP(
                mcp,
                to: provider,
                remoteBaseURL: currentRemoteBaseURL()
            )
            refreshTrigger += 1
        } catch {
            Self.logger.error("Failed to install MCP: \(String(describing: error), privacy: .public)")
            // Ideally show an alert here
        }
    }
    
    @MainActor
    func onResourceCenterDismissed() {
        refreshTrigger += 1
    }

    @MainActor
    func presentResourceCenter() {
        showingResourceCenter = true
    }

    @MainActor
    func dismissResourceCenter() {
        guard showingResourceCenter else { return }
        showingResourceCenter = false
        onResourceCenterDismissed()
    }

    private func currentRemoteBaseURL() -> String {
        settings.remoteRepositories.first { $0.templateType == .clawdhub }?.baseURL
            ?? RepositoryTemplate.clawdhub.createRepository().baseURL
    }
}

/// Main three-column split view for the app
/// Left 1: Provider sidebar (collapsible)
/// Left 2: Skills list for current provider
/// Left 3: Skill detail view
@MainActor
public struct MainSplitView: View {
    
    @State private var viewModel = MainSplitViewModel()

    public init() {}

    public var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $viewModel.columnVisibility) {
                // Left 1: Provider sidebar
                ProviderSidebarView(
                    selectedProviderId: $viewModel.selectedProviderId,
                    settings: viewModel.settings
                )
            } content: {
                // Left 2: Skills/Workflows tab navigation
                ProviderContentTabView(
                    provider: viewModel.selectedProvider,
                    selectedTab: $viewModel.selectedTab,
                    settings: viewModel.settings,
                    refreshTrigger: viewModel.refreshTrigger
                )
            } detail: {
                // Left 3: Grid cards (skills or workflows)
                ProviderDetailGridView(
                    provider: viewModel.selectedProvider,
                    selectedTab: viewModel.selectedTab,
                    settings: viewModel.settings,
                    refreshTrigger: viewModel.refreshTrigger,
                    onSelectProvider: { providerID in
                        viewModel.selectedProviderId = providerID
                    },
                    onSelectTab: { tab in
                        viewModel.selectedTab = tab
                    }
                )
            }
            .navigationSplitViewStyle(.balanced)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    // Resource Center button
                    Button {
                        viewModel.presentResourceCenter()
                    } label: {
                        Label(
                            NSLocalizedString("toolbar.clawdhub", comment: "Clawdhub"),
                            systemImage: "cloud"
                        )
                    }
                    .help("Browse and install resources from Clawdhub")
                }
            }

            if viewModel.showingResourceCenter {
                resourceCenterOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.showingResourceCenter)

        .sheet(isPresented: Bindable(AppCommandState.shared).showingSettings) {
            AppSettingsView()
                .frame(minWidth: 720, minHeight: 480)
        }
        .onExitCommand {
            viewModel.dismissResourceCenter()
        }
        .onReceive(URLSchemeHandler.shared.$pendingURL) { pendingURL in
            guard let url = pendingURL else { return }
            MainSplitViewModel.logger.info("Received URL from URLSchemeHandler: \(url.absoluteString, privacy: .public)")
            
            // URLSchemeHandler already converted nln:// or nolon:// to https://
            let urlString = url.absoluteString
            MainSplitViewModel.logger.info("Setting pendingImportURL to: \(urlString, privacy: .public)")
            viewModel.settings.pendingImportURL = urlString
            MainSplitViewModel.logger.info("pendingImportURL after set: \(viewModel.settings.pendingImportURL ?? "nil", privacy: .public)")
            
            MainSplitViewModel.logger.info("Opening ResourceCenterView overlay")
            viewModel.presentResourceCenter()
            
            // Clear the pending URL after consuming
            URLSchemeHandler.shared.pendingURL = nil
        }
        .onAppear {
            viewModel.setup()
        }
        .onChange(of: viewModel.selectedProviderId) { _, _ in
            viewModel.updateResourceMonitoring()
        }
        .onReceive(viewModel.settings.$providers) { _ in
            viewModel.updateResourceMonitoring()
        }

    }

    @ViewBuilder
    private var resourceCenterOverlay: some View {
        ZStack {
            DesignSystem.Colors.Overlay.scrim
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.dismissResourceCenter()
                }

            ResourceCenterView(
                settings: viewModel.settings,
                repository: viewModel.repository,
                targetProvider: viewModel.selectedProvider,
                selectedTab: .skills,
                onInstall: { skill, provider in
                    Task {
                        await viewModel.installRemoteSkill(skill, to: provider)
                    }
                },
                onInstallWorkflow: { workflow, provider in
                    Task {
                        await viewModel.installRemoteWorkflow(workflow, to: provider)
                    }
                },
                onInstallMCP: { mcp, provider in
                    Task {
                        await viewModel.installRemoteMCP(mcp, to: provider)
                    }
                }
            )
            .dsGlassPanel(cornerRadius: DesignSystem.Metrics.cornerRadiusXL)
            .padding(ResourceCenterOverlayLayout.outerInset)
        }
    }
}

enum ResourceCenterOverlayLayout {
    static let outerInset: CGFloat = 40
}

#Preview {
    MainSplitView()
}
