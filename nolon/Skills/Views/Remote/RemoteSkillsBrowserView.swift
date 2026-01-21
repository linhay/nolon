import SwiftUI

/// Main three-column split view for browsing remote skill repositories
struct RemoteSkillsBrowserView: View {
    @ObservedObject var settings: ProviderSettings
    let repository: SkillRepository
    let onInstall: (RemoteSkill, Provider) -> Void

    @State private var selectedRepository: RemoteRepository?
    @State private var selectedSkill: RemoteSkill?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var installedSlugs: Set<String> = []

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Column 1: Repository sidebar
            RemoteRepositorySidebarView(
                selectedRepository: $selectedRepository,
                settings: settings
            )
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } content: {
            // Column 2: Skills list
            RemoteSkillsContentView(
                repository: selectedRepository,
                selectedSkill: $selectedSkill,
                installedSlugs: installedSlugs
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 320)
        } detail: {
            // Column 3: Skill detail (takes remaining space)
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    refreshInstalledSkills()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh installed status")
            }
        }
        .onAppear {
            refreshInstalledSkills()
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if let skill = selectedSkill {
            RemoteSkillDetailView(
                skill: skill,
                providers: settings.providers,
                isInstalled: installedSlugs.contains(skill.slug),
                onInstall: { provider in
                    onInstall(skill, provider)
                    // Refresh after install attempt
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        refreshInstalledSkills()
                    }
                }
            )
        } else {
            ContentUnavailableView(
                "Select a Skill",
                systemImage: "square.grid.2x2",
                description: Text("Choose a skill from the list to view details and install")
            )
        }
    }

    private func refreshInstalledSkills() {
        do {
            let skills = try repository.listSkills()
            installedSlugs = Set(skills.map { $0.id })
        } catch {
            print("Failed to load installed skills: \(error)")
        }
    }
}

#Preview {
    RemoteSkillsBrowserView(
        settings: ProviderSettings(),
        repository: SkillRepository(),
        onInstall: { skill, provider in
            print("Install \(skill.displayName) to \(provider.name)")
        }
    )
    .frame(width: 900, height: 600)
}
