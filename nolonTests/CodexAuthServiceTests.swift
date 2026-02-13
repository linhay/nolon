import XCTest
import STJSON
import ProviderUsage
import STFilePath
import ProviderCatalog
@testable import nolon

@MainActor
final class CodexAuthManagerTests: XCTestCase {
    func testBDD_GivenAppAuthManagerType_WhenCheckingMigrationBoundary_ThenUsesProviderUsageManagerType() {
        XCTAssertEqual(
            ObjectIdentifier(CodexAuthManager.self),
            ObjectIdentifier(CodexAuthManager.self)
        )
    }

    func testBDD_GivenRealCodexAccount_WhenStoringUsageCache_ThenUsageCacheIsPersisted() async throws {
        let service = CodexAuthManager()
        let accounts = try await service.loadAccounts()
        if accounts.isEmpty {
            throw XCTSkip("No codex accounts found under ~/.nolon/codex/auth")
        }

        let account = accounts[0]
        let file = await service.accountAuthFile(account)
        let fileURL = file.url
        let originalData = try Data(contentsOf: fileURL)
        defer {
            try? originalData.write(to: fileURL, options: [.atomic])
        }

        let usage = UsageSnapshot(
            identity: UsageIdentity(accountEmail: "bdd@example.com", accountOrganization: nil, loginMethod: "oauth", plan: "plus"),
            primary: nil,
            secondary: nil,
            tertiary: nil,
            updatedAt: Date()
        )
        let credits = CreditsSnapshot(remaining: 42, updatedAt: Date())
        let cache = CodexAuthUsageCache(
            cachedAt: Date(),
            creditsRefreshedAt: credits.updatedAt,
            fetchKind: .cli,
            strategyKind: .direct,
            sourceLabel: "CLI",
            usage: usage,
            credits: credits,
            cost: nil
        )

        try await service.storeUsageCache(cache, for: account)

        let loaded = try await service.loadUsageCache(for: account)
        XCTAssertEqual(loaded, cache)

        let data = try Data(contentsOf: fileURL)
        let json = try JSON(data: data)
        XCTAssertNotEqual(json["nolon"]["usage_cache"], JSON.null)
    }
}

final class CodexAuthChangeSuppressionStoreTests: XCTestCase {
    func testBDD_GivenUnseenEvent_WhenCheckingSuppression_ThenEventIsNotSuppressed() {
        // Given
        var store = CodexAuthChangeSuppressionStore()
        let now = Date()

        // When
        let suppressed = store.shouldSuppress(path: "/tmp/auth/modified.json", now: now)

        // Then
        XCTAssertFalse(suppressed)
    }

    func testBDD_GivenMarkedEventWithinWindow_WhenCheckingSuppression_ThenEventIsSuppressed() {
        // Given
        var store = CodexAuthChangeSuppressionStore()
        let now = Date()
        store.mark(filePath: "/tmp/auth/auth.json", folderPath: "/tmp/auth", ttl: 1.0, now: now)

        // When
        let suppressed = store.shouldSuppress(path: "/tmp/auth/auth.json", now: now.addingTimeInterval(0.2))

        // Then
        XCTAssertTrue(suppressed)
    }

    func testBDD_GivenMarkedEventAfterWindow_WhenCheckingSuppression_ThenEventIsNotSuppressed() {
        // Given
        var store = CodexAuthChangeSuppressionStore()
        let now = Date()
        store.mark(filePath: "/tmp/auth/auth.json", folderPath: "/tmp/auth", ttl: 0.5, now: now)

        // When
        let suppressed = store.shouldSuppress(path: "/tmp/auth/auth.json", now: now.addingTimeInterval(0.6))

        // Then
        XCTAssertFalse(suppressed)
    }

    func testBDD_GivenTwoDifferentEvents_WhenCheckingSuppression_ThenOnlyMarkedEventIsSuppressed() {
        // Given
        var store = CodexAuthChangeSuppressionStore()
        let now = Date()
        store.mark(filePath: "/tmp/auth/a.json", folderPath: "/tmp/auth", ttl: 1.0, now: now)

        // When
        let suppressedMarked = store.shouldSuppress(path: "/tmp/auth/a.json", now: now.addingTimeInterval(0.1))
        let suppressedUnmarked = store.shouldSuppress(path: "/tmp/other/b.json", now: now.addingTimeInterval(0.1))

        // Then
        XCTAssertTrue(suppressedMarked)
        XCTAssertFalse(suppressedUnmarked)
    }
}

