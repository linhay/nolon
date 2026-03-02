import XCTest
import ProviderCatalog
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
}
