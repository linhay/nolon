import SwiftUI

struct ProviderSkillsGridView: View {
    let viewModel: ProviderDetailGridViewModel
    let columns: [GridItem]
    let provider: Provider
    
    var body: some View {
        if viewModel.filteredSkills.isEmpty {
            ContentUnavailableView(
                viewModel.searchText.isEmpty ? NSLocalizedString("skills.empty", comment: "No Skills") : "No Results",
                systemImage: viewModel.searchText.isEmpty ? "square.grid.2x2" : "magnifyingglass",
                description: Text(viewModel.searchText.isEmpty ? NSLocalizedString("skills.empty_desc", comment: "No skills installed in this provider") : "No matching skills found")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.filteredSkills) { skill in
                    SkillCardView(
                        skill: skill,
                        provider: provider,
                        hasWorkflow: viewModel.workflowIds.contains(skill.id),
                        searchText: viewModel.searchText,
                        onReveal: { viewModel.revealSkillInFinder(skill) },
                        onUninstall: { await viewModel.uninstallSkill(skill) },
                        onLinkWorkflow: { viewModel.linkSkillToWorkflow(skill) },
                        onTap: { viewModel.selectedSkillForDetail = skill }
                    )
                }
            }
        }
    }
}