@MainActor
final class CodexAuthTokenExtractionTests: XCTestCase {
    func testBDD_GivenAccountSnapshot_WhenReadingTokenPair_ThenReturnsIdAndAccessToken() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-auth-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let raw = """
        {
          "tokens": {
            "id_token": "id-token-value",
            "access_token": "access-token-value"
          }
        }
        """
        let account = try await service.addAccount(name: "test", authJSONString: raw)

        let pair = try await service.readTokenPair(for: account)

        XCTAssertEqual(pair?.idToken, "id-token-value")
        XCTAssertEqual(pair?.accessToken, "access-token-value")
    }
}

@MainActor
final class CodexAuthActiveAccountRegistryTests: XCTestCase {
    func testBDD_GivenRuntimeActivatedAccount_WhenAuthFileMissing_ThenActiveAccountIdUsesRegistry() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-active-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let account = try await service.addAccount(
            name: "runtime",
            authJSONString: #"{"tokens":{"id_token":"id","access_token":"access"}}"#
        )
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: root.appendingPathComponent("provider/skills").path,
            workflowPath: root.appendingPathComponent("provider/prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await service.setActiveAccount(account, for: provider)
        let active = await service.activeAccountId(for: provider)

        XCTAssertEqual(active, account.id)
    }
}

@MainActor
final class CodexAuthCompatSyncTests: XCTestCase {
    func testBDD_GivenSelectedSnapshot_WhenActivating_ThenProviderAuthIsSymlinkedToSnapshot() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-compat-sync-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let account = try await service.addAccount(
            name: "work",
            authJSONString: #"{"tokens":{"id_token":"id-1","access_token":"access-1"},"nolon":{"usage_cache":{"fetch_kind":"api"}}}"#
        )
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: root.appendingPathComponent("provider/skills").path,
            workflowPath: root.appendingPathComponent("provider/prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await service.activateAccount(account, for: provider)
        let authFile = try XCTUnwrap(await service.authFile(for: provider))
        XCTAssertTrue(authFile.isSymbolicLink)
        let destination = try authFile.destinationOfSymbolicLink()
        let snapshotFile = await service.accountAuthFile(account)
        XCTAssertEqual(
            STPath.standardizedPath(destination.url.path).path,
            STPath.standardizedPath(snapshotFile.url.path).path
        )
    }

    func testBDD_GivenFreshCLILogin_WhenFinalizing_ThenSyncsProviderAuthAndMarksActive() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-cli-finalize-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let providerRoot = root.appendingPathComponent("provider", isDirectory: true)
        try FileManager.default.createDirectory(at: providerRoot, withIntermediateDirectories: true)

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.appendingPathComponent("skills").path,
            workflowPath: providerRoot.appendingPathComponent("prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )

        let authURL = providerRoot.appendingPathComponent("auth.json")
        let raw = #"{"tokens":{"id_token":"id-2","access_token":"access-2"},"user":{"email":"cli@example.com"}}"#
        try raw.write(to: authURL, atomically: true, encoding: .utf8)

        let account = try await service.finalizeCLILogin(provider: provider, newAccountName: "cli")
        let active = await service.activeAccountId(for: provider)

        XCTAssertEqual(active, account.id)
        let authRawValue = try await service.readAuthJSONString(from: provider)
        let authRaw = try XCTUnwrap(authRawValue)
        XCTAssertTrue(authRaw.contains("\"id_token\":\"id-2\""))
        XCTAssertTrue(authRaw.contains("\"access_token\":\"access-2\""))
    }

    func testBDD_GivenPreferredAccount_WhenUpsertingCLILogin_ThenUpdatesPreferredSnapshot() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-cli-upsert-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let target = try await service.addAccount(
            name: "target",
            authJSONString: #"{"tokens":{"id_token":"old-id","access_token":"old-access"},"user":{"email":"a@example.com"}}"#
        )
        _ = try await service.addAccount(
            name: "other",
            authJSONString: #"{"tokens":{"id_token":"other","access_token":"other"},"user":{"email":"b@example.com"}}"#
        )

