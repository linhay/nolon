import Foundation
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog

enum ProviderUsageOutcomeFilter {
    static func displayedGenericOutcomes(
        usageProvider: UsageProvider?,
        hasGeminiAccounts: Bool,
        outcomes: [ProviderAccountUsageOutcome],
    ) -> [ProviderAccountUsageOutcome] {
        ProviderUsageEngine.displayedGenericUsageOutcomes(
            usageProvider: usageProvider,
            hasGeminiAccounts: hasGeminiAccounts,
            outcomes: outcomes,
        )
    }

    static func displayedClaudeOutcomes(
        hasClaudeAccounts: Bool,
        outcomes: [ProviderAccountUsageOutcome]
    ) -> [ProviderAccountUsageOutcome] {
        ProviderUsageEngine.displayedClaudeUsageOutcomes(
            hasClaudeAccounts: hasClaudeAccounts,
            outcomes: outcomes
        )
    }
}
