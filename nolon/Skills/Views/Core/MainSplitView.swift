import SwiftUI

/// Main three-column split view for the app
/// Left 1: Provider sidebar (collapsible)
/// Left 2: Skills list for current provider
/// Left 3: Skill detail view
@MainActor
@Observable
final class MainSplitViewModel {
    var settings = ProviderSettings.shared
    var repository = SkillRepository()
    private(set) var installer: SkillInstaller?

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
    }

    @MainActor
    func installRemoteSkill(_ skill: RemoteSkill, to provider: Provider) async {
        guard let installer = installer else { return }

        do {
            if let localPath = skill.localPath {
                // Install from local path (GitHub or Local Folder)
                print("Installing from local path: \(localPath)")
                try installer.installLocal(from: localPath, slug: skill.slug, to: provider)
                print("Successfully installed \(skill.slug) from \(localPath)")
            } else {
                // Using ClawdhubService to download
                let zipURL = try await ClawdhubService.shared.downloadSkill(
                    slug: skill.slug, version: skill.latestVersion?.version)
                try installer.installRemote(zipURL: zipURL, slug: skill.slug, to: provider)
                print("Successfully installed \(skill.slug) from Clawdhub to \(provider.name)")
            }

            // Trigger refresh immediately after install
            refreshTrigger += 1
        } catch {
            print("Failed to install remote skill: \(error)")
            // Ideally show an alert here
        }
    }
    
    @MainActor
    func installRemoteWorkflow(_ workflow: RemoteWorkflow, to provider: Provider) async {
        do {
            let resourceInstaller = ResourceInstaller(globalCache: GlobalCacheRepository())

            if let localPath = workflow.localPath {
                guard let installer else { return }
                print("Installing workflow from local path: \(localPath)")
                try installer.installLocalWorkflow(
                    fileURL: URL(fileURLWithPath: localPath),
                    slug: workflow.slug,
                    to: provider
                )
                print("Successfully installed workflow \(workflow.slug) from local path")
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
                print("Successfully installed workflow \(workflow.slug) to \(provider.name)")
            }
            
            // Trigger refresh immediately after install
            refreshTrigger += 1
        } catch {
            print("Failed to install workflow: \(error)")
            // Ideally show an alert here
        }
    }
    
    @MainActor
    func installRemoteMCP(_ mcp: RemoteMCP, to provider: Provider) async {
        do {
            let resourceInstaller = ResourceInstaller(globalCache: GlobalCacheRepository())
            
            if let localPath = mcp.localPath {
                // Install from local path (GitHub or Local Folder)
                print("Installing MCP from local path: \(localPath)")
                try await resourceInstaller.installFromLocal(
                    resourceURL: URL(fileURLWithPath: localPath),
                    resourceSlug: mcp.slug,
                    resourceType: .mcp,
                    to: provider
                )
                print("Successfully installed MCP \(mcp.slug) from local path")
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
                print("Successfully installed MCP \(mcp.slug) to \(provider.name)")
            }
            
            // Trigger refresh immediately after install
            refreshTrigger += 1
        } catch {
            print("Failed to install MCP: \(error)")
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
            .frame(minHeight: 700, maxHeight: .infinity)
        }
        .onChange(of: viewModel.showingClawdhub) { _, isShowing in
            // Refresh skills list when Clawdhub sheet is dismissed
            if !isShowing {
                viewModel.onClawdhubDismissed()
            }
        }
        .onReceive(URLSchemeHandler.shared.$pendingURL) { pendingURL in
            guard let url = pendingURL else { return }
            print("[MainSplitView] Received URL from URLSchemeHandler: \(url.absoluteString)")
            
            // URLSchemeHandler already converted nln:// or nolon:// to https://
            let urlString = url.absoluteString
            print("[MainSplitView] Setting pendingImportURL to: \(urlString)")
            viewModel.settings.pendingImportURL = urlString
            print("[MainSplitView] pendingImportURL after set: \(viewModel.settings.pendingImportURL ?? "nil")")
            
            print("[MainSplitView] Opening RemoteSkillsBrowserView sheet")
            viewModel.showingClawdhub = true
            
            // Clear the pending URL after consuming
            URLSchemeHandler.shared.pendingURL = nil
        }
        .onAppear {
            viewModel.setup()
        }

    }
}

#Preview {
    MainSplitView()
}
