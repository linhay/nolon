import SwiftUI
import NolonUI
import NolonUIFoundation

struct ProviderRulesGridView: View {
    let viewModel: ProviderDetailGridViewModel
    let columns: [GridItem]
    let markerBaseItems: [PageMarkerItem]
    let onEditRule: (NolonUIFoundation.RuleInfo) -> Void

    var body: some View {
        NolonUI.ProviderResourceGridSectionView(
            isEmpty: viewModel.filteredRules.isEmpty,
            searchText: viewModel.searchText,
            kind: .rules,
            noResultsDescription: NSLocalizedString(
                "remote.search.no_results_desc",
                value: "No matching workflows found",
                comment: "No search results description"
            ),
            columns: columns
        ) {
            ForEach(viewModel.filteredRules) { rule in
                NolonUI.RuleCardView(
                    rule: rule,
                    searchText: viewModel.searchText,
                    onReveal: { viewModel.revealRuleInFinder(rule) },
                    onDelete: { await viewModel.deleteRule(rule) },
                    onTap: {
                        onEditRule(rule)
                    }
                ) { rule in
                    debugPageMarkerMenuItem(
                        [
                            PageMarkerItem(title: NSLocalizedString("tab.rules", value: "Rules", comment: "Rules tab")),
                            PageMarkerItem(title: rule.name)
                        ]
                    )
                }
                .debugCardLocator(markerBaseItems + [PageMarkerItem(title: rule.name)])
            }
        }
    }
}
