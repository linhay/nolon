import SwiftUI
import Observation

@Observable
final class RemoteSkillsBrowserViewModel {
    var selectedRepository: RemoteRepository?
    var selectedSkill: RemoteSkill?
    var searchText = ""
    var columnVisibility: NavigationSplitViewVisibility = .all
    var installedSlugs: Set<String> = []
    
    @MainActor
    func refreshInstalledSkills(repository: SkillRepository) {
        do {
            let skills = try repository.listSkills()
            installedSlugs = Set(skills.map { $0.id })
        } catch {
            print("Failed to load installed skills: \(error)")
        }
    }
}

/// Main three-column split view for browsing remote skill repositories
struct RemoteSkillsBrowserView: View {
    @ObservedObject var settings: ProviderSettings
    let repository: SkillRepository
    let onInstall: (RemoteSkill, Provider) -> Void
    
    @State private var viewModel = RemoteSkillsBrowserViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationSplitView(columnVisibility: $viewModel.columnVisibility) {
            // Column 1: Repository sidebar
            RemoteRepositorySidebarView(
                selectedRepository: $viewModel.selectedRepository,
                settings: settings
            )
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } content: {
            // Column 2: Skills list
            RemoteSkillsContentView(
                repository: viewModel.selectedRepository,
                selectedSkill: $viewModel.selectedSkill,
                searchText: $viewModel.searchText,
                installedSlugs: viewModel.installedSlugs
            )
            .id(viewModel.selectedRepository?.id)
            .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 320)
        } detail: {
            // Column 3: Skill detail (takes remaining space)
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $viewModel.searchText, placement: .toolbar, prompt: "Search Skills")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.refreshInstalledSkills(repository: repository)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh installed status")
            }
        }
        .onAppear {
            viewModel.refreshInstalledSkills(repository: repository)
        }
    }
    
    @ViewBuilder
    private var detailView: some View {
        if let skill = viewModel.selectedSkill {
            RemoteSkillDetailView(
                skill: skill,
                providers: settings.providers,
                isInstalled: viewModel.installedSlugs.contains(skill.slug),
                onInstall: { provider in
                    onInstall(skill, provider)
                    // Refresh after install attempt
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        viewModel.refreshInstalledSkills(repository: repository)
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
