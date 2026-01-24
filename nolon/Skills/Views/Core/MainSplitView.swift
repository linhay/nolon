import SwiftUI

/// Main three-column split view for the app
/// Left 1: Provider sidebar (collapsible)
/// Left 2: Skills list for current provider
/// Left 3: Skill detail view
@MainActor
@Observable
final class MainSplitViewModel {
    var settings = ProviderSettings()
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

                // Settings button
                Button {
                    viewModel.showingSettings = true
                } label: {
                    Label(
                        NSLocalizedString("toolbar.settings", comment: "Settings"),
                        systemImage: "gear"
                    )
                }
                .help(NSLocalizedString("toolbar.settings_help", comment: "Configure providers"))
            }
        }
        .sheet(isPresented: $viewModel.showingSettings) {
            SettingsSheet(settings: viewModel.settings)
        }

        .sheet(isPresented: $viewModel.showingClawdhub) {
            RemoteSkillsBrowserView(
                settings: viewModel.settings,
                repository: viewModel.repository,
                onInstall: { skill, provider in
                    Task {
                        await viewModel.installRemoteSkill(skill, to: provider)
                    }
                }
            )
            .frame(minWidth: 900, minHeight: 600)
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
            viewModel.settings.pendingImportURL = url.absoluteString
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
