import SwiftUI
import NolonUI
import NolonUIFoundation

struct ProviderAgentsGridView: View {
    let viewModel: ProviderDetailGridViewModel
    let columns: [GridItem]
    let onEditDoc: (NolonUIFoundation.AgentDocInfo) -> Void

    var body: some View {
        NolonUI.ProviderResourceGridSectionView(
            isEmpty: viewModel.filteredAgentsFiles.isEmpty,
            searchText: viewModel.searchText,
            kind: .agents,
            noResultsDescription: NSLocalizedString(
                "remote.search.no_results_desc",
                value: "No matching workflows found",
                comment: "No search results description"
            ),
            columns: columns
        ) {
            ForEach(viewModel.filteredAgentsFiles) { doc in
                NolonUI.AgentDocCardView(
                    doc: doc,
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
