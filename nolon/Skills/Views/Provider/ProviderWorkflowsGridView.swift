import SwiftUI

struct ProviderWorkflowsGridView: View {
    let viewModel: ProviderDetailGridViewModel
    let columns: [GridItem]
    
    var body: some View {
        if viewModel.filteredWorkflows.isEmpty {
            ContentUnavailableView(
                viewModel.searchText.isEmpty ? NSLocalizedString("workflows.empty", comment: "No Workflows") : "No Results",
                systemImage: viewModel.searchText.isEmpty ? "arrow.triangle.branch" : "magnifyingglass",
                description: Text(viewModel.searchText.isEmpty ? NSLocalizedString("workflows.empty_desc", comment: "No workflows in this provider") : "No matching workflows found")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.filteredWorkflows) { workflow in
                    WorkflowCardView(
                        workflow: workflow,
                        searchText: viewModel.searchText,
                        onReveal: { viewModel.revealWorkflowInFinder(workflow) },
                        onDelete: { await viewModel.deleteWorkflow(workflow) },
                        onTap: {
                            // Open workflow file in default editor
                            NSWorkspace.shared.open(URL(fileURLWithPath: workflow.path))
                        }
                    )
                }
            }
        }
    }
}
