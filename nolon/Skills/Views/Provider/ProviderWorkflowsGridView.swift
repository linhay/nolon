import SwiftUI

struct ProviderWorkflowsGridView: View {
    let viewModel: ProviderDetailGridViewModel
    let columns: [GridItem]
    
    var body: some View {
        if viewModel.workflows.isEmpty {
            ContentUnavailableView(
                NSLocalizedString("workflows.empty", comment: "No Workflows"),
                systemImage: "arrow.triangle.branch",
                description: Text(NSLocalizedString("workflows.empty_desc", comment: "No workflows in this provider"))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.workflows) { workflow in
                    WorkflowCardView(
                        workflow: workflow,
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
