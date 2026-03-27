import SwiftUI
import NolonUI

struct ProviderWorkflowsGridView: View {
    let viewModel: ProviderDetailGridViewModel
    let columns: [GridItem]
    let markerBaseItems: [PageMarkerItem]
    
    var body: some View {
        NolonUI.ProviderResourceGridSectionView(
            isEmpty: viewModel.filteredWorkflows.isEmpty,
            searchText: viewModel.searchText,
            kind: .workflows,
            noResultsDescription: "No matching workflows found",
            columns: columns
        ) {
            ForEach(viewModel.filteredWorkflows) { workflow in
                NolonUI.WorkflowCardView(
                    workflow: workflow,
                    searchText: viewModel.searchText,
                    onReveal: { viewModel.revealWorkflowInFinder(workflow) },
                    onDelete: { await viewModel.deleteWorkflow(workflow) },
                    onTap: {
                        // Open workflow file in default editor
                        NSWorkspace.shared.open(URL(fileURLWithPath: workflow.path))
                    }
                ) { workflow in
                    debugPageMarkerMenuItem(
                        [
                            PageMarkerItem(title: NSLocalizedString("tab.workflows", comment: "Workflows")),
                            PageMarkerItem(title: workflow.name)
                        ]
                    )
                }
                .debugCardLocator(markerBaseItems + [PageMarkerItem(title: workflow.name)])
            }
        }
    }
}
