import SwiftUI
import ProviderCatalog
import NolonResourceKit
import NolonUI

struct ProviderSkillsGridView: View {
    let viewModel: ProviderDetailGridViewModel
    let columns: [GridItem]
    let provider: Provider
    let markerBaseItems: [PageMarkerItem]
    
    var body: some View {
        NolonUI.ProviderResourceGridSectionView(
            isEmpty: viewModel.filteredSkills.isEmpty,
            searchText: viewModel.searchText,
            kind: .skills,
            noResultsDescription: "No matching skills found",
            columns: columns
        ) {
            ForEach(viewModel.groupedFilteredSkills, id: \.path) { group in
                Section {
                    ForEach(group.skills, id: \.uniqueId) { skill in
                        NolonUI.SkillCardView(
                            name: skill.name,
                            description: skill.description,
                            version: skill.version,
                            isOrphaned: skill.installationState == .orphaned,
                            hasWorkflow: viewModel.workflowIds.contains(skill.id),
                            referenceCount: skill.referenceCount,
                            scriptCount: skill.scriptCount,
                            searchText: viewModel.searchText,
                            onReveal: { viewModel.revealSkillInFinder(skill) },
                            onUninstall: { await viewModel.uninstallSkill(skill) },
                            onLinkWorkflow: { viewModel.linkSkillToWorkflow(skill) },
                            onUnlinkWorkflow: { viewModel.unlinkSkillFromWorkflow(skill) },
                            onMigrate: { await viewModel.migrateSkill(skill) },
                            onTap: { viewModel.selectedSkillForDetail = skill }
                        ) {
                            debugPageMarkerMenuItem(
                                [
                                    PageMarkerItem(title: provider.displayName),
                                    PageMarkerItem(title: NSLocalizedString("tab.skills", comment: "Skills")),
                                    PageMarkerItem(title: skill.name)
                                ]
                            )
                        }
                        .id(skill.uniqueId)
                        .debugCardLocator(markerBaseItems + [PageMarkerItem(title: skill.name)])
                    }
                } header: {
                    NolonUI.ProviderGroupedPathHeaderView(
                        title: viewModel.displayPath(for: group.path),
                        columnCount: columns.count
                    )
                }
            }
        }
    }
}
