import SwiftUI

/// Main three-column split view for the app
/// Left 1: Provider sidebar (collapsible)
/// Left 2: Skills list for current provider
/// Left 3: Skill detail view
@MainActor
public struct MainSplitView: View {

    @StateObject private var settings = ProviderSettings()
    @State private var repository = SkillRepository()
    @State private var installer: SkillInstaller?

    @State private var selectedProvider: Provider?
    @State private var selectedSkill: Skill?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    @State private var showingSettings = false
    @State private var showingGlobalSkills = false
    @State private var showingClawdhub = false

    /// Refresh trigger - increment to force skills list reload
    @State private var refreshTrigger: Int = 0

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Left 1: Provider sidebar
            ProviderSidebarView(
                selectedProvider: $selectedProvider,
                settings: settings
            )
        } content: {
            // Left 2: Skills list for current provider
            ProviderSkillsListView(
                provider: selectedProvider,
                selectedSkill: $selectedSkill,
                settings: settings,
                refreshTrigger: refreshTrigger
            )
        } detail: {
            // Left 3: Skill detail
            SkillDetailContentView(skill: selectedSkill)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Global skills button
                Button {
                    showingGlobalSkills = true
                } label: {
                    Label(
                        NSLocalizedString("toolbar.global_skills", comment: "Global Skills"),
                        systemImage: "square.grid.2x2"
                    )
                }
                .help(
                    NSLocalizedString(
                        "toolbar.global_skills_help", comment: "View and install global skills"))

                // Clawdhub button
                Button {
                    showingClawdhub = true
                } label: {
                    Label(
                        NSLocalizedString("toolbar.clawdhub", comment: "Clawdhub"),
                        systemImage: "cloud"
                    )
                }
                .help("Browse and install skills from Clawdhub")

                // Settings button
                Button {
                    showingSettings = true
                } label: {
                    Label(
                        NSLocalizedString("toolbar.settings", comment: "Settings"),
                        systemImage: "gear"
                    )
                }
                .help(NSLocalizedString("toolbar.settings_help", comment: "Configure providers"))
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet(settings: settings)
        }
        .sheet(isPresented: $showingGlobalSkills) {
            GlobalSkillsPopover(
                currentProvider: selectedProvider,
                settings: settings,
                onInstall: { skill in
                    await installSkillToCurrentProvider(skill)
                    refreshTrigger += 1
                },
                onDismiss: {
                    showingGlobalSkills = false
                }
            )
            .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: $showingClawdhub) {
            RemoteSkillsBrowserView(
                settings: settings,
                repository: repository,
                onInstall: { skill, provider in
                    Task {
                        await installRemoteSkill(skill, to: provider)
                    }
                }
            )
            .frame(minWidth: 900, minHeight: 600)
        }
        .onChange(of: showingClawdhub) { _, isShowing in
            // Refresh skills list when Clawdhub sheet is dismissed
            if !isShowing {
                refreshTrigger += 1
            }
        }
        .onAppear {
            installer = SkillInstaller(repository: repository, settings: settings)
        }
    }

    private func installSkillToCurrentProvider(_ skill: Skill) async {
        guard let installer = installer, let provider = selectedProvider else { return }

        do {
            try installer.install(skill: skill, to: provider)
        } catch {
            print("Failed to install skill: \(error)")
        }
    }

    private func installRemoteSkill(_ skill: RemoteSkill, to provider: Provider) async {
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
}

#Preview {
    MainSplitView()
}
