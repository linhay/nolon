import SwiftUI
import ProviderCatalog
import Combine
import OSLog

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

    var selectedProviderId: Provider.ID?
    var selectedTab: ProviderContentTabType? = .skills
    var columnVisibility: NavigationSplitViewVisibility = .all
    
    var showingSettings = false
    var showingClawdhub = false
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
            if let localPath = skill.localPath {
                // Install from local path (GitHub or Local Folder)
                Self.logger.info("Installing skill from local path: \(localPath, privacy: .public)")
                try installer.installLocal(from: localPath, slug: skill.slug, to: provider)
                Self.logger.info("Installed skill \(skill.slug, privacy: .public) from local path")
            } else {
                let clawdhubRepo = ClawdhubRepository(
                    repository: settings.remoteRepositories.first { $0.templateType == .clawdhub }
                        ?? RepositoryTemplate.clawdhub.createRepository()
                )

                let zipURL = try await clawdhubRepo.downloadSkill(
                    slug: skill.slug,
                    version: skill.latestVersion?.version
                )
                try installer.installRemote(zipURL: zipURL, slug: skill.slug, to: provider)
                Self.logger.info("Installed skill \(skill.slug, privacy: .public) from Clawdhub to \(provider.name, privacy: .public)")
            }

            // Trigger refresh immediately after install
            refreshTrigger += 1
        } catch {
            Self.logger.error("Failed to install remote skill: \(String(describing: error), privacy: .public)")
            // Ideally show an alert here
        }
    }
    
    @MainActor
    func installRemoteWorkflow(_ workflow: RemoteWorkflow, to provider: Provider) async {
        do {
            let resourceInstaller = ResourceInstaller(globalCache: GlobalCacheRepository())

            if let localPath = workflow.localPath {
                guard let installer else { return }
                Self.logger.info("Installing workflow from local path: \(localPath, privacy: .public)")
                try installer.installLocalWorkflow(
                    fileURL: URL(fileURLWithPath: localPath),
                    slug: workflow.slug,
                    to: provider
                )
                Self.logger.info("Installed workflow \(workflow.slug, privacy: .public) from local path")
            } else {
                // Download from remote repository and install
                let clawdhubRepo = ClawdhubRepository(
                    repository: settings.remoteRepositories.first { $0.templateType == .clawdhub }
                        ?? RepositoryTemplate.clawdhub.createRepository()
                )
                
                try await resourceInstaller.installFromRemote(
                    repository: clawdhubRepo,
                    resourceSlug: workflow.slug,
                    resourceType: .workflow,
                    to: provider
                )
                Self.logger.info("Installed workflow \(workflow.slug, privacy: .public) to \(provider.name, privacy: .public)")
            }
            
            // Trigger refresh immediately after install
            refreshTrigger += 1
        } catch {
            Self.logger.error("Failed to install workflow: \(String(describing: error), privacy: .public)")
            // Ideally show an alert here
        }
    }
    
    @MainActor
    func installRemoteMCP(_ mcp: RemoteMCP, to provider: Provider) async {
        do {
            let resourceInstaller = ResourceInstaller(globalCache: GlobalCacheRepository())
            
            if let localPath = mcp.localPath {
                // Install from local path (GitHub or Local Folder)
                Self.logger.info("Installing MCP from local path: \(localPath, privacy: .public)")
                try await resourceInstaller.installFromLocal(
                    resourceURL: URL(fileURLWithPath: localPath),
                    resourceSlug: mcp.slug,
                    resourceType: .mcp,
                    to: provider
                )
                Self.logger.info("Installed MCP \(mcp.slug, privacy: .public) from local path")
            } else {
                // Download from remote repository and install
                let clawdhubRepo = ClawdhubRepository(
                    repository: settings.remoteRepositories.first { $0.templateType == .clawdhub }
                        ?? RepositoryTemplate.clawdhub.createRepository()
                )
                
                try await resourceInstaller.installFromRemote(
                    repository: clawdhubRepo,
                    resourceSlug: mcp.slug,
                    resourceType: .mcp,
                    to: provider
                )
                Self.logger.info("Installed MCP \(mcp.slug, privacy: .public) to \(provider.name, privacy: .public)")
            }
            
            // Trigger refresh immediately after install
            refreshTrigger += 1
        } catch {
            Self.logger.error("Failed to install MCP: \(String(describing: error), privacy: .public)")
            // Ideally show an alert here
        }
    }
    
    @MainActor
    func onClawdhubDismissed() {
        refreshTrigger += 1
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
                refreshTrigger: viewModel.refreshTrigger
            )
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {


                // Clawdhub button
                Button {
                    viewModel.showingClawdhub = true
                } label: {
                    Label(
                        NSLocalizedString("toolbar.clawdhub", comment: "Clawdhub"),
                        systemImage: "cloud"
                    )
                }
                .help("Browse and install skills from Clawdhub")
            }
        }

        .sheet(isPresented: Bindable(AppCommandState.shared).showingSettings) {
            AppSettingsView()
                .frame(minWidth: 720, minHeight: 480)
        }
        .sheet(isPresented: $viewModel.showingClawdhub) {
            RemoteSkillsBrowserView(
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
            .frame(minWidth: 980, idealWidth: 1100, maxWidth: .infinity,
                   minHeight: 700, idealHeight: 760, maxHeight: .infinity)
        }
        .onChange(of: viewModel.showingClawdhub) { _, isShowing in
            // Refresh skills list when Clawdhub sheet is dismissed
            if !isShowing {
                viewModel.onClawdhubDismissed()
            }
        }
        .onReceive(URLSchemeHandler.shared.$pendingURL) { pendingURL in
            guard let url = pendingURL else { return }
            MainSplitViewModel.logger.info("Received URL from URLSchemeHandler: \(url.absoluteString, privacy: .public)")
            
            // URLSchemeHandler already converted nln:// or nolon:// to https://
            let urlString = url.absoluteString
            MainSplitViewModel.logger.info("Setting pendingImportURL to: \(urlString, privacy: .public)")
            viewModel.settings.pendingImportURL = urlString
            MainSplitViewModel.logger.info("pendingImportURL after set: \(viewModel.settings.pendingImportURL ?? "nil", privacy: .public)")
            
            MainSplitViewModel.logger.info("Opening RemoteSkillsBrowserView sheet")
            viewModel.showingClawdhub = true
            
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
}

#Preview {
    MainSplitView()
}