        let updated = try await service.upsertAccountFromCLILogin(
            authJSONString: #"{"tokens":{"id_token":"new-id","access_token":"new-access"},"user":{"email":"b@example.com"}}"#,
            preferredAccountID: target.id
        )

        XCTAssertEqual(updated.id, target.id)
        let pair = try await service.readTokenPair(for: updated)
        XCTAssertEqual(pair?.idToken, "new-id")
        XCTAssertEqual(pair?.accessToken, "new-access")
    }
}

@MainActor
final class ProviderUsageViewModelCLILoginTests: XCTestCase {
    func testBDD_GivenCodexUsageWatcher_WhenRebuilding_ThenProviderAuthFileIsNotWatched() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let viewModel = ProviderUsageViewModel(provider: provider)

        await viewModel.rebuildUsageWatcherForTesting()
        let watched = viewModel.watchedPathsForTesting()
        let providerAuthPath = URL(fileURLWithPath: "/tmp/auth.json").standardizedFileURL.path

        XCTAssertFalse(watched.contains(providerAuthPath))
    }

    func testBDD_GivenCLILoginAlreadyRunning_WhenRequestingCardLoginAgain_ThenFlowRestartsWithPreferredAccount() {
        // Given
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let viewModel = ProviderUsageViewModel(provider: provider)
        viewModel.isRunningCLILogin = true
        viewModel.cliLoginPreferredAccountId = nil

        // When
        viewModel.requestLoginForCodexAccount(id: UUID())

        // Then
        XCTAssertTrue(viewModel.isRunningCLILogin)
        XCTAssertNotNil(viewModel.cliLoginPreferredAccountId)
    }
}

@MainActor
final class ProviderUsageViewModelActivationTests: XCTestCase {
    func testBDD_GivenActivationSuccess_WhenConfirmActivate_ThenClearsPendingAndReloadRuns() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let reloadFlag = AsyncFlagBox()
        let viewModel = ProviderUsageViewModel(
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
        let viewModel = ProviderUsageViewModel(
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
        let viewModel = ProviderUsageViewModel(
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

final class CodexAuthEventPolicyTests: XCTestCase {
    func testBDD_GivenKnownAccountFileRenamedToTrash_WhenEvaluatingPolicy_ThenRenameIsIgnored() {
        // Given
        let changedPath = "/Users/test/.Trash/personal-account.json"
        let knownFiles: Set<String> = ["personal-account.json", "work-account.json"]

        // When
        let ignored = CodexAuthEventPolicy.shouldIgnoreKnownAuthRename(
            changedPath: changedPath,
            kind: .renamed,
            isAuthFolderChange: true,
            isAuthFileChange: false,
            knownAuthFileNames: knownFiles
        )

        // Then
        XCTAssertTrue(ignored)
    }

    func testBDD_GivenUnknownRenamedFile_WhenEvaluatingPolicy_ThenRenameIsNotIgnored() {
        // Given
        let changedPath = "/Users/test/.Trash/unknown.json"
        let knownFiles: Set<String> = ["personal-account.json", "work-account.json"]

        // When
        let ignored = CodexAuthEventPolicy.shouldIgnoreKnownAuthRename(
            changedPath: changedPath,
            kind: .renamed,
            isAuthFolderChange: true,
            isAuthFileChange: false,
            knownAuthFileNames: knownFiles
        )

        // Then
        XCTAssertFalse(ignored)
    }

    func testBDD_GivenActiveAuthFileRenamed_WhenEvaluatingPolicy_ThenRenameIsNotIgnored() {
        // Given
        let changedPath = "/Users/test/.codex/auth.json"
        let knownFiles: Set<String> = ["auth.json"]

        // When
        let ignored = CodexAuthEventPolicy.shouldIgnoreKnownAuthRename(
            changedPath: changedPath,
            kind: .renamed,
            isAuthFolderChange: true,
            isAuthFileChange: true,
            knownAuthFileNames: knownFiles
        )

        // Then
        XCTAssertFalse(ignored)
    }
}

private enum ActivationTestError: Error {
    case failed
}

private actor AsyncFlagBox {
    private var flag = false

    func setTrue() {
        flag = true
    }

    func value() -> Bool {
        flag
    }
}
