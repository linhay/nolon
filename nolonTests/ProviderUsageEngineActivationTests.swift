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
    func testBDD_GivenCodexRequestActivate_WhenShowingConfirmation_ThenOnlyTracksPendingAccount() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            name: "work",
            relativeAuthPath: "auth/work.json"
        )
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexActivateAction: { _, _ in },
            postActivationLoadAction: { }
        )
        viewModel.codexAccounts = [account]

        viewModel.requestActivateCodexAccount(id: account.id)

        XCTAssertTrue(viewModel.isShowingActivateConfirm)
        XCTAssertEqual(viewModel.pendingActivateCodexAccount?.id, account.id)
        XCTAssertNil(viewModel.activatingCodexAccountId)
        XCTAssertEqual(viewModel.codexInteractionState(accountID: account.id), .awaitingConfirmation)
        XCTAssertFalse(viewModel.shouldActivateCodexAccountOnTap(id: account.id))
    }

    func testBDD_GivenActivationSuccess_WhenConfirmActivate_ThenClearsPendingAndReloadRuns() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let reloadFlag = AsyncFlagBox()
        let activationStillVisibleDuringReload = LockedBox(false)
        var viewModel: ProviderUsageEngine!
        viewModel = ProviderUsageEngine(
            provider: provider,
            codexActivateAction: { _, _ in },
            postActivationLoadAction: {
                await activationStillVisibleDuringReload.set(viewModel.activatingCodexAccountId != nil)
                await reloadFlag.setTrue()
            }
        )
        let account = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")
        viewModel.pendingActivateCodexAccount = account

        await viewModel.confirmActivate()

        XCTAssertNil(viewModel.pendingActivateCodexAccount)
        XCTAssertNil(viewModel.activatingCodexAccountId)
        XCTAssertNil(viewModel.alertTitle)
        XCTAssertNil(viewModel.alertMessage)
        let reloaded = await reloadFlag.value()
        XCTAssertTrue(reloaded)
        let persistedTransitioning = await activationStillVisibleDuringReload.value()
        XCTAssertTrue(persistedTransitioning)
    }

    func testBDD_GivenActivationSuccessWithoutCustomPostLoad_WhenConfirmActivate_ThenUsesTargetedDiskReloadInsteadOfFullLoad() async throws {
        let isolatedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-codex-activation-targeted-reload-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: isolatedRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: isolatedRoot) }

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: isolatedRoot.appendingPathComponent("provider/skills").path,
            workflowPath: isolatedRoot.appendingPathComponent("provider/prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )
        let authManager = CodexAuthManager(rootURL: isolatedRoot)
        let account = try await authManager.addConfiguredAccount(
            name: "direct",
            apiKey: "sk-live-12345678",
            relay: nil
        )
        let preflightCalled = AsyncFlagBox()
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: authManager,
            codexActivateAction: { passedAccount, passedProvider in
                try await authManager.setActiveAccount(passedAccount, for: passedProvider)
            },
            codexPreflightAction: { _, _, _ in
                await preflightCalled.setTrue()
                return nil
            }
        )
        viewModel.pendingActivateCodexAccount = account

        await viewModel.confirmActivate()

        XCTAssertNil(viewModel.pendingActivateCodexAccount)
        XCTAssertNil(viewModel.activatingCodexAccountId)
        XCTAssertEqual(viewModel.codexDiskReloadCountForTesting, 1)
        XCTAssertFalse(viewModel.didStartInitialLoad)
        XCTAssertEqual(viewModel.activeCodexAccountId, account.id)
        XCTAssertEqual(viewModel.codexAccounts.map(\.id), [account.id])
        let didRunPreflight = await preflightCalled.value()
        XCTAssertFalse(didRunPreflight)
    }

    func testBDD_GivenPreviousActiveAccount_WhenActivationSucceedsBeforeReload_ThenOldAccountBecomesTappableImmediately() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let previous = CodexAuthAccount(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            name: "oauth",
            relativeAuthPath: "auth/oauth.json"
        )
        let target = CodexAuthAccount(
            id: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!,
            name: "apikey",
            relativeAuthPath: "auth/apikey.json"
        )
        let oldAccountTapAllowedDuringReload = LockedBox(false)
        let switchedActiveIDDuringReload = LockedBox<UUID?>(nil)
        var viewModel: ProviderUsageEngine!
        viewModel = ProviderUsageEngine(
            provider: provider,
            codexActivateAction: { _, _ in },
            postActivationLoadAction: {
                await oldAccountTapAllowedDuringReload.set(viewModel.shouldActivateCodexAccountOnTap(id: previous.id))
                await switchedActiveIDDuringReload.set(viewModel.activeCodexAccountId)
            }
        )
        viewModel.codexAccounts = [previous, target]
        viewModel.activeCodexAccountId = previous.id
        viewModel.pendingActivateCodexAccount = target

        await viewModel.confirmActivate()

        let switchedActiveID = await switchedActiveIDDuringReload.value()
        let oldAccountTapAllowed = await oldAccountTapAllowedDuringReload.value()
        XCTAssertEqual(switchedActiveID, target.id)
        XCTAssertTrue(oldAccountTapAllowed)
        XCTAssertEqual(viewModel.activeCodexAccountId, target.id)
        XCTAssertEqual(viewModel.codexInteractionState(accountID: target.id), .active)
    }

    func testBDD_GivenActivationFailure_WhenConfirmActivate_ThenShowsActivationAlertAndClearsTransientState() async {
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

        XCTAssertNil(viewModel.pendingActivateCodexAccount)
        XCTAssertNil(viewModel.activatingCodexAccountId)
        XCTAssertEqual(
            viewModel.alertTitle,
            NSLocalizedString("codex.accounts.title", value: "Accounts", comment: "Codex accounts title")
        )
        XCTAssertEqual(
            viewModel.alertMessage,
            NSLocalizedString("codex.accounts.error.activate", value: "Failed to activate this account.", comment: "Error message")
        )
    }

    func testBDD_GivenImmediateActivateEntry_WhenInvoked_ThenOnlyRequestsConfirmation() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(
            id: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!,
            name: "work",
            relativeAuthPath: "auth/work.json"
        )
        let activateCalled = AsyncFlagBox()
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexActivateAction: { _, _ in
                await activateCalled.setTrue()
            },
            postActivationLoadAction: { }
        )
        viewModel.codexAccounts = [account]

        await viewModel.activateCodexAccountImmediately(id: account.id)

        XCTAssertTrue(viewModel.isShowingActivateConfirm)
        XCTAssertEqual(viewModel.pendingActivateCodexAccount?.id, account.id)
        XCTAssertNil(viewModel.activatingCodexAccountId)
        let didActivate = await activateCalled.value()
        XCTAssertFalse(didActivate)
    }
}
