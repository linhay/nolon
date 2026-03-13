import SwiftUI

struct ProviderRulesGridView: View {
    let viewModel: ProviderDetailGridViewModel
    let columns: [GridItem]
    let markerBaseItems: [PageMarkerItem]
    let onEditRule: (RuleInfo) -> Void

    var body: some View {
        if viewModel.filteredRules.isEmpty {
            ContentUnavailableView(
                viewModel.searchText.isEmpty
                ? NSLocalizedString("rules.empty", value: "No Rules", comment: "No rules")
                : "No Results",
                systemImage: viewModel.searchText.isEmpty ? "list.bullet.rectangle" : "magnifyingglass",
                description: Text(
                    viewModel.searchText.isEmpty
                    ? NSLocalizedString("rules.empty_desc", value: "No rules in this provider", comment: "No rules in provider")
                    : NSLocalizedString("remote.search.no_results_desc", value: "No matching workflows found", comment: "No search results description")
                )
                .dsSecondaryText(font: .body)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.filteredRules) { rule in
                    RuleCardView(
                        rule: rule,
                        searchText: viewModel.searchText,
                        onReveal: { viewModel.revealRuleInFinder(rule) },
                        onDelete: { await viewModel.deleteRule(rule) },
                        onTap: {
                            onEditRule(rule)
                        }
                    )
                    .debugCardLocator(markerBaseItems + [PageMarkerItem(title: rule.name)])
                }
            }
        }
    }
}
