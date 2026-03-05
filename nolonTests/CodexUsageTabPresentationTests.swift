import XCTest
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
@testable import nolon

@MainActor
final class CodexUsageTabPresentationTests: XCTestCase {
    func testBDD_GivenCodexProvider_WhenResolvingUsageTabName_ThenUsesAccountAndUsageLabel() {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "~/.codex/skills",
            workflowPath: "~/.codex/prompts",
            installMethod: .symlink,
            templateId: "codex"
        )

        let title = ProviderContentTabType.usage.localizedName(for: provider)

        XCTAssertEqual(title, "账号与用量")
    }

    func testBDD_GivenCodexXcodeProvider_WhenResolvingUsageTabName_ThenUsesAccountAndUsageLabel() {
        let provider = Provider(
            name: "Codex Xcode",
            defaultSkillsPath: "~/Library/Developer/Xcode/CodingAssistant/codex/skills",
            workflowPath: "~/Library/Developer/Xcode/CodingAssistant/codex/prompts",
            installMethod: .symlink,
            templateId: "codexXcode"
        )

        let title = ProviderContentTabType.usage.localizedName(for: provider)

        XCTAssertEqual(title, "账号与用量")
    }

    func testBDD_GivenNonCodexProvider_WhenResolvingUsageTabName_ThenKeepsUsageLabel() {
        let provider = Provider(
            name: "Claude",
            defaultSkillsPath: "~/.claude/skills",
            workflowPath: "~/.claude/prompts",
            installMethod: .copy,
            templateId: "claudeCode"
        )

        let title = ProviderContentTabType.usage.localizedName(for: provider)

        XCTAssertEqual(title, NSLocalizedString("tab.usage", value: "Usage", comment: "Usage"))
    }

    func testBDD_GivenCodexUsageView_WhenResolvingHeaderActions_ThenActionOrderIsRefreshLoginImport() {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "~/.codex/skills",
            workflowPath: "~/.codex/prompts",
            installMethod: .symlink,
            templateId: "codex"
        )

        let actions = ProviderUsageHeaderAction.orderedActions(for: provider)

        XCTAssertEqual(actions, [.refreshAll, .login, .importAuth])
    }

    func testBDD_GivenNonCodexUsageView_WhenResolvingHeaderActions_ThenOnlyShowsLogin() {
        let provider = Provider(
            name: "Copilot",
            defaultSkillsPath: "~/.copilot/skills",
            workflowPath: "~/.copilot/prompts",
            installMethod: .copy,
            templateId: "copilot"
        )

        let actions = ProviderUsageHeaderAction.orderedActions(for: provider)

        XCTAssertEqual(actions, [.login])
    }

    func testBDD_GivenGeminiProvider_WhenResolvingDashboardLoginPolicy_ThenUsesRefreshInsteadOfSignIn() {
        let provider = Provider(
            name: "Gemini CLI",
            defaultSkillsPath: "~/.gemini/skills",
            workflowPath: "~/.gemini/workflows",
            installMethod: .copy,
            templateId: "gemini"
        )
        let shouldShowSignIn = ProviderUsageLoginPolicy.shouldShowDashboardSignIn(
            for: provider,
            dashboardURL: URL(string: "https://gemini.google.com")
        )
        XCTAssertFalse(shouldShowSignIn)
    }

    func testBDD_GivenCopilotProvider_WhenResolvingDashboardLoginPolicy_ThenKeepsSignIn() {
        let provider = Provider(
            name: "Copilot",
            defaultSkillsPath: "~/.copilot/skills",
            workflowPath: "~/.copilot/prompts",
            installMethod: .copy,
            templateId: "copilot"
        )
        let shouldShowSignIn = ProviderUsageLoginPolicy.shouldShowDashboardSignIn(
            for: provider,
            dashboardURL: URL(string: "https://github.com/settings/copilot")
        )
        XCTAssertTrue(shouldShowSignIn)
    }

    func testBDD_GivenGeminiProvider_WhenResolvingCLILoginPolicy_ThenShowsLoginAction() {
        let provider = Provider(
            name: "Gemini CLI",
            defaultSkillsPath: "~/.gemini/skills",
            workflowPath: "~/.gemini/workflows",
            installMethod: .copy,
            templateId: "gemini"
        )

        let shouldUseCLILogin = ProviderUsageLoginPolicy.shouldUseCLILogin(for: provider)

        XCTAssertTrue(shouldUseCLILogin)
    }

    func testBDD_GivenGeminiCandidate_WhenEvaluatingInlineImportPolicy_ThenShowsImportAction() {
        let shouldShow = ProviderUsageViewModel.shouldShowGeminiImportAction(
            usageProvider: .gemini,
            outcomes: [],
            candidateAvailable: true
        )

        XCTAssertTrue(shouldShow)
    }

    func testBDD_GivenGeminiWithoutCandidate_WhenEvaluatingInlineImportPolicy_ThenHidesImportAction() {
        let shouldShow = ProviderUsageViewModel.shouldShowGeminiImportAction(
            usageProvider: .gemini,
            outcomes: [],
            candidateAvailable: false
        )

        XCTAssertFalse(shouldShow)
    }

    func testBDD_GivenNonGeminiProvider_WhenEvaluatingInlineImportPolicy_ThenHidesImportAction() {
        let outcome = ProviderAccountUsageOutcome(
            provider: .antigravity,
            account: .default,
            outcome: ProviderFetchOutcome(
                fetchKind: .cli,
                result: .failure(ProviderUsageError.missingAccount(.antigravity))
            )
        )

        let shouldShow = ProviderUsageViewModel.shouldShowGeminiImportAction(
            usageProvider: .antigravity,
            outcomes: [outcome],
            candidateAvailable: true
        )

        XCTAssertFalse(shouldShow)
    }

    func testBDD_GivenFailedUsageOutcome_WhenEvaluatingAppearRefreshPolicy_ThenForcesRefresh() {
        let failed = ProviderAccountUsageOutcome(
            provider: .antigravity,
            account: .default,
            outcome: ProviderFetchOutcome(
                fetchKind: .cli,
                result: .failure(ProviderUsageError.missingAccount(.antigravity))
            )
        )

        let shouldForce = ProviderUsageViewModel.shouldForceRefreshOnAppearForFailedOutcomes([failed])

        XCTAssertTrue(shouldForce)
    }

    func testBDD_GivenSuccessfulUsageOutcome_WhenEvaluatingAppearRefreshPolicy_ThenDoesNotForceRefresh() {
        let success = ProviderAccountUsageOutcome(
            provider: .antigravity,
            account: .default,
            outcome: ProviderFetchOutcome(
                fetchKind: .cli,
                result: .success(
                    ProviderFetchResult(
                        usage: UsageSnapshot(identity: UsageIdentity(), primary: nil, secondary: nil, tertiary: nil, updatedAt: Date()),
                        credits: nil,
                        cost: nil,
                        sourceLabel: "CLI",
                        fetchKind: .cli,
                        strategyKind: .direct
                    )
                )
            )
        )

        let shouldForce = ProviderUsageViewModel.shouldForceRefreshOnAppearForFailedOutcomes([success])

        XCTAssertFalse(shouldForce)
    }
}
