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
final class ProviderUsageEngineActivationTests: XCTestCase {
    func testBDD_GivenActivationSuccess_WhenConfirmActivate_ThenClearsPendingAndReloadRuns() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let reloadFlag = AsyncFlagBox()
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexActivateAction: { _, _ in
                CodexAuthActivationResult(
                    runtimeSwitched: true,
                    runtimeErrorDescription: nil
                )
            },
            postActivationLoadAction: {
                await reloadFlag.setTrue()
            }
        )
        viewModel.pendingActivateCodexAccount = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")

        await viewModel.confirmActivate()

        XCTAssertNil(viewModel.pendingActivateCodexAccount)
        XCTAssertNil(viewModel.alertTitle)
        XCTAssertNil(viewModel.alertMessage)
        let reloaded = await reloadFlag.value()
        XCTAssertTrue(reloaded)
    }

    func testBDD_GivenRuntimeSwitchFailure_WhenConfirmActivate_ThenActivationContinuesAndReloadRuns() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let reloadFlag = AsyncFlagBox()
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexActivateAction: { _, _ in
                CodexAuthActivationResult(
                    runtimeSwitched: false,
                    runtimeErrorDescription: "runtime switch failed"
                )
            },
            postActivationLoadAction: {
                await reloadFlag.setTrue()
            }
        )
        viewModel.pendingActivateCodexAccount = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")

        await viewModel.confirmActivate()

        XCTAssertNil(viewModel.pendingActivateCodexAccount)
        XCTAssertNil(viewModel.alertMessage)
        let reloaded = await reloadFlag.value()
        XCTAssertTrue(reloaded)
    }

    func testBDD_GivenActivationFailure_WhenConfirmActivate_ThenShowsActivationAlert() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexActivateAction: { _, _ in
                throw ActivationTestError.failed
            },
            postActivationLoadAction: { }
        )
        viewModel.pendingActivateCodexAccount = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")

        await viewModel.confirmActivate()

        XCTAssertNotNil(viewModel.pendingActivateCodexAccount)
        XCTAssertEqual(
            viewModel.alertTitle,
            NSLocalizedString("codex.accounts.title", value: "Accounts", comment: "Codex accounts title")
        )
        XCTAssertEqual(
            viewModel.alertMessage,
            NSLocalizedString("codex.accounts.error.activate", value: "Failed to activate this account.", comment: "Error message")
        )
    }
}
