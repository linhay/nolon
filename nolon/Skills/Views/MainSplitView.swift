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
                settings: settings
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
                        systemImage: "globe"
                    )
                }
                .help(NSLocalizedString("toolbar.global_skills_help", comment: "View and install global skills"))
                
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
                },
                onDismiss: {
                    showingGlobalSkills = false
                }
            )
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
}

#Preview {
    MainSplitView()
}
