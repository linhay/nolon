import XCTest
import ProviderUsage
import CodexBarProviderCatalog
@testable import nolon

@MainActor
final class ProviderUsageGenericOutcomeFilteringTests: XCTestCase {
    func testBDD_GivenCopilotTokenAccountOutcome_WhenFilteringDisplayedGenericOutcomes_ThenHidesDefaultMissingTokenFailure() {
        let now = Date(timeIntervalSince1970: 1_713_139_200)
        let successOutcome = ProviderAccountUsageOutcome(
            provider: .copilot,
            account: .tokenAccount(
                .init(
                    id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
                    label: "GitHub Copilot",
                    token: "token",
                    addedAt: now.timeIntervalSince1970,
                    lastUsed: nil
                )
            ),
            outcome: .init(
                fetchKind: .web,
                result: .success(
                    .init(
                        usage: UsageSnapshot(
                            identity: UsageIdentity(
                                accountEmail: "dev@example.com",
                                accountOrganization: "GitHub",
                                loginMethod: "oauth",
                                plan: "copilot-pro"
                            ),
                            primary: RateWindow(usedPercent: 12),
                            secondary: nil,
                            tertiary: nil,
                            updatedAt: now
                        ),
                        credits: nil,
                        cost: nil,
                        sourceLabel: "Web",
                        fetchKind: .web,
                        strategyKind: .direct
                    )
                )
            )
        )
        let defaultFailure = ProviderAccountUsageOutcome(
            provider: .copilot,
            account: .default,
            outcome: .init(fetchKind: .web, result: .failure(ProviderUsageError.missingToken(.copilot)))
        )

        let displayed = ProviderUsageEngine.displayedGenericUsageOutcomes(
            usageProvider: .copilot,
            hasGeminiAccounts: false,
            outcomes: [defaultFailure, successOutcome]
        )

        XCTAssertEqual(displayed.count, 1)
        XCTAssertEqual(displayed.first?.id, successOutcome.id)
    }

    func testBDD_GivenCopilotWithoutTokenAccounts_WhenFilteringDisplayedGenericOutcomes_ThenKeepsDefaultMissingTokenFailure() {
        let defaultFailure = ProviderAccountUsageOutcome(
            provider: .copilot,
            account: .default,
            outcome: .init(fetchKind: .web, result: .failure(ProviderUsageError.missingToken(.copilot)))
        )

        let displayed = ProviderUsageEngine.displayedGenericUsageOutcomes(
            usageProvider: .copilot,
            hasGeminiAccounts: false,
            outcomes: [defaultFailure]
        )

        XCTAssertEqual(displayed.map(\.id), [defaultFailure.id])
    }
}
