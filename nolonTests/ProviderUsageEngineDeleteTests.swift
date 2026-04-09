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
final class ProviderUsageEngineDeleteTests: XCTestCase {
    func testBDD_GivenAccountId_WhenRequestDelete_ThenPendingDeleteAndConfirmAreSet() {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")
        let viewModel = ProviderUsageEngine(provider: provider)
        viewModel.codexAccounts = [account]

        viewModel.requestDeleteCodexAccount(id: account.id)

        XCTAssertEqual(viewModel.pendingDeleteCodexAccount?.id, account.id)
        XCTAssertTrue(viewModel.isShowingDeleteConfirm)
    }

    func testBDD_GivenDeleteSuccess_WhenConfirmDelete_ThenClearsPendingAndRunsReload() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")
        let reloadFlag = AsyncFlagBox()
        let deletedId = LockedBox<UUID?>(nil)
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexDeleteAction: { id in
                await deletedId.set(id)
            },
            postDeleteLoadAction: {
                await reloadFlag.setTrue()
            }
        )
        viewModel.pendingDeleteCodexAccount = account
        viewModel.isShowingDeleteConfirm = true

        await viewModel.confirmDeleteCodexAccount()

        let removedID = await deletedId.value()
        XCTAssertEqual(removedID, account.id)
        XCTAssertNil(viewModel.pendingDeleteCodexAccount)
        XCTAssertFalse(viewModel.isShowingDeleteConfirm)
        XCTAssertNil(viewModel.alertTitle)
        XCTAssertNil(viewModel.alertMessage)
        let reloaded = await reloadFlag.value()
        XCTAssertTrue(reloaded)
    }

    func testBDD_GivenDeleteFailure_WhenConfirmDelete_ThenShowsDeleteAlert() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexDeleteAction: { _ in
                throw EmptyLocalizedError()
            },
            postDeleteLoadAction: {}
        )
        viewModel.pendingDeleteCodexAccount = account
        viewModel.isShowingDeleteConfirm = true

        await viewModel.confirmDeleteCodexAccount()

        XCTAssertEqual(viewModel.pendingDeleteCodexAccount?.id, account.id)
        XCTAssertTrue(viewModel.isShowingDeleteConfirm)
        XCTAssertEqual(
            viewModel.alertTitle,
            NSLocalizedString("codex.accounts.title", value: "Accounts", comment: "Codex accounts title")
        )
        XCTAssertEqual(
            viewModel.alertMessage,
            NSLocalizedString("codex.accounts.error.delete", value: "Failed to delete this account.", comment: "Error message")
        )
    }

    func testBDD_GivenDeletingNonActiveAccount_WhenConfirmDeleteWithoutHook_ThenDoesNotRefreshRemainingSnapshot() async throws {
        let isolatedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-delete-no-refresh-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: isolatedRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: isolatedRoot) }

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: isolatedRoot.appendingPathComponent("provider/skills").path,
            workflowPath: isolatedRoot.appendingPathComponent("provider/prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )

        let service = CodexAuthManager(rootURL: isolatedRoot)
        let active = try await service.addAccount(
            name: "active",
            authJSONString: #"{"tokens":{"id_token":"active-id","access_token":"active-access"},"user":{"email":"active@example.com"}}"#
        )
        let removable = try await service.addAccount(
            name: "removable",
            authJSONString: #"{"tokens":{"id_token":"remove-id","access_token":"remove-access"},"user":{"email":"remove@example.com"}}"#
        )
        try await service.setActiveAccount(active, for: provider)

        let canonicalAccounts = try await service.loadAccounts()
        let canonicalActive = try XCTUnwrap(canonicalAccounts.first(where: { $0.id == active.id }))
        let canonicalRemovable = try XCTUnwrap(canonicalAccounts.first(where: { $0.id == removable.id }))
        let activeFileURL = await service.accountAuthFile(canonicalActive).url
        let before = try Data(contentsOf: activeFileURL)

        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: service
        )
        viewModel.settings.webTimeoutSeconds = 1
        viewModel.codexAccounts = [canonicalActive, canonicalRemovable]
        viewModel.pendingDeleteCodexAccount = canonicalRemovable
        viewModel.isShowingDeleteConfirm = true

        await viewModel.confirmDeleteCodexAccount()

        XCTAssertEqual(viewModel.codexAccounts.map(\.id), [active.id])
        XCTAssertNil(viewModel.pendingDeleteCodexAccount)
        XCTAssertFalse(viewModel.isShowingDeleteConfirm)
        XCTAssertNil(viewModel.alertTitle)
        XCTAssertNil(viewModel.alertMessage)

        let updatedAccounts = try await service.loadAccounts()
        let remaining = try XCTUnwrap(updatedAccounts.first(where: { $0.id == active.id }))
        let updatedActiveFileURL = await service.accountAuthFile(remaining).url
        let after = try Data(contentsOf: updatedActiveFileURL)
        XCTAssertEqual(before, after)
    }
}
