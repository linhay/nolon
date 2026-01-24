import SwiftUI

struct ProviderSkillsGridView: View {
    let viewModel: ProviderDetailGridViewModel
    let columns: [GridItem]
    let provider: Provider
    
    var body: some View {
        if viewModel.installedSkills.isEmpty {
            ContentUnavailableView(
                NSLocalizedString("skills.empty", comment: "No Skills"),
                systemImage: "square.grid.2x2",
                description: Text(NSLocalizedString("skills.empty_desc", comment: "No skills installed in this provider"))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.installedSkills) { skill in
                    SkillCardView(
                        skill: skill,
                        provider: provider,
                        hasWorkflow: viewModel.workflowIds.contains(skill.id),
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
