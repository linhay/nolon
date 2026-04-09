import XCTest
import AppKit
import STJSON
import ProviderUsage
import STFilePath
import ProviderCatalog
import CodexBarProviderCatalog
import NolonResourceKit
@testable import nolon

@MainActor
final class ProviderUsageEngineOutcomeOrderingTests: XCTestCase {
    func testBDD_GivenOutcomeOrderMismatch_WhenReplacingByAccountId_ThenUsageDoesNotDriftAcrossAccounts() {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )

        let first = CodexAuthAccount(name: "first", relativeAuthPath: "auth/first.json")
        let second = CodexAuthAccount(name: "second", relativeAuthPath: "auth/second.json")
        let viewModel = ProviderUsageEngine(provider: provider)

        viewModel.codexAccounts = [first, second]
        viewModel.codexAccountOutcomes = [makeOutcome(account: second, label: "old-second"), makeOutcome(account: first, label: "old-first")]
        viewModel.reorderCodexAccountOutcomesForDisplay()

        viewModel.replaceCodexOutcome(makeOutcome(account: second, label: "new-second"), for: second.id)

        XCTAssertEqual(viewModel.codexAccountOutcomes.count, 2)
        let firstLabel = viewModel.codexAccountOutcomes[0].displayName
        let secondLabel = viewModel.codexAccountOutcomes[1].displayName
        XCTAssertEqual(firstLabel, "old-first")
        XCTAssertEqual(secondLabel, "new-second")
    }

    func testBDD_GivenDuplicatedAccountOutcomes_WhenReordering_ThenKeepsLatestWithoutCrash() {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )

        let first = CodexAuthAccount(name: "first", relativeAuthPath: "auth/first.json")
        let second = CodexAuthAccount(name: "second", relativeAuthPath: "auth/second.json")
        let viewModel = ProviderUsageEngine(provider: provider)

        viewModel.codexAccounts = [first, second]
        viewModel.codexAccountOutcomes = [
            makeOutcome(account: first, label: "old-first"),
            makeOutcome(account: first, label: "new-first"),
            makeOutcome(account: second, label: "old-second")
        ]

        viewModel.reorderCodexAccountOutcomesForDisplay()

        XCTAssertEqual(viewModel.codexAccountOutcomes.count, 2)
        XCTAssertEqual(viewModel.codexAccountOutcomes[0].displayName, "new-first")
        XCTAssertEqual(viewModel.codexAccountOutcomes[1].displayName, "old-second")
    }

    func testBDD_GivenDuplicatedCodexAccounts_WhenReordering_ThenDisplayOutcomesRemainUniqueByAccountID() {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )

        let duplicated = CodexAuthAccount(name: "duplicated", relativeAuthPath: "auth/duplicated.json")
        let normal = CodexAuthAccount(name: "normal", relativeAuthPath: "auth/normal.json")
        let viewModel = ProviderUsageEngine(provider: provider)

        viewModel.codexAccounts = [duplicated, duplicated, normal]
        viewModel.codexAccountOutcomes = [
            makeOutcome(account: duplicated, label: "duplicated"),
            makeOutcome(account: normal, label: "normal")
        ]

        viewModel.reorderCodexAccountOutcomesForDisplay()

        XCTAssertEqual(viewModel.codexAccountOutcomes.count, 2)
        XCTAssertEqual(Set(viewModel.codexAccountOutcomes.map(\.id)).count, 2)
        XCTAssertEqual(viewModel.codexAccountOutcomes.map(\.displayName), ["duplicated", "normal"])
    }

    func testBDD_GivenStaleOutcomeWithoutSnapshot_WhenReordering_ThenDropsStaleOutcomeCard() {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )

        let existing = CodexAuthAccount(name: "existing", relativeAuthPath: "auth/existing.json")
        let stale = CodexAuthAccount(name: "stale", relativeAuthPath: "auth/stale.json")
        let viewModel = ProviderUsageEngine(provider: provider)

        viewModel.codexAccounts = [existing]
        viewModel.codexAccountOutcomes = [
            makeOutcome(account: existing, label: "existing"),
            makeOutcome(account: stale, label: "stale")
        ]

        viewModel.reorderCodexAccountOutcomesForDisplay()

        XCTAssertEqual(viewModel.codexAccountOutcomes.count, 1)
        XCTAssertEqual(viewModel.codexAccountOutcomes.first?.displayName, "existing")
    }

    private func makeOutcome(account: CodexAuthAccount, label: String) -> ProviderAccountUsageOutcome {
        let usage = UsageSnapshot(
            identity: UsageIdentity(accountEmail: "\(label)@example.com", accountOrganization: nil, loginMethod: "oauth", plan: "plus"),
            primary: nil,
            secondary: nil,
            tertiary: nil,
            updatedAt: Date()
        )
        let result = ProviderFetchResult(
            usage: usage,
            credits: nil,
            cost: nil,
            sourceLabel: "CLI",
            fetchKind: .cli,
            strategyKind: .direct
        )
        let outcome = ProviderFetchOutcome(fetchKind: .cli, result: .success(result))
        return ProviderAccountUsageOutcome(
            provider: .codex,
            account: .tokenAccount(
                .init(
                    id: account.id,
                    label: label,
                    token: "",
                    addedAt: Date().timeIntervalSince1970,
                    lastUsed: nil
                )
            ),
            outcome: outcome
        )
    }
}
