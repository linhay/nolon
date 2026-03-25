import Foundation
import ProviderUsage

enum CodexAccountSectionBuilder {
    static func makeSections(
        accounts: [CodexAuthAccount],
        outcomes: [ProviderAccountUsageOutcome],
        summaries: [UUID: CodexAuthSummary],
        grouping: ProviderUsageViewModel.CodexAccountGroupingOption,
        sorting: ProviderUsageViewModel.CodexAccountSortOption,
        sortDirection: ProviderUsageViewModel.CodexSortDirection,
        hideZeroQuotaAccounts: Bool,
        hideErroredAccounts: Bool
    ) -> [ProviderUsageViewModel.CodexAccountDisplaySection] {
        ProviderUsageViewModel.makeCodexAccountDisplaySections(
            accounts: accounts,
            outcomes: outcomes,
            summaries: summaries,
            grouping: grouping,
            sorting: sorting,
            sortDirection: sortDirection,
            hideZeroQuotaAccounts: hideZeroQuotaAccounts,
            hideErroredAccounts: hideErroredAccounts
        )
    }
}

