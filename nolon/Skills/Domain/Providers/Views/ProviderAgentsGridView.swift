import SwiftUI
import NolonUI
import NolonUIFoundation

struct ProviderAgentsGridView: View {
    let viewModel: ProviderDetailGridViewModel
    let columns: [GridItem]
    let onEditDoc: (AgentDocInfo) -> Void

    var body: some View {
        if viewModel.filteredAgentsFiles.isEmpty {
            ContentUnavailableView(
                viewModel.searchText.isEmpty
                ? NSLocalizedString("agents.empty", value: "No AGENTS.md Files", comment: "No AGENTS files")
                : "No Results",
                systemImage: viewModel.searchText.isEmpty ? "doc.text" : "magnifyingglass",
                description: Text(
                    viewModel.searchText.isEmpty
                    ? NSLocalizedString("agents.empty_desc", value: "No AGENTS.md files found in Codex home", comment: "No agents docs")
                    : NSLocalizedString("remote.search.no_results_desc", value: "No matching workflows found", comment: "No search results description")
                )
                .dsSecondaryText(font: .body)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.filteredAgentsFiles) { doc in
                    NolonUI.AgentDocCardView(
                        doc: doc.uiFoundationModel,
                        searchText: viewModel.searchText,
                        onReveal: { viewModel.revealAgentDocInFinder(doc) },
                        onDelete: { await viewModel.deleteAgentDoc(doc) },
                        onTap: { onEditDoc(doc) }
                    ) { doc in
                        debugPageMarkerMenuItem(
                            [
                                PageMarkerItem(title: NSLocalizedString("tab.agents", value: "Agents", comment: "Agents tab")),
                                PageMarkerItem(title: doc.fileName)
                            ]
                        )
                    }
                }
            }
        }
    }
}
