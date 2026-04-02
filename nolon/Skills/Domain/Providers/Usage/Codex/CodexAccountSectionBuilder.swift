import Foundation
import ProviderUsage

enum CodexAccountSectionBuilder {
    static func makeSections(
        accounts: [CodexAuthAccount],
        outcomes: [ProviderAccountUsageOutcome],
        summaries: [UUID: CodexAuthSummary],
        grouping: ProviderUsageEngine.CodexAccountGroupingOption,
        sorting: ProviderUsageEngine.CodexAccountSortOption,
        sortDirection: ProviderUsageEngine.CodexSortDirection,
        hideZeroQuotaAccounts: Bool,
        hideErroredAccounts: Bool
    ) -> [ProviderUsageEngine.CodexAccountDisplaySection] {
        ProviderUsageEngine.makeCodexAccountDisplaySections(
            accounts: accounts,
            outcomes: outcomes,
            summaries: summaries,
            customGroupNames: [:],
            grouping: grouping,
            sorting: sorting,
            sortDirection: sortDirection,
            hideZeroQuotaAccounts: hideZeroQuotaAccounts,
            hideErroredAccounts: hideErroredAccounts
        )
    }
}
